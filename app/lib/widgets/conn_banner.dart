import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';

class ConnBanner extends StatelessWidget {
  const ConnBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    Widget child;
    if (s.nearbyMode) {
      final n = s.nearbyPeers;
      child = Container(
        width: double.infinity,
        color: C.danger.withValues(alpha: .14),
        padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
        child: Row(
          children: [
            const Icon(Icons.wifi_tethering_error_rounded, color: C.danger, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Server lost: hop mode',
                    style: TextStyle(color: C.danger, fontWeight: FontWeight.w700),
                  ),
                  Text(
                    n == 0 ? 'Looking for phones to hop through…' : '$n phone${n == 1 ? '' : 's'} in range · text and SOS only',
                    style: const TextStyle(color: C.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: C.danger,
                foregroundColor: Colors.white,
                minimumSize: const Size(64, 40),
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              onPressed: () => _confirmSos(context),
              child: const Text('SOS', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
            ),
          ],
        ),
      );
    } else if (!s.connected) {
      child = Container(
        width: double.infinity,
        color: C.warn.withValues(alpha: .15),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: const Row(
          children: [
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: C.warn)),
            SizedBox(width: 10),
            Text('Reconnecting… messages will send when back', style: TextStyle(color: C.warn, fontSize: 13)),
          ],
        ),
      );
    } else {
      child = const SizedBox(width: double.infinity);
    }
    return AnimatedSize(duration: const Duration(milliseconds: 200), child: child);
  }
}

Future<void> _confirmSos(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.sos_rounded, color: C.danger, size: 40),
      title: const Text('Send SOS?'),
      content: const Text('Every nearby teammate gets a full-screen alert. Control sees it when the server is back.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: C.danger, foregroundColor: Colors.white, minimumSize: const Size(100, 44)),
          onPressed: () => Navigator.pop(c, true),
          child: const Text('Send SOS'),
        ),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await context.read<AppState>().sendSos();
    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('SOS sent')));
  }
}
