import 'package:flutter/foundation.dart';
import '../models/channel.dart';
import '../models/message.dart';
import '../services/api_service.dart';
import '../services/db_service.dart';
import '../services/ws_service.dart';
import '../services/outbox_service.dart';

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

  String? _currentTalker;
  int _currentPriority = 0;
  Map<String, dynamic>? _activeBroadcast;

  Channel? get selectedChannel => _selectedChannel;
  List<Message> get messages => _messages;
  bool get wsConnected => _wsConnected;
  String? get currentTalker => _currentTalker;
  Map<String, dynamic>? get activeBroadcast => _activeBroadcast;

  ChatProvider({
    required this.apiService,
    required this.userId,
    required this.host,
    required this.port,
    required this.token,
  }) {
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
    notifyListeners();

    // 1. Load local messages
    _messages = await DbService.instance.getMessagesForChannel(channel.id);
    notifyListeners();

    // 2. Sync latest messages from server
    await syncChannelMessages(channel.id);
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
      if (_selectedChannel?.id == chId) {
        if (state == 'granted') {
          _currentTalker = event['name'] ?? 'Someone';
          _currentPriority = event['priority'] ?? 1;
        } else if (state == 'released') {
          _currentTalker = null;
          _currentPriority = 0;
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
    super.dispose();
  }
}
