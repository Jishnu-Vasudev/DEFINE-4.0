import 'package:flutter/material.dart';
import '../models/message.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final String? baseUrl;
  final String? jwtToken;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.baseUrl,
    this.jwtToken,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMe ? const Color(0xFF2563EB) : const Color(0xFF1E293B);
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Column(
        crossAxisAlignment: align,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Render image if message type is image
                if (message.type == 'image' && message.media != null && baseUrl != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      '$baseUrl/media/${message.media}?token=${jwtToken ?? ""}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Icon(Icons.broken_image, color: Colors.white60),
                      ),
                      loadingBuilder: (_, child, progress) {
                        if (progress == null) return child;
                        return const Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                        );
                      },
                    ),
                  ),
                  if (message.body.isNotEmpty) const SizedBox(height: 6),
                ],

                if (message.body.isNotEmpty)
                  Text(
                    message.body,
                    style: const TextStyle(color: Colors.white, fontSize: 15),
                  ),

                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      DateTime.fromMillisecondsSinceEpoch(message.createdAt)
                          .toLocal()
                          .toString()
                          .substring(11, 16),
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 11),
                    ),
                    if (isMe) ...[
                      const SizedBox(width: 4),
                      _buildStatusIcon(),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    switch (message.status) {
      case OutboxStatus.queued:
        return const Icon(Icons.access_time, size: 13, color: Colors.orangeAccent);
      case OutboxStatus.sent:
        return const Icon(Icons.check, size: 13, color: Colors.white70);
      case OutboxStatus.delivered:
        return const Icon(Icons.done_all, size: 13, color: Colors.lightGreenAccent);
    }
  }
}
