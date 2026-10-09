import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/channel.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import '../widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  final Channel channel;
  const ChatScreen({super.key, required this.channel});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final chat = Provider.of<ChatProvider>(context, listen: false);
    chat.sendTextMessage(text);
    _inputController.clear();

    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${widget.channel.name}', style: const TextStyle(fontSize: 16)),
            Text(
              chat.wsConnected ? 'Connected' : 'Offline / Reconnecting',
              style: TextStyle(
                fontSize: 11,
                color: chat.wsConnected ? Colors.lightGreenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Emergency Broadcast Banner
          if (chat.activeBroadcast != null)
            Container(
              color: Colors.red.shade900,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'EMERGENCY BROADCAST',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                        Text(
                          chat.activeBroadcast!['message']?['body'] ?? '',
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => chat.dismissBroadcast(),
                    style: TextButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                    child: const Text('ACK'),
                  ),
                ],
              ),
            ),

          // Talker banner
          if (chat.currentTalker != null)
            Container(
              color: Colors.red.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.mic, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${chat.currentTalker} is talking...',
                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),

          // Messages List
          Expanded(
            child: chat.messages.isEmpty
                ? const Center(child: Text('No messages yet. Send one below!'))
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: chat.messages.length,
                    itemBuilder: (ctx, i) {
                      final msg = chat.messages[i];
                      final isMe = msg.senderId == auth.userId;
                      return MessageBubble(message: msg, isMe: isMe);
                    },
                  ),
          ),

          // Bottom Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message...',
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send, color: Color(0xFF3B82F6)),
                    onPressed: _send,
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
