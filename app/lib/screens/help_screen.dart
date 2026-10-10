import 'package:flutter/material.dart';

import '../theme.dart';

// Built-in guides; works with no network since the app runs on a closed LAN.
const _topics = [
  (
    Icons.qr_code_2_rounded,
    'Joining a channel',
    'Scan the channel QR on the admin screen, or type its 6-letter code with the server address. '
        'To join more channels later, tap "Join a channel" on the channel list or the switch button inside a chat.',
  ),
  (
    Icons.mic_rounded,
    'Push to talk',
    'Hold the talk button while speaking and let go when done. Only one person can talk in a channel at a time; '
        'if someone else is talking you feel a buzz and see who it is. Turn on "Tap to talk" in the menu to tap once to start and again to stop.',
  ),
  (
    Icons.wifi_off_rounded,
    'No server connection',
    'If the server stops answering for about 3 seconds a red bar appears and Bunny Hop switches to nearby mode: '
        "text and SOS go phone to phone, and every phone carries the others' messages until one of them reaches the server again. "
        'With Bridge mode on (side menu), a nearby phone that still has Wi-Fi delivers your messages to the server right away.',
  ),
  (
    Icons.attach_file_rounded,
    'Photos, video and files',
    'Use the paperclip in a chat. You see a preview before sending. Files over the size limit set by your admin are blocked before upload.',
  ),
  (Icons.campaign_rounded, 'Emergency alerts', 'Admin broadcasts appear full screen. Tap Acknowledge so your admin knows you got it.'),
  (
    Icons.lock_outline_rounded,
    'Privacy',
    'Messages, voice and files stay on your organisation\'s own server on this network. Nothing is sent to the internet. '
        'Messages and files are end-to-end encrypted, so the server cannot read them. When the chat header says '
        '"org monitored", your organisation\'s control room can also open them to check for unsafe content.',
  ),
];

class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = _topics.where((t) => '${t.$2} ${t.$3}'.toLowerCase().contains(_q.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Help')),
      body: EmberBackdrop(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            const Text('How can we help?', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -.6)),
            const SizedBox(height: 14),
            TextField(
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(hintText: 'Search help', prefixIcon: Icon(Icons.search_rounded)),
            ),
            const SizedBox(height: 16),
            if (list.isEmpty)
              Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nothing matches. Try another word.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: C.muted),
                ),
              ),
            for (final t in list)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: glass(radius: 18),
                child: Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    leading: Icon(t.$1, color: C.accent),
                    title: Text(t.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                    iconColor: C.accent,
                    collapsedIconColor: C.muted,
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [Text(t.$3, style: TextStyle(color: C.muted, height: 1.45))],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
