import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';

class ChannelListScreen extends StatelessWidget {
  const ChannelListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return ChangeNotifierProvider(
      create: (_) => ChatProvider(
        apiService: auth.apiService,
        userId: auth.userId!,
        host: auth.host,
        port: auth.port,
        token: auth.jwtToken!,
      ),
      child: Consumer<ChatProvider>(
        builder: (context, chat, _) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Channels (${auth.userName ?? "User"})'),
              actions: [
                Container(
                  margin: const EdgeInsets.only(right: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: chat.wsConnected ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: chat.wsConnected ? Colors.green : Colors.red,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        chat.wsConnected ? 'ONLINE' : 'OFFLINE',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: chat.wsConnected ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            body: auth.channels.isEmpty
                ? const Center(child: Text('No channels assigned.'))
                : ListView.builder(
                    itemCount: auth.channels.length,
                    itemBuilder: (ctx, i) {
                      final ch = auth.channels[i];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFF1E293B),
                          child: Icon(
                            ch.kind == 'dm' ? Icons.person : Icons.tag,
                            color: Colors.white,
                          ),
                        ),
                        title: Text(ch.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('Type: ${ch.kind}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          chat.selectChannel(ch);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(
                                value: chat,
                                child: ChatScreen(channel: ch),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}
