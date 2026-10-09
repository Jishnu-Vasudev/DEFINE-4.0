import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ptt.dart';
import '../theme.dart';
import '../widgets/conn_banner.dart';
import 'chat_screen.dart';

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Channels'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'mode') return s.setToggleTalk(!s.toggleTalk);
              final ok = await showDialog<bool>(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('Leave network?'),
                  content: const Text('You will need a new invite to join again.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                    TextButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Leave', style: TextStyle(color: C.danger)),
                    ),
                  ],
                ),
              );
              if (ok == true) s.logout();
            },
            itemBuilder: (_) => [
              CheckedPopupMenuItem(value: 'mode', checked: s.toggleTalk, child: const Text('Tap to talk (toggle)')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'leave', child: Text('Leave network')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnBanner(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: avatarColor(s.userName ?? ''),
                  child: Text(initials(s.userName ?? ''), style: const TextStyle(fontSize: 11, color: Colors.white)),
                ),
                const SizedBox(width: 10),
                Text('Signed in as ${s.userName}', style: const TextStyle(color: C.muted)),
                if (s.role == 'admin') ...[const SizedBox(width: 8), const _Tag('admin')],
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: s.refreshChannels,
              child: s.channels.isEmpty
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(Icons.forum_outlined, size: 56, color: C.muted),
                        SizedBox(height: 12),
                        Center(
                          child: Text('No channels yet', style: TextStyle(color: C.muted)),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: s.channels.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, indent: 84),
                      itemBuilder: (_, i) => _ChannelTile(s.channels[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatelessWidget {
  final Map<String, dynamic> ch;
  const _ChannelTile(this.ch);

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final talker = context.watch<Ptt>().talkers[ch['id']];
    final zone = ch['kind'] == 'zone';
    return FutureBuilder<Map<String, dynamic>?>(
      future: s.store.last(ch['id']),
      builder: (_, snap) {
        final last = snap.data;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          leading: CircleAvatar(
            radius: 26,
            backgroundColor: avatarColor(ch['name']),
            child: Icon(zone ? Icons.place_outlined : Icons.groups_2_outlined, color: Colors.white),
          ),
          title: Text(ch['name'], style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
          subtitle: talker != null
              ? Row(
                  children: [
                    const Icon(Icons.graphic_eq_rounded, size: 16, color: C.accent),
                    const SizedBox(width: 6),
                    Text(
                      '${talker.userId == s.userId ? 'You are' : '${talker.name} is'} talking',
                      style: const TextStyle(color: C.accent, fontWeight: FontWeight.w600),
                    ),
                  ],
                )
              : Text(
                  last == null
                      ? (zone ? 'Zone channel' : 'Team channel')
                      : '${last['sender_id'] == s.userId ? 'You' : last['sender_name']}: ${last['type'] == 'image' ? '📷 Photo' : last['body']}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: C.muted),
                ),
          trailing: last == null ? null : Text(_time(last['created_at'] as int), style: const TextStyle(color: C.muted, fontSize: 12)),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(channel: ch))),
        );
      },
    );
  }
}

String _time(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

class _Tag extends StatelessWidget {
  final String text;
  const _Tag(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      border: Border.all(color: C.line),
    ),
    child: Text(text, style: const TextStyle(fontSize: 11, color: C.muted)),
  );
}
