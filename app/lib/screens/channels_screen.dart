import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ptt.dart';
import '../theme.dart';
import '../widgets/app_drawer.dart';
import '../widgets/channel_nav.dart';
import '../widgets/conn_banner.dart';

class ChannelsScreen extends StatelessWidget {
  const ChannelsScreen({super.key});

  Future<void> _join(BuildContext context) async {
    final ch = await showJoinChannelSheet(context);
    if (ch != null && context.mounted) openChannel(context, ch);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final n = s.channels.length;
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        leading: Builder(
          builder: (c) => RoundButton(icon: Icons.menu_rounded, tooltip: 'Menu', onTap: () => Scaffold.of(c).openDrawer()),
        ),
        title: Column(
          children: [
            const Text('Channels'),
            Text(
              n == 1 ? '1 channel' : '$n channels',
              style: TextStyle(fontSize: 12, color: C.muted, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
      body: EmberBackdrop(
        child: Column(
          children: [
            const ConnBanner(),
            Expanded(
              child: RefreshIndicator(
                color: C.accent,
                onRefresh: s.refreshChannels,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 4, 18),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 18,
                            backgroundColor: avatarColor(s.userName ?? ''),
                            child: Text(initials(s.userName ?? ''), style: const TextStyle(fontSize: 13, color: Colors.white)),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Hi, ${s.userName}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (s.role == 'admin') const _Tag('admin'),
                        ],
                      ),
                    ),
                    if (n == 0)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 48),
                        child: Column(
                          children: [
                            Icon(Icons.forum_outlined, size: 52, color: C.muted),
                            SizedBox(height: 12),
                            Text('No channels yet', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            SizedBox(height: 4),
                            Text('Scan a channel QR or enter its code to start.', style: TextStyle(color: C.muted)),
                          ],
                        ),
                      ),
                    for (var i = 0; i < n; i++) _Entrance(index: i, child: _ChannelCard(s.channels[i])),
                    const SizedBox(height: 6),
                    _JoinButton(onTap: () => _join(context)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// One orchestrated moment: cards rise in once, staggered, when the list first shows.
class _Entrance extends StatelessWidget {
  final int index;
  final Widget child;
  const _Entrance({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 420 + 70 * index.clamp(0, 6)),
      curve: Curves.easeOutCubic,
      builder: (_, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

class _ChannelCard extends StatelessWidget {
  final Map<String, dynamic> ch;
  const _ChannelCard(this.ch);

  static String _preview(Map<String, dynamic> m) => switch (m['type']) {
    'image' => 'Photo',
    'video' => 'Video',
    'audio' => 'Audio',
    'file' => 'File: ${m['body']}',
    _ => '${m['body']}',
  };

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final talker = context.watch<Ptt>().talkers[ch['id']];
    final zone = ch['kind'] == 'zone';
    return FutureBuilder<Map<String, dynamic>?>(
      future: s.store.last(ch['id']),
      builder: (_, snap) {
        final last = snap.data;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          margin: const EdgeInsets.only(bottom: 10),
          decoration: glass(radius: 22, bright: talker != null),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () => openChannel(context, ch),
              onLongPress: () => showChannelActions(context, ch),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        gradient: LinearGradient(colors: [C.accent, C.ember]),
                      ),
                      child: Icon(
                        ch['kind'] == 'dm' ? Icons.person_rounded : (zone ? Icons.place_rounded : Icons.groups_2_rounded),
                        color: C.accentInk,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(channelTitle(ch, s.userName), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          const SizedBox(height: 3),
                          if (talker != null)
                            Row(
                              children: [
                                Icon(Icons.graphic_eq_rounded, size: 16, color: C.accent),
                                const SizedBox(width: 6),
                                Text(
                                  '${talker.userId == s.userId ? 'You are' : '${talker.name} is'} talking',
                                  style: TextStyle(color: C.accent, fontWeight: FontWeight.w600),
                                ),
                              ],
                            )
                          else
                            Text(
                              last == null
                                  ? (ch['kind'] == 'dm' ? 'Direct message' : (zone ? 'Zone channel' : 'Team channel'))
                                  : '${last['sender_id'] == s.userId ? 'You' : last['sender_name']}: ${_preview(last)}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: C.muted),
                            ),
                        ],
                      ),
                    ),
                    if (last != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: Text(_time(last['created_at'] as int), style: TextStyle(color: C.muted, fontSize: 12)),
                      ),
                    Icon(Icons.chevron_right_rounded, color: C.muted),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _JoinButton extends StatelessWidget {
  final VoidCallback onTap;
  const _JoinButton({required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(22),
    child: Container(
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: C.accent.withValues(alpha: .4), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_circle_outline_rounded, color: C.accent),
          SizedBox(width: 10),
          Text(
            'Join a channel',
            style: TextStyle(color: C.accent, fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    ),
  );
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
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(99),
      color: C.accent.withValues(alpha: .12),
      border: Border.all(color: C.accent.withValues(alpha: .4)),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 11, color: C.accent, fontWeight: FontWeight.w700),
    ),
  );
}
