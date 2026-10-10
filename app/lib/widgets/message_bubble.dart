import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'media_views.dart';

class MessageBubble extends StatelessWidget {
  final Map<String, dynamic> m;
  final bool mine;
  final bool showName;
  const MessageBubble({super.key, required this.m, required this.mine, required this.showName});

  @override
  Widget build(BuildContext context) {
    final d = DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int);
    final time = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    final name = m['sender_name'] as String? ?? '';
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(top: showName ? 10 : 2, left: mine ? 56 : 0, right: mine ? 0 : 56),
        padding: const EdgeInsets.fromLTRB(14, 8, 12, 6),
        decoration: BoxDecoration(
          color: mine ? C.mine : C.panel2,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(mine ? 18 : 4),
            bottomRight: Radius.circular(mine ? 4 : 18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showName && !mine)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  name,
                  style: TextStyle(color: Color.lerp(avatarColor(name), Colors.white, .45), fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
            if (m['type'] == 'sos')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.sos_rounded, color: C.danger),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      m['body'] ?? '',
                      style: TextStyle(color: C.danger, fontWeight: FontWeight.w700, fontSize: 15.5),
                    ),
                  ),
                ],
              )
            else if (m['type'] == 'pending' || m['type'] == 'undecryptable')
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(m['type'] == 'pending' ? Icons.lock_clock_outlined : Icons.lock_outline_rounded, size: 16, color: C.muted),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      m['type'] == 'pending' ? "Waiting for the sender's key…" : "This message can't be decrypted on this phone",
                      style: TextStyle(color: C.muted, fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              )
            else if (const {'image', 'video', 'audio', 'file'}.contains(m['type']))
              Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 4),
                child: E2eMedia(
                  media: m['media'] as String? ?? '',
                  name: (m['body'] as String?)?.isNotEmpty == true ? m['body'] : '${m['id']}.${m['type'] == 'image' ? 'jpg' : 'bin'}',
                  builder: (media) => switch (m['type']) {
                    'image' => _Photo(media),
                    'video' => VideoTile(media, m['body'] as String? ?? ''),
                    'audio' => AudioTile(media, m['body'] as String? ?? ''),
                    _ => FileTile(media, m['body'] as String? ?? ''),
                  },
                ),
              )
            else
              Text(m['body'] ?? '', style: const TextStyle(fontSize: 15.5, height: 1.3)),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (m['offline'] == 1)
                  Padding(
                    padding: EdgeInsets.only(right: 4),
                    child: Icon(Icons.wifi_off, size: 12, color: C.warn),
                  ),
                Text(time, style: TextStyle(fontSize: 11, color: C.muted)),
                if (mine) ...[const SizedBox(width: 4), _Status(m['status'] as String? ?? 'queued')],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Photo extends StatelessWidget {
  final String media;
  const _Photo(this.media);

  @override
  Widget build(BuildContext context) {
    final api = context.read<AppState>().api!;
    final local = media.startsWith('local:');
    final img = local
        ? Image.file(File(media.substring(6)), fit: BoxFit.cover)
        : Image.network(
            api.mediaUrl(media),
            headers: api.authHeader,
            fit: BoxFit.cover,
            loadingBuilder: (_, child, p) => p == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
            errorBuilder: (_, _, _) => Center(child: Icon(Icons.broken_image_outlined, color: C.muted)),
          );
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            backgroundColor: Colors.black,
            appBar: AppBar(backgroundColor: Colors.black),
            body: Center(child: InteractiveViewer(child: img)),
          ),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240, height: 240, child: img),
      ),
    );
  }
}

// Queued (clock) -> Sent (one tick) -> Delivered (two ticks, accent).
class _Status extends StatelessWidget {
  final String s;
  const _Status(this.s);
  @override
  Widget build(BuildContext context) {
    final (icon, color, label) = switch (s) {
      'sent' => (Icons.done, C.muted, 'Sent'),
      'delivered' => (Icons.done_all, C.accent, 'Delivered'),
      'failed' => (Icons.error_outline, C.danger, 'Not sent: too large or not allowed'),
      _ => (Icons.schedule, C.warn, 'Queued'),
    };
    return Tooltip(
      message: label,
      child: Icon(icon, size: 14, color: color, semanticLabel: label),
    );
  }
}
