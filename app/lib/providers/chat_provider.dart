import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/ws_service.dart';
import '../services/outbox_service.dart';
import '../services/livekit_service.dart';
import '../services/foreground_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService apiService;
  final String userId;
  final String host;
  final int port;
  final String token;

  Channel? _selectedChannel;
  List<Message> _messages = [];
  bool _wsConnected = false;
  WsService? _wsService;
  OutboxService? _outboxService;
  LivekitService? _livekitService;

  String? _currentTalker;
  int _currentPriority = 0;
  bool _isTalking = false;
  bool _isRequestingFloor = false;
  String? _floorDeniedReason;
  Map<String, dynamic>? _activeBroadcast;

  Channel? get selectedChannel => _selectedChannel;
  List<Message> get messages => _messages;
  bool get wsConnected => _wsConnected;
  String? get currentTalker => _currentTalker;
  bool get isTalking => _isTalking;
  bool get isRequestingFloor => _isRequestingFloor;
  String? get floorDeniedReason => _floorDeniedReason;
  Map<String, dynamic>? get activeBroadcast => _activeBroadcast;

  ChatProvider({
    required this.apiService,
    required this.userId,
    required this.host,
    required this.port,
    required this.token,
  }) {
    _livekitService = LivekitService(apiService: apiService);

    _outboxService = OutboxService(
      apiService: apiService,
      onMessageUpdated: (msg) {
        _handleLocalMessageUpdate(msg);
      },
    );

    _wsService = WsService(
      host: host,
      port: port,
      token: token,
      onConnectionChanged: (connected) {
        _wsConnected = connected;
        notifyListeners();
        if (connected) {
          _outboxService?.flush();
          if (_selectedChannel != null) {
            syncChannelMessages(_selectedChannel!.id);
          }
        }
      },
      onEvent: (event) {
        _handleWsEvent(event);
      },
    );
  }

  void selectChannel(Channel channel) async {
    _selectedChannel = channel;
    _currentTalker = null;
    _isTalking = false;
    _floorDeniedReason = null;
    notifyListeners();

    // 1. Join LiveKit room for this channel
    await _livekitService?.joinChannelRoom(channel.id);
    ForegroundService.start(channel.name);

    // 2. Load local messages
    _messages = await DbService.instance.getMessagesForChannel(channel.id);
    notifyListeners();

    // 3. Sync latest messages from server
    await syncChannelMessages(channel.id);
  }

  Future<void> startTalking({int priority = 1}) async {
    if (_selectedChannel == null || _isTalking || _isRequestingFloor) return;

    _isRequestingFloor = true;
    _floorDeniedReason = null;
    notifyListeners();

    try {
      final res = await apiService.requestFloor(_selectedChannel!.id, priority: priority);
      if (res['granted'] == true) {
        _isTalking = true;
        _isRequestingFloor = false;
        await _livekitService?.setMicrophoneEnabled(true);
        HapticFeedback.lightImpact();
        notifyListeners();
      } else {
        _isTalking = false;
        _isRequestingFloor = false;
        _floorDeniedReason = 'Channel busy: ${res['holder'] ?? 'Someone'} is talking';
        HapticFeedback.vibrate();
        notifyListeners();
      }
    } catch (e) {
      _isTalking = false;
      _isRequestingFloor = false;
      _floorDeniedReason = 'Failed to request floor';
      notifyListeners();
    }
  }

  Future<void> stopTalking() async {
    if (_selectedChannel == null || !_isTalking) {
      _isRequestingFloor = false;
      notifyListeners();
      return;
    }

    _isTalking = false;
    _isRequestingFloor = false;
    await _livekitService?.setMicrophoneEnabled(false);
    notifyListeners();

    try {
      await apiService.releaseFloor(_selectedChannel!.id);
    } catch (_) {}
  }

  Future<void> syncChannelMessages(String channelId) async {
    try {
      final maxSeq = await DbService.instance.getMaxSeqForChannel(channelId);
      final newMessages = await apiService.getMessages(channelId, afterSeq: maxSeq);
      for (final msg in newMessages) {
        await DbService.instance.saveMessage(msg);
      }
      if (_selectedChannel?.id == channelId) {
        _messages = await DbService.instance.getMessagesForChannel(channelId);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> sendTextMessage(String text) async {
    if (_selectedChannel == null || text.trim().isEmpty) return;
    await _outboxService?.createAndSend(
      channelId: _selectedChannel!.id,
      senderId: userId,
      type: 'text',
      body: text.trim(),
    );
  }

  void _handleLocalMessageUpdate(Message msg) {
    if (_selectedChannel?.id == msg.channelId) {
      final index = _messages.indexWhere((m) => m.id == msg.id);
      if (index != -1) {
        _messages[index] = msg;
      } else {
        _messages.add(msg);
      }
      notifyListeners();
    }
  }

  void _handleWsEvent(Map<String, dynamic> event) async {
    final type = event['t'];
    if (type == 'message') {
      final msgJson = event['message'] as Map<String, dynamic>;
      final msg = Message.fromJson(msgJson);
      await DbService.instance.saveMessage(msg);
      if (_selectedChannel?.id == msg.channelId) {
        final idx = _messages.indexWhere((m) => m.id == msg.id);
        if (idx != -1) {
          _messages[idx] = msg;
        } else {
          _messages.add(msg);
        }
        notifyListeners();
      }
    } else if (type == 'floor') {
      final chId = event['channel_id'];
      final state = event['state'];
      final eventUserId = event['user_id'];

      if (_selectedChannel?.id == chId) {
        if (state == 'granted') {
          if (eventUserId == userId) {
            _isTalking = true;
          } else {
            _currentTalker = event['name'] ?? 'Someone';
            _currentPriority = event['priority'] ?? 1;
          }
        } else if (state == 'released') {
          if (eventUserId == userId) {
            _isTalking = false;
            _livekitService?.setMicrophoneEnabled(false);
          }
          if (_currentTalker != null && (eventUserId == null || eventUserId != userId)) {
            _currentTalker = null;
            _currentPriority = 0;
          }
        }
        notifyListeners();
      }
    } else if (type == 'broadcast') {
      _activeBroadcast = event;
      notifyListeners();
    }
  }

  void dismissBroadcast() {
    if (_activeBroadcast != null && _activeBroadcast!['message'] != null) {
      final msgId = _activeBroadcast!['message']['id'];
      if (msgId != null) {
        apiService.ackMessage(msgId.toString());
      }
    }
    _activeBroadcast = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wsService?.dispose();
    _outboxService?.dispose();
    _livekitService?.dispose();
    ForegroundService.stop();
    super.dispose();
  }
}
