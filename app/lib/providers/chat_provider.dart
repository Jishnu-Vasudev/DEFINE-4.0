import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/ws_service.dart';
import '../services/outbox_service.dart';
import '../services/livekit_service.dart';
import '../services/foreground_service.dart';
import '../services/nearby_service.dart';

class ChatProvider extends ChangeNotifier {
  final ApiService apiService;
  final String userId;
  final String userName;
  final String host;
  final int port;
  final String token;

  Channel? _selectedChannel;
  List<Message> _messages = [];
  bool _wsConnected = false;
  WsService? _wsService;
  OutboxService? _outboxService;
  LivekitService? _livekitService;
  NearbyService? _nearbyService;

  String? _currentTalker;
  int _currentPriority = 0;
  bool _isTalking = false;
  bool _isRequestingFloor = false;
  String? _floorDeniedReason;
  Map<String, dynamic>? _activeBroadcast;

  // Nearby fallback mode
  bool _isNearbyMode = false;
  String? _nearbyStatus;
  int _failedPingCount = 0;

  // 1:1 Voice Call state
  Map<String, dynamic>? _incomingCall;
  bool _isInCall = false;
  String? _activeCallRoom;

  Channel? get selectedChannel => _selectedChannel;
  List<Message> get messages => _messages;
  bool get wsConnected => _wsConnected;
  String? get currentTalker => _currentTalker;
  bool get isTalking => _isTalking;
  bool get isRequestingFloor => _isRequestingFloor;
  String? get floorDeniedReason => _floorDeniedReason;
  Map<String, dynamic>? get activeBroadcast => _activeBroadcast;
  Map<String, dynamic>? get incomingCall => _incomingCall;
  bool get isInCall => _isInCall;
  String? get activeCallRoom => _activeCallRoom;
  bool get isNearbyMode => _isNearbyMode;
  String? get nearbyStatus => _nearbyStatus;

  ChatProvider({
    required this.apiService,
    required this.userId,
    required this.userName,
    required this.host,
    required this.port,
    required this.token,
  }) {
    _livekitService = LivekitService(apiService: apiService);

    _nearbyService = NearbyService(
      userName: userName,
      onMessageReceived: (msg) async {
        await DbService.instance.saveMessage(msg);
        _handleLocalMessageUpdate(msg);
      },
      onStatusChanged: (st) {
        _nearbyStatus = st;
        notifyListeners();
      },
    );

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
        if (connected) {
          _failedPingCount = 0;
          if (_isNearbyMode) {
            _isNearbyMode = false;
            _nearbyService?.stopNearby();
          }
          _wsService?.setOfflineMode(false);
          _outboxService?.flush();
          if (_selectedChannel != null) {
            syncChannelMessages(_selectedChannel!.id);
          }
        } else {
          _failedPingCount++;
          if (_failedPingCount >= 3 && !_isNearbyMode) {
            enableNearbyFallback();
          }
        }
        notifyListeners();
      },
      onEvent: (event) {
        _handleWsEvent(event);
      },
    );
  }

  void enableNearbyFallback() {
    _isNearbyMode = true;
    _nearbyService?.startNearby();
    _wsService?.setOfflineMode(true);
    notifyListeners();
  }

  void selectChannel(Channel channel) async {
    _selectedChannel = channel;
    _currentTalker = null;
    _isTalking = false;
    _floorDeniedReason = null;
    notifyListeners();

    // 1. Join LiveKit room for this channel
    if (!_isInCall) {
      await _livekitService?.joinChannelRoom(channel.id);
      ForegroundService.start(channel.name);
    }

    // 2. Load local messages
    _messages = await DbService.instance.getMessagesForChannel(channel.id);
    notifyListeners();

    // 3. Sync latest messages from server
    if (_wsConnected) {
      await syncChannelMessages(channel.id);
    }
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

    if (_isNearbyMode) {
      final msgId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'id': msgId,
        'channel_id': _selectedChannel!.id,
        'type': 'text',
        'body': text.trim(),
        'created_at': now,
        'sender_id': userId,
        'name': userName,
      };

      // Broadcast over Nearby
      await _nearbyService?.broadcastNearbyMessage(payload);

      // Save locally with offline=1
      await _outboxService?.createAndSend(
        channelId: _selectedChannel!.id,
        senderId: userId,
        type: 'text',
        body: text.trim(),
        offline: 1,
      );
    } else {
      await _outboxService?.createAndSend(
        channelId: _selectedChannel!.id,
        senderId: userId,
        type: 'text',
        body: text.trim(),
      );
    }
  }

  Future<void> sendSosBroadcast() async {
    if (_selectedChannel == null) return;
    const sosText = '🚨 SOS EMERGENCY: IMMEDIATE ASSISTANCE REQUIRED';

    if (_isNearbyMode) {
      final msgId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final payload = {
        'id': msgId,
        'channel_id': _selectedChannel!.id,
        'type': 'sos',
        'body': sosText,
        'created_at': now,
        'sender_id': userId,
        'name': userName,
      };
      await _nearbyService?.broadcastNearbyMessage(payload);
    }

    await _outboxService?.createAndSend(
      channelId: _selectedChannel!.id,
      senderId: userId,
      type: 'sos',
      body: sosText,
      offline: _isNearbyMode ? 1 : 0,
    );
  }

  Future<void> sendImageMessage(Uint8List bytes, String filename, {String caption = ''}) async {
    if (_selectedChannel == null) return;
    try {
      final uploadedFilename = await apiService.uploadMedia(bytes, filename);
      await _outboxService?.createAndSend(
        channelId: _selectedChannel!.id,
        senderId: userId,
        type: 'image',
        body: caption,
        media: uploadedFilename,
      );
    } catch (_) {}
  }

  Future<void> initiate1to1Call(String toUserId) async {
    try {
      final room = await apiService.callInvite(toUserId);
      _activeCallRoom = room;
      _isInCall = true;
      notifyListeners();

      await _livekitService?.joinChannelRoom(room);
      await _livekitService?.setMicrophoneEnabled(true);
    } catch (_) {}
  }

  Future<void> acceptIncomingCall() async {
    if (_incomingCall == null) return;
    final room = _incomingCall!['room'] as String;
    _incomingCall = null;
    _activeCallRoom = room;
    _isInCall = true;
    notifyListeners();

    await _livekitService?.joinChannelRoom(room);
    await _livekitService?.setMicrophoneEnabled(true);
  }

  void declineIncomingCall() {
    _incomingCall = null;
    notifyListeners();
  }

  Future<void> end1to1Call() async {
    _isInCall = false;
    _activeCallRoom = null;
    await _livekitService?.setMicrophoneEnabled(false);
    if (_selectedChannel != null) {
      await _livekitService?.joinChannelRoom(_selectedChannel!.id);
    } else {
      await _livekitService?.leaveRoom();
    }
    notifyListeners();
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
    } else if (type == 'call_invite') {
      _incomingCall = event;
      HapticFeedback.vibrate();
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
    _nearbyService?.dispose();
    ForegroundService.stop();
    super.dispose();
  }
}
