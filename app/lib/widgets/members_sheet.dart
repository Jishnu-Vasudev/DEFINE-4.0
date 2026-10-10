import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../screens/call_screen.dart';
import '../theme.dart';
import 'channel_nav.dart';

class MembersSheet extends StatelessWidget {
  final String channelId;
  const MembersSheet({super.key, required this.channelId});

  Future<void> _call(BuildContext context, Map m) async {
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    try {
      final r = await s.api!.post('/call/invite', {'to_user_id': m['id']});
      nav.pop();
      nav.push(
        MaterialPageRoute(
          builder: (_) => CallScreen(room: r['room'], peerName: m['name'], outgoing: true),
        ),
      );
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Can\'t start call right now')));
    }
  }

  Future<void> _message(BuildContext context, Map m) async {
    final s = context.read<AppState>();
    final nav = Navigator.of(context);
    try {
      final ch = Map<String, dynamic>.from(await s.api!.post('/dm', {'user_id': m['id']}));
      await s.refreshChannels();
      nav.pop();
      if (nav.mounted) openChannel(nav.context, ch, replace: true);
    } catch (_) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Can't open a chat right now")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<AppState>();
    return FutureBuilder(
      future: s.api!.get('/channels/$channelId/members'),
      builder: (_, snap) {
        if (!snap.hasData) {
          return const SizedBox(height: 160, child: Center(child: CircularProgressIndicator()));
        }
        final list = (snap.data as List).where((m) => m['id'] != s.userId).toList();
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .6),
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Text('People in this channel', style: TextStyle(color: C.muted)),
                ),
                if (list.isEmpty)
                  ListTile(
                    title: Text('Nobody else yet', style: TextStyle(color: C.muted)),
                  ),
                for (final m in list)
                  ListTile(
                    leading: Stack(
                      children: [
                        CircleAvatar(
                          backgroundColor: avatarColor(m['name']),
                          child: Text(initials(m['name']), style: const TextStyle(color: Colors.white)),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: m['online'] == true ? C.accent : C.muted,
                              shape: BoxShape.circle,
                              border: Border.all(color: C.panel, width: 2),
                            ),
                          ),
                        ),
                      ],
                    ),
                    title: Text(m['name']),
                    subtitle: Text(m['online'] == true ? 'Online' : 'Offline', style: TextStyle(color: C.muted)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Message ${m['name']}',
                          onPressed: () => _message(context, m),
                          icon: const Icon(Icons.chat_bubble_outline_rounded),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filledTonal(
                          tooltip: 'Call ${m['name']}',
                          onPressed: m['online'] == true ? () => _call(context, m) : null,
                          icon: const Icon(Icons.call_rounded),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
