import 'package:flutter/material.dart';
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
  bool _down = false;

  Future<void> _press() async {
    setState(() => _down = true);
    final ptt = context.read<Ptt>();
    final r = await ptt.press(widget.channelId);
    if (!mounted) return;
    if (r != PttResult.granted) {
      setState(() => _down = false);
      final who = ptt.talkers[widget.channelId]?.name;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(r == PttResult.denied ? '${who ?? 'Someone'} is talking — wait for them to finish' : 'Can\'t reach the server'),
          ),
        );
    }
  }

  void _release() {
    setState(() => _down = false);
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
    final color = live ? C.accent : C.panel2;
    final label = live
        ? (toggle ? 'Talking… tap to stop' : 'Talking… release to stop')
        : _down
        ? 'Connecting…'
        : busy
        ? '${other.name} is talking'
        : (toggle ? 'Tap to talk' : 'Hold to talk');

    return Semantics(
      button: true,
      label: toggle ? 'Tap to talk' : 'Push to talk',
      child: GestureDetector(
        // hold mode: down = talk, up = stop. toggle mode: each tap flips.
        onTapDown: toggle ? null : (_) => _press(),
        onTapUp: toggle ? null : (_) => _release(),
        onTapCancel: toggle ? null : _release,
        onTap: toggle ? () => (live || _down) ? _release() : _press() : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 64,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(
              color: live
                  ? C.accent
                  : busy
                  ? C.warn.withValues(alpha: .6)
                  : C.line,
              width: 1.5,
            ),
            boxShadow: live ? [BoxShadow(color: C.accent.withValues(alpha: .45), blurRadius: 24, spreadRadius: 2)] : null,
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
                    ? C.accentInk
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
                      ? C.accentInk
                      : busy
                      ? C.warn
                      : C.text,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
