import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../ptt.dart';
import '../screens/call_screen.dart';
import '../theme.dart';

final navigatorKey = GlobalKey<NavigatorState>();

// Ringing banner over every screen; declining just lets the caller time out.
class IncomingCall extends StatefulWidget {
  const IncomingCall({super.key});
  @override
  State<IncomingCall> createState() => _IncomingCallState();
}

class _IncomingCallState extends State<IncomingCall> {
  Timer? _timeout;
  String? _room;

  @override
  Widget build(BuildContext context) {
    final ptt = context.watch<Ptt>();
    final call = ptt.incomingCall;
    if (call?['room'] != _room) {
      _room = call?['room'];
      _timeout?.cancel();
      if (call != null) _timeout = Timer(const Duration(seconds: 30), ptt.clearIncoming);
    }
    if (call == null) return const SizedBox.shrink();
    return Positioned(
      left: 12,
      right: 12,
      top: MediaQuery.of(context).padding.top + 8,
      child: Material(
        color: C.panel,
        elevation: 12,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor(call['name']),
                child: Text(initials(call['name']), style: const TextStyle(color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(call['name'], style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('Incoming voice call', style: TextStyle(color: C.muted)),
                  ],
                ),
              ),
              IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: C.danger, foregroundColor: Colors.white),
                onPressed: ptt.clearIncoming,
                icon: const Icon(Icons.call_end_rounded, semanticLabel: 'Decline'),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () {
                  ptt.clearIncoming();
                  navigatorKey.currentState?.push(
                    MaterialPageRoute(
                      builder: (_) => CallScreen(room: call['room'], peerName: call['name'], outgoing: false),
                    ),
                  );
                },
                icon: const Icon(Icons.call_rounded, semanticLabel: 'Answer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }
}
