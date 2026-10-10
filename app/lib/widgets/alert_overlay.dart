import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ptt.dart';
import '../theme.dart';

// Full-screen broadcast; emergency is red and can only be closed by acknowledging.
class AlertOverlay extends StatelessWidget {
  const AlertOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final ptt = context.watch<Ptt>();
    final a = ptt.alert;
    if (a == null) return const SizedBox.shrink();
    final emg = ptt.alertEmergency;
    return Positioned.fill(
      child: Material(
        color: emg ? const Color(0xFF7A0E1A) : C.bg.withValues(alpha: .96),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(color: emg ? C.danger : C.accent, shape: BoxShape.circle),
                          child: Icon(
                            emg ? Icons.warning_amber_rounded : Icons.campaign_rounded,
                            size: 44,
                            color: emg ? Colors.white : C.accentInk,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          a['type'] == 'sos' ? 'SOS' : (emg ? 'EMERGENCY' : 'Broadcast'),
                          style: TextStyle(fontSize: 15, letterSpacing: 3, fontWeight: FontWeight.w800, color: emg ? Colors.white70 : C.accent),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          a['body'] ?? '',
                          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, height: 1.2, color: Colors.white),
                        ),
                        const SizedBox(height: 14),
                        Text('From ${a['sender_name'] ?? 'Control'}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: emg ? Colors.white : C.accent,
                      foregroundColor: emg ? const Color(0xFF7A0E1A) : C.accentInk,
                      minimumSize: const Size.fromHeight(64),
                    ),
                    onPressed: ptt.acknowledge,
                    icon: const Icon(Icons.check_circle_rounded),
                    label: const Text('Acknowledge', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
