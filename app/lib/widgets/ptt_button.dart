import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../ptt.dart';
import '../theme.dart';

// Big hold-to-talk bar: idle -> requesting -> live (accent) / someone else talking (muted).
class PttButton extends StatefulWidget {
  final String channelId;
  const PttButton({super.key, required this.channelId});
  @override
  State<PttButton> createState() => _PttButtonState();
}

class _PttButtonState extends State<PttButton> {
  bool _requesting = false; // waiting for the server to grant the floor

  Future<void> _press() async {
    setState(() => _requesting = true);
    final ptt = context.read<Ptt>();
    final r = await ptt.press(widget.channelId);
    if (!mounted) return;
    setState(() => _requesting = false);
    if (r != PttResult.granted) {
      final who = ptt.talkers[widget.channelId]?.name;
      final text = switch (r) {
        PttResult.denied => '${who ?? 'Someone'} is talking — wait for them to finish',
        PttResult.noMic => 'Microphone is off for BunnyHop. Allow it in Settings.',
        PttResult.noVoice => ptt.voiceErrors[widget.channelId] ?? 'Voice server not reachable',
        _ => 'Couldn\'t start talking. Try again.',
      };
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 4),
            content: Text(text),
            action: r == PttResult.noMic ? SnackBarAction(label: 'Settings', onPressed: openAppSettings) : null,
          ),
        );
    }
  }

  void _release() {
    context.read<Ptt>().release(widget.channelId);
  }

  @override
  Widget build(BuildContext context) {
    final ptt = context.watch<Ptt>();
    final me = context.read<AppState>().userId;
    final live = ptt.talkingIn == widget.channelId;
    final other = ptt.talkers[widget.channelId];
    final busy = other != null && other.userId != me;
    final toggle = context.select<AppState, bool>((s) => s.toggleTalk);
    final label = live
        ? (toggle ? 'Talking… tap to stop' : 'Talking… release to stop')
        : _requesting
        ? 'Connecting…'
        : busy
        ? '${other?.name ?? 'Someone'} is talking'
        : (toggle ? 'Tap to talk' : 'Hold to talk');

    return Semantics(
      button: true,
      label: toggle ? 'Tap to talk' : 'Push to talk',
      child: Listener(
        // hold mode: pointer down = talk, up/cancel = stop. A raw Listener keeps talking
        // when the finger drifts; GestureDetector cancels the tap after ~18 px.
        onPointerDown: toggle ? null : (_) => _press(),
        onPointerUp: toggle ? null : (_) => _release(),
        onPointerCancel: toggle ? null : (_) => _release(),
        child: GestureDetector(
          // toggle mode: each tap flips.
          onTap: toggle ? () => (live || _requesting) ? _release() : _press() : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 64,
            decoration: BoxDecoration(
              color: live ? null : C.panel2,
              gradient: live ? brandGradient : null,
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: live
                    ? C.accent
                    : busy
                    ? C.warn.withValues(alpha: .6)
                    : C.line,
                width: 1.5,
              ),
              boxShadow: live ? [BoxShadow(color: C.accent.withValues(alpha: .5), blurRadius: 24, spreadRadius: 2)] : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  live
                      ? Icons.mic
                      : busy
                      ? Icons.volume_up_rounded
                      : Icons.mic_none_rounded,
                  color: live
                      ? Colors.white
                      : busy
                      ? C.warn
                      : C.text,
                  size: 26,
                ),
                const SizedBox(width: 10),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: live
                        ? Colors.white
                        : busy
                        ? C.warn
                        : C.text,
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
