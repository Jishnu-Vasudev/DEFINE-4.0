import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../perms.dart';
import '../theme.dart';

// 1:1 voice call in its own LiveKit room. Hang-up is detected when the other side leaves the room.
class CallScreen extends StatefulWidget {
  final String room, peerName;
  final bool outgoing;
  const CallScreen({super.key, required this.room, required this.peerName, required this.outgoing});
  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  final _room = Room();
  EventsListener<RoomEvent>? _events;
  String _status = 'Connecting…';
  bool _live = false, _muted = false, _speaker = false, _ended = false;
  final _clock = Stopwatch();
  Timer? _tick, _noAnswer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      if (!await Perms.mic()) return _end('Microphone is off');
      final t = await context.read<AppState>().api!.get('/livekit/token?room=${widget.room}');
      _events = _room.createListener()
        ..on<ParticipantConnectedEvent>((_) => _connected())
        ..on<ParticipantDisconnectedEvent>((_) => _end('Call ended'))
        ..on<RoomDisconnectedEvent>((_) => _end('Call ended'));
      await _room.connect(t['url'], t['token']);
      await AudioManager.instance.setSpeakerOutputPreferred(_speaker); // calls start on the earpiece
      await _room.localParticipant?.setMicrophoneEnabled(true);
      if (_room.remoteParticipants.isNotEmpty) {
        _connected();
      } else {
        setState(() => _status = widget.outgoing ? 'Ringing…' : 'Connecting…');
        _noAnswer = Timer(const Duration(seconds: 30), () => _end('No answer'));
      }
    } catch (_) {
      _end('Call failed');
    }
  }

  void _connected() {
    if (_live || _ended) return;
    _noAnswer?.cancel();
    _clock.start();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
    setState(() => _live = true);
  }

  Future<void> _end(String why) async {
    if (_ended) return;
    _ended = true;
    _tick?.cancel();
    _noAnswer?.cancel();
    _clock.stop();
    if (mounted) setState(() => _status = why);
    await _room.disconnect();
    AudioManager.instance.setSpeakerOutputPreferred(true); // push-to-talk wants the loudspeaker back
    await Future.delayed(const Duration(milliseconds: 900));
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _tick?.cancel();
    _noAnswer?.cancel();
    _events?.dispose();
    if (!_ended) {
      _room.disconnect();
      AudioManager.instance.setSpeakerOutputPreferred(true);
    }
    _room.dispose();
    super.dispose();
  }

  String get _elapsed {
    final s = _clock.elapsed.inSeconds;
    return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _ended,
      child: Scaffold(
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFF0B2A6B), C.bg]),
          ),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(),
                CircleAvatar(
                  radius: 56,
                  backgroundColor: avatarColor(widget.peerName),
                  child: Text(
                    initials(widget.peerName),
                    style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),
                Text(widget.peerName, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(
                  _live && !_ended ? _elapsed : _status,
                  style: TextStyle(
                    fontSize: 16,
                    color: _live && !_ended ? C.accent : C.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const Spacer(flex: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _RoundBtn(
                      icon: _muted ? Icons.mic_off_rounded : Icons.mic_rounded,
                      label: _muted ? 'Unmute' : 'Mute',
                      active: _muted,
                      onTap: () async {
                        setState(() => _muted = !_muted);
                        await _room.localParticipant?.setMicrophoneEnabled(!_muted);
                      },
                    ),
                    _RoundBtn(icon: Icons.call_end_rounded, label: 'End', color: C.danger, size: 76, onTap: () => _end('Call ended')),
                    _RoundBtn(
                      icon: _speaker ? Icons.volume_up_rounded : Icons.hearing_rounded,
                      label: 'Speaker',
                      active: _speaker,
                      onTap: () async {
                        setState(() => _speaker = !_speaker);
                        await AudioManager.instance.setSpeakerOutputPreferred(_speaker);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  final bool active;
  final double size;
  const _RoundBtn({required this.icon, required this.label, required this.onTap, this.color, this.active = false, this.size = 64});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? (active ? C.text : C.panel2);
    return Column(
      children: [
        Material(
          color: bg,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: 30,
                color: color != null
                    ? Colors.white
                    : active
                    ? C.bg
                    : C.text,
                semanticLabel: label,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(color: C.muted, fontSize: 13)),
      ],
    );
  }
}
