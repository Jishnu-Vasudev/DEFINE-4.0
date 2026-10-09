import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
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
  final ImagePicker _picker = ImagePicker();

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

  void _pickAndSendPhoto() async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );
    if (image != null) {
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final chat = Provider.of<ChatProvider>(context, listen: false);
      await chat.sendImageMessage(bytes, image.name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final chat = Provider.of<ChatProvider>(context);

    // Show floor denial snackbar if triggered
    if (chat.floorDeniedReason != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(chat.floorDeniedReason!),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 2),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('#${widget.channel.name}', style: const TextStyle(fontSize: 16)),
            Text(
              chat.wsConnected ? 'Connected (Voice Room Active)' : 'Offline / Reconnecting',
              style: TextStyle(
                fontSize: 11,
                color: chat.wsConnected ? Colors.lightGreenAccent : Colors.orangeAccent,
              ),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Active 1:1 Call Banner
              if (chat.isInCall)
                Container(
                  color: Colors.green.shade800,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.phone_in_talk, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          '1:1 Voice Call Active',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () => chat.end1to1Call(),
                        style: TextButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                        child: const Text('End Call'),
                      ),
                    ],
                  ),
                ),

              // Talker banner (someone else speaking)
              if (chat.currentTalker != null)
                Container(
                  color: Colors.red.withOpacity(0.25),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.mic, color: Colors.redAccent, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${chat.currentTalker} is talking...',
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const Text(
                        'PTT LOCKED',
                        style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),

              // Active transmission banner (I am speaking)
              if (chat.isTalking)
                Container(
                  color: Colors.green.withOpacity(0.3),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: const Row(
                    children: [
                      Icon(Icons.mic, color: Colors.greenAccent, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'TRANSMITTING VOICE (MIC LIVE)',
                          style: TextStyle(
                            color: Colors.greenAccent,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // Messages List
              Expanded(
                child: chat.messages.isEmpty
                    ? const Center(child: Text('No messages in this channel yet.'))
                    : ListView.builder(
                        controller: _scrollController,
                        itemCount: chat.messages.length,
                        itemBuilder: (ctx, i) {
                          final msg = chat.messages[i];
                          final isMe = msg.senderId == auth.userId;
                          return MessageBubble(
                            message: msg,
                            isMe: isMe,
                            baseUrl: 'http://${auth.host}:${auth.port}',
                            jwtToken: auth.jwtToken,
                          );
                        },
                      ),
              ),

              // Bottom Bar: PTT Button & Text/Photo input
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Hold to Talk PTT Button
                      GestureDetector(
                        onTapDown: (_) => chat.startTalking(),
                        onTapUp: (_) => chat.stopTalking(),
                        onTapCancel: () => chat.stopTalking(),
                        child: Container(
                          width: double.infinity,
                          height: 54,
                          margin: const EdgeInsets.only(bottom: 8),
                          decoration: BoxDecoration(
                            color: chat.isTalking
                                ? const Color(0xFF10B981)
                                : (chat.isRequestingFloor
                                    ? const Color(0xFFF59E0B)
                                    : (chat.currentTalker != null
                                        ? const Color(0xFF475569)
                                        : const Color(0xFF2563EB))),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: chat.isTalking
                                ? [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withOpacity(0.5),
                                      blurRadius: 12,
                                      spreadRadius: 2,
                                    )
                                  ]
                                : [],
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                chat.isTalking ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 28,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                chat.isTalking
                                    ? 'RELEASE TO LISTEN'
                                    : (chat.isRequestingFloor
                                        ? 'REQUESTING FLOOR...'
                                        : (chat.currentTalker != null
                                            ? 'FLOOR BUSY'
                                            : 'HOLD TO TALK (PTT)')),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Text and Media input bar
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.photo_camera, color: Color(0xFF94A3B8)),
                            onPressed: _pickAndSendPhoto,
                          ),
                          Expanded(
                            child: TextField(
                              controller: _inputController,
                              decoration: const InputDecoration(
                                hintText: 'Type text message...',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8),
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
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Incoming 1:1 Voice Call Dialog
          if (chat.incomingCall != null)
            Container(
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.blueAccent, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_in_talk, color: Colors.blueAccent, size: 56),
                      const SizedBox(height: 16),
                      Text(
                        'Incoming Voice Call from ${chat.incomingCall!['from_name'] ?? 'User'}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton(
                            onPressed: () => chat.declineIncomingCall(),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            child: const Text('Decline'),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton(
                            onPressed: () => chat.acceptIncomingCall(),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                            child: const Text('Accept Call'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Full-screen Emergency Broadcast Alert Modal
          if (chat.activeBroadcast != null && chat.activeBroadcast!['emergency'] == true)
            Container(
              color: Colors.black.withOpacity(0.85),
              padding: const EdgeInsets.all(24),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF991B1B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'EMERGENCY BROADCAST',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        chat.activeBroadcast!['message']?['body'] ?? '',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () => chat.dismissBroadcast(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red.shade900,
                          minimumSize: const Size(200, 48),
                        ),
                        child: const Text(
                          'ACKNOWLEDGE (ACK)',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
