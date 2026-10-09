import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<AppState>().sync(widget.channel['id']);
  }

  void _send() {
    final t = _text.text.trim();
    if (t.isEmpty) return;
    context.read<AppState>().sendText(widget.channel['id'], t);
    _text.clear();
  }

  Future<void> _attach() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: C.panel,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take photo'),
              onTap: () => Navigator.pop(c, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(c, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (src == null) return;
    // picker resizes on device so uploads stay small on a busy network
    final f = await ImagePicker().pickImage(source: src, maxWidth: 1280, maxHeight: 1280, imageQuality: 80);
    if (f != null && mounted) context.read<AppState>().sendImage(widget.channel['id'], f.path);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    final ch = widget.channel;
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: avatarColor(ch['name']),
              child: Icon(ch['kind'] == 'zone' ? Icons.place_outlined : Icons.groups_2_outlined, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(ch['name'], overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.toggleTalk ? 'Talk mode: tap to toggle' : 'Talk mode: hold to talk',
            icon: Icon(s.toggleTalk ? Icons.touch_app_rounded : Icons.pan_tool_alt_outlined),
            onPressed: () {
              s.setToggleTalk(!s.toggleTalk);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    duration: const Duration(seconds: 2),
                    content: Text(
                      s.toggleTalk ? 'Tap to talk: tap once to start, again to stop' : 'Hold to talk: hold the button while speaking',
                    ),
                  ),
                );
            },
          ),
          IconButton(
            tooltip: 'People',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => showModalBottomSheet(
              context: context,
              backgroundColor: C.panel,
              showDragHandle: true,
              builder: (_) => MembersSheet(channelId: ch['id']),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const ConnBanner(),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: s.store.messages(ch['id']),
              builder: (_, snap) {
                final msgs = snap.data ?? [];
                if (msgs.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Say hi 👋', style: TextStyle(color: C.muted)),
                  );
                }
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
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  PttButton(channelId: ch['id']),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      IconButton(
                        onPressed: _attach,
                        tooltip: 'Send photo',
                        style: IconButton.styleFrom(minimumSize: const Size(46, 50)),
                        icon: const Icon(Icons.add_photo_alternate_outlined, color: C.muted),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _text,
                          minLines: 1,
                          maxLines: 5,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: InputDecoration(
                            hintText: 'Message',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: C.line),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: C.line),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: const BorderSide(color: C.accent),
                            ),
                          ),
                          onSubmitted: (_) => _send(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _send,
                        tooltip: 'Send',
                        style: IconButton.styleFrom(minimumSize: const Size(50, 50)),
                        icon: const Icon(Icons.send_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
