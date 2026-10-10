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

class _PttButtonState extends State<PttButton> with SingleTickerProviderStateMixin {
  bool _down = false;
  late final _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100));

  @override
  void initState() {
    super.initState();
    context.read<Ptt>().prewarm(widget.channelId);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

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
    final emergency = busy && other.priority >= 3;
    final notice = ptt.preemptNotice;
    if (notice != null) {
      ptt.preemptNotice = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _down = false);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(backgroundColor: C.danger, content: Text(notice)));
        }
      });
    }
    final toggle = context.select<AppState, bool>((s) => s.toggleTalk);
    final label = live
        ? (toggle ? 'Talking… tap to stop' : 'Talking… release to stop')
        : _down
        ? 'Connecting…'
        : busy
        ? (emergency ? 'EMERGENCY: ${other.name}' : '${other.name} is talking')
        : (toggle ? 'Tap to talk' : 'Hold to talk');

    // live: the mic orb breathes; otherwise it rests
    if (live && !_pulse.isAnimating && !MediaQuery.of(context).disableAnimations) _pulse.repeat(reverse: true);
    if (!live && _pulse.isAnimating) _pulse.stop();
    final fg = live
        ? C.accentInk
        : busy
        ? (emergency ? C.danger : C.warn)
        : C.text;

    return Semantics(
      button: true,
      label: toggle ? 'Tap to talk' : 'Push to talk',
      child: GestureDetector(
        // hold mode: down = talk, up = stop. toggle mode: each tap flips.
        onTapDown: toggle ? null : (_) => _press(),
        onTapUp: toggle ? null : (_) => _release(),
        onTapCancel: toggle ? null : _release,
        onTap: toggle ? () => (live || _down) ? _release() : _press() : null,
        child: AnimatedScale(
          scale: _down && !live ? .97 : 1,
          duration: const Duration(milliseconds: 120),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 62,
            padding: const EdgeInsets.symmetric(horizontal: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(31),
              gradient: live ? LinearGradient(colors: [C.accent, C.ember]) : null,
              color: live ? null : C.panel2,
              border: Border.all(
                color: live
                    ? C.accent
                    : busy
                    ? (emergency ? C.danger : C.warn.withValues(alpha: .6))
                    : C.line,
                width: 1.3,
              ),
              boxShadow: live ? [BoxShadow(color: C.ember.withValues(alpha: .5), blurRadius: 28, offset: const Offset(0, 8))] : null,
            ),
            child: Row(
              children: [
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, child) => Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: live ? Colors.white.withValues(alpha: .28) : C.accent.withValues(alpha: .14),
                      boxShadow: live
                          ? [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: .35 * _pulse.value),
                                blurRadius: 6 + 14 * _pulse.value,
                                spreadRadius: 4 * _pulse.value,
                              ),
                            ]
                          : null,
                    ),
                    child: child,
                  ),
                  child: Icon(
                    live
                        ? Icons.mic_rounded
                        : busy
                        ? Icons.volume_up_rounded
                        : Icons.mic_none_rounded,
                    color: live ? C.accentInk : (busy ? (emergency ? C.danger : C.warn) : C.accent),
                    size: 24,
                  ),
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    child: Text(
                      label,
                      key: ValueKey(label),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: fg),
                    ),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
