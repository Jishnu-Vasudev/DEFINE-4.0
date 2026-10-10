import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../hw_ptt.dart';
import '../screens/help_screen.dart';
import '../theme.dart';
import 'ember_toggle.dart';

const appVersion = '1.3.0';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<void> _leave(BuildContext context, AppState s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Leave network?'),
        content: const Text('You are signed out on this phone and need a channel code to join again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text('Leave', style: TextStyle(color: C.danger)),
          ),
        ],
      ),
    );
    if (ok == true) s.logout();
  }

  // Volume-key talk needs Android's accessibility permission once; explain, then open settings.
  Future<void> _hwPtt(BuildContext context, AppState s, bool on) async {
    if (on && !await HwPtt.serviceEnabled() && context.mounted) {
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Talk with the volume keys'),
          content: const Text(
            'Android needs you to allow this once: in the next screen open "Bunny Hop volume-key talk" and turn it on. '
            'While this is on, the volume keys talk on your last opened channel, even on the lock screen.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Open settings')),
          ],
        ),
      );
      if (go != true) return;
      await HwPtt.openSettings();
    }
    await s.setHwPtt(on);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final name = s.userName ?? '';
    return Drawer(
      width: 300,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.horizontal(right: Radius.circular(28))),
      child: EmberBackdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Row(
                  children: [
                    Logo(size: 44),
                    SizedBox(width: 12),
                    Text('Bunny Hop', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -.5)),
                  ],
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: glass(radius: 18),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: avatarColor(name),
                        child: Text(
                          initials(name),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(s.role == 'admin' ? 'Admin' : 'Member', style: TextStyle(color: C.muted, fontSize: 13)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Item(
                  icon: s.darkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  title: s.darkMode ? 'Dark mode' : 'Light mode',
                  subtitle: 'Appearance',
                  trailing: EmberToggle(
                    value: s.darkMode,
                    onChanged: s.setDarkMode,
                    semanticLabel: 'Dark mode',
                    onIcon: Icons.dark_mode_rounded,
                    offIcon: Icons.light_mode_rounded,
                    width: 54,
                  ),
                  onTap: () => s.setDarkMode(!s.darkMode),
                ),
                _Item(
                  icon: s.toggleTalk ? Icons.touch_app_rounded : Icons.pan_tool_alt_outlined,
                  title: 'Tap to talk',
                  subtitle: s.toggleTalk ? 'Tap once to start, again to stop' : 'Off: hold the button while speaking',
                  trailing: EmberToggle(value: s.toggleTalk, onChanged: s.setToggleTalk, semanticLabel: 'Tap to talk', width: 54),
                  onTap: () => s.setToggleTalk(!s.toggleTalk),
                ),
                _Item(
                  icon: Icons.volume_up_rounded,
                  title: 'Volume-key talk',
                  subtitle: s.hwPtt
                      ? 'Talks on ${s.channels.where((c) => c['id'] == s.pttChannelId).map((c) => channelTitle(c, s.userName)).firstOrNull ?? 'your channel'}'
                      : 'Off: volume keys change volume',
                  trailing: EmberToggle(
                    value: s.hwPtt,
                    onChanged: (v) => _hwPtt(context, s, v),
                    semanticLabel: 'Volume-key talk',
                    width: 54,
                  ),
                  onTap: () => _hwPtt(context, s, !s.hwPtt),
                ),
                _Item(
                  icon: Icons.hub_outlined,
                  title: 'Bridge mode',
                  subtitle: s.bridgeMode ? 'Mesh: ${s.meshStatus}' : 'Off: saves battery',
                  trailing: EmberToggle(value: s.bridgeMode, onChanged: s.setBridgeMode, semanticLabel: 'Bridge mode', width: 54),
                  onTap: () => s.setBridgeMode(!s.bridgeMode),
                ),
                _Item(
                  icon: Icons.help_outline_rounded,
                  title: 'Help',
                  subtitle: 'Joining, talking, offline mode',
                  trailing: Icon(Icons.chevron_right_rounded, color: C.muted),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
                  },
                ),
                const Spacer(),
                _Item(
                  icon: Icons.logout_rounded,
                  title: 'Leave network',
                  subtitle: 'Sign out on this phone',
                  danger: true,
                  onTap: () => _leave(context, s),
                ),
                const SizedBox(height: 8),
                Text(
                  'Version $appVersion  ·  ${s.connected ? 'Connected' : 'Offline'}',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Item extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Widget? trailing;
  final VoidCallback onTap;
  final bool danger;
  const _Item({required this.icon, required this.title, required this.subtitle, required this.onTap, this.trailing, this.danger = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(color: (danger ? C.danger : C.accent).withValues(alpha: .12), borderRadius: BorderRadius.circular(12)),
        child: Icon(icon, size: 20, color: danger ? C.danger : C.accent),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w600, color: danger ? C.danger : C.text),
      ),
      subtitle: Text(subtitle, style: TextStyle(color: C.muted, fontSize: 12.5)),
      trailing: trailing,
    ),
  );
}
