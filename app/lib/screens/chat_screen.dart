import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/attach.dart';
import '../widgets/channel_nav.dart';
import '../widgets/conn_banner.dart';
import '../widgets/members_sheet.dart';
import '../widgets/message_bubble.dart';
import '../widgets/ptt_button.dart';

class ChatScreen extends StatefulWidget {
  final Map<String, dynamic> channel;
  const ChatScreen({super.key, required this.channel});
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _text = TextEditingController();
  late final AppState _app;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    // channel deleted / left / removed while open: go back to the list and say why
    _sub = context.read<AppState>().events.listen((e) {
      if (e['t'] != 'channel_gone' || e['channel_id'] != widget.channel['id'] || !mounted) return;
      final msg = ScaffoldMessenger.of(context);
      Navigator.of(context).popUntil((r) => r.isFirst);
      msg.showSnackBar(SnackBar(content: Text('${e['name']} ${e['reason'] == 'left' ? 'left' : 'was ${e['reason']}'}.')));
    });
    _app = context.read<AppState>()..openedChannel(widget.channel['id']);
    _app.sync(widget.channel['id']);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _app.closedChannel(widget.channel['id']);
    _text.dispose();
    super.dispose();
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    context.read<AppState>().sendText(widget.channel['id'], t);
    _text.clear();
  }

  Future<void> _attach() async {
    final a = await pickAttachment(context);
    if (a == null || !mounted) return;
    final s = context.read<AppState>();
    a.type == 'image' ? s.sendImage(widget.channel['id'], a.path) : s.sendMedia(widget.channel['id'], a.path, a.type, a.name);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ch = widget.channel;
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 64,
        titleSpacing: 0,
        title: InkWell(
          onTap: () => showChannelSwitcher(context),
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            // both lines shrink with ellipsis so the header never overflows on narrow phones or large fonts
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(child: Text(channelTitle(ch, s.userName), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Icon(Icons.expand_more_rounded, size: 20, color: C.muted),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(shape: BoxShape.circle, color: s.connected ? C.accent : C.muted),
                    ),
                    const SizedBox(width: 6),
                    Icon(Icons.lock_rounded, size: 11, color: C.accent),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        '${ch['kind'] == 'dm' ? 'Direct · ' : ''}Encrypted${s.monitored ? ' · org monitored' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.5, color: C.accent, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          RoundButton(icon: Icons.swap_horiz_rounded, tooltip: 'Switch or join channel', onTap: () => showChannelSwitcher(context)),
          const SizedBox(width: 8),
          RoundButton(
            icon: Icons.people_alt_outlined,
            tooltip: 'People',
            onTap: () => showModalBottomSheet(
              context: context,
              showDragHandle: true,
              builder: (_) => MembersSheet(channelId: ch['id']),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: EmberBackdrop(
        child: Column(
          children: [
            const ConnBanner(),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: s.store.messages(ch['id']),
                builder: (_, snap) {
                  final msgs = snap.data ?? [];
                  if (msgs.isEmpty && snap.connectionState == ConnectionState.done) return const _EmptyChat();
                  return ListView.builder(
                    reverse: true,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    itemCount: msgs.length,
                    itemBuilder: (_, i) {
                      final m = msgs[msgs.length - 1 - i];
                      final prev = i + 1 < msgs.length ? msgs[msgs.length - 2 - i] : null;
                      return MessageBubble(
                        m: m,
                        mine: m['sender_id'] == s.userId,
                        showName: prev == null || prev['sender_id'] != m['sender_id'],
                      );
                    },
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Container(
                margin: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
                decoration: glass(radius: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PttButton(channelId: ch['id']),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        IconButton(
                          onPressed: _attach,
                          tooltip: 'Attach photo, video, audio or file',
                          style: IconButton.styleFrom(minimumSize: const Size(46, 48)),
                          icon: Icon(Icons.attach_file_rounded, color: C.muted),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _text,
                            minLines: 1,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: 'Message',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(22), borderSide: BorderSide.none),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: C.accent),
                              ),
                            ),
                            onSubmitted: (_) => _send(),
                          ),
                        ),
                        const SizedBox(width: 6),
                        IconButton.filled(
                          onPressed: _send,
                          tooltip: 'Send',
                          style: IconButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            backgroundColor: C.accent,
                            foregroundColor: C.accentInk,
                          ),
                          icon: const Icon(Icons.send_rounded, size: 20),
                        ),
                      ],
                    ),
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

class _EmptyChat extends StatelessWidget {
  const _EmptyChat();
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Opacity(opacity: .85, child: Logo(size: 72)),
        SizedBox(height: 16),
        Text('No messages yet. Say hi', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        SizedBox(height: 4),
        Text('Hold the talk button to speak to everyone here.', style: TextStyle(color: C.muted)),
      ],
    ),
  );
}
