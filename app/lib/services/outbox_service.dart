import 'dart:async';
import 'package:uuid/uuid.dart';
import '../models/message.dart';
import 'api_service.dart';
import 'db_service.dart';

class OutboxService {
  final ApiService apiService;
  final DbService dbService = DbService.instance;
  final Function(Message msg)? onMessageUpdated;

  bool _isFlushing = false;
  Timer? _flushTimer;

  OutboxService({required this.apiService, this.onMessageUpdated}) {
    _flushTimer = Timer.periodic(const Duration(seconds: 5), (_) => flush());
  }

  Future<Message> createAndSend({
    required String channelId,
    required String senderId,
    required String type,
    required String body,
    String? media,
    int offline = 0,
  }) async {
    final msg = Message(
      id: const Uuid().v4(),
      channelId: channelId,
      senderId: senderId,
      type: type,
      body: body,
      media: media,
      createdAt: DateTime.now().millisecondsSinceEpoch,
      offline: offline,
      status: OutboxStatus.queued,
    );

    // 1. Write first to local DB
    await dbService.saveMessage(msg);
    onMessageUpdated?.call(msg);

    // 2. Attempt immediate send
    _sendSingle(msg);

    return msg;
  }

  Future<void> _sendSingle(Message msg) async {
    try {
      final seq = await apiService.sendMessage(msg);
      await dbService.updateMessageStatus(msg.id, OutboxStatus.delivered, seq: seq);
      final updated = msg.copyWith(status: OutboxStatus.delivered, seq: seq);
      onMessageUpdated?.call(updated);
    } catch (_) {
      // Keep in queued state for flush retry
    }
  }

  Future<void> flush() async {
    if (_isFlushing) return;
    _isFlushing = true;
    try {
      final queued = await dbService.getQueuedMessages();
      for (final msg in queued) {
        try {
          final seq = await apiService.sendMessage(msg);
          await dbService.updateMessageStatus(msg.id, OutboxStatus.delivered, seq: seq);
          final updated = msg.copyWith(status: OutboxStatus.delivered, seq: seq);
          onMessageUpdated?.call(updated);
        } catch (_) {
          break; // Stop flushing if server unreachable
        }
      }
    } finally {
      _isFlushing = false;
    }
  }

  void dispose() {
    _flushTimer?.cancel();
  }
}
