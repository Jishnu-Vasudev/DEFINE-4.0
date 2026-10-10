import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../screens/chat_screen.dart';
import '../screens/scan_screen.dart';
import '../theme.dart';

// Open a channel's chat. From inside a chat, replace it so Back still returns to the list.
void openChannel(BuildContext context, Map<String, dynamic> ch, {bool replace = false}) {
  final route = MaterialPageRoute(builder: (_) => ChatScreen(channel: ch));
  replace ? Navigator.pushReplacement(context, route) : Navigator.push(context, route);
}

Future<Map<String, dynamic>?> showJoinChannelSheet(BuildContext context) => showModalBottomSheet<Map<String, dynamic>>(
  context: context,
  isScrollControlled: true,
  backgroundColor: C.panel,
  showDragHandle: true,
  builder: (_) => const _JoinSheet(),
);

// Joined channels plus "Join another channel"; returns the channel to open.
Future<void> showChannelSwitcher(BuildContext context) async {
  final picked = await showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: C.panel,
    showDragHandle: true,
    builder: (c) => const _Switcher(),
  );
  if (picked != null && context.mounted && picked['id'] != context.read<AppState>().activeChannelId) {
    openChannel(context, picked, replace: true);
  }
}

class _Switcher extends StatelessWidget {
  const _Switcher();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .7),
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text('Your channels', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            for (final ch in s.channels)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: avatarColor(ch['name']),
                  child: Icon(ch['kind'] == 'zone' ? Icons.place_outlined : Icons.groups_2_outlined, color: Colors.white, size: 20),
                ),
                title: Text(channelTitle(ch, s.userName)),
                trailing: ch['id'] == s.activeChannelId ? Icon(Icons.check_circle, color: C.accent) : null,
                onTap: () => Navigator.pop(context, ch),
              ),
            const Divider(height: 1),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: C.panel2,
                child: Icon(Icons.add, color: C.accent),
              ),
              title: const Text('Join another channel'),
              subtitle: Text('Scan a QR or enter a code', style: TextStyle(color: C.muted)),
              onTap: () async {
                final ch = await showJoinChannelSheet(context);
                if (ch != null && context.mounted) Navigator.pop(context, ch);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet();
  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _err;

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (raw == null) return;
    _code.text = inviteCode(raw);
    _join();
  }

  Future<void> _join() async {
    if (_code.text.trim().isEmpty) return setState(() => _err = 'Enter the channel code.');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final ch = await context.read<AppState>().joinChannel(_code.text);
      if (mounted) Navigator.pop(context, ch);
    } catch (e) {
      setState(() => _err = e.toString().contains('invalid') ? 'No channel has that code.' : 'Can\'t reach the server.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Join a channel', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        OutlinedButton.icon(onPressed: _busy ? null : _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan channel QR')),
        Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'or enter the code',
            textAlign: TextAlign.center,
            style: TextStyle(color: C.muted),
          ),
        ),
        TextField(
          controller: _code,
          textCapitalization: TextCapitalization.characters,
          textInputAction: TextInputAction.go,
          onSubmitted: (_) => _join(),
          decoration: const InputDecoration(labelText: 'Channel code', prefixIcon: Icon(Icons.key_outlined)),
        ),
        if (_err != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_err!, style: TextStyle(color: C.danger)),
          ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _busy ? null : _join,
          child: _busy ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5)) : const Text('Join'),
        ),
      ],
    ),
  );
}

// Long-press menu: members can leave; admins can also delete the channel for everyone.
Future<void> showChannelActions(BuildContext context, Map<String, dynamic> ch) async {
  final s = context.read<AppState>();
  final action = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: C.panel,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(channelTitle(ch, s.userName), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          ListTile(
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Leave channel'),
            subtitle: Text('Remove it from your list. Rejoin with its code.', style: TextStyle(color: C.muted)),
            onTap: () => Navigator.pop(c, 'leave'),
          ),
          if (s.role == 'admin')
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: C.danger),
              title: Text('Delete channel', style: TextStyle(color: C.danger)),
              subtitle: Text('For everyone, with all messages and files.', style: TextStyle(color: C.muted)),
              onTap: () => Navigator.pop(c, 'delete'),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return;
  final del = action == 'delete';
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(del ? 'Delete ${channelTitle(ch, s.userName)}?' : 'Leave ${channelTitle(ch, s.userName)}?'),
      content: Text(
        del
            ? 'Everyone loses this channel, its messages and files. This cannot be undone.'
            : 'You stop getting its messages and talk. You can rejoin with the channel code.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.pop(c, true),
          child: Text(del ? 'Delete' : 'Leave', style: TextStyle(color: C.danger)),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;
  final msg = ScaffoldMessenger.of(context);
  try {
    del ? await s.deleteChannel(ch['id']) : await s.leaveChannel(ch['id']);
  } catch (e) {
    msg.showSnackBar(SnackBar(content: Text('Could not ${del ? 'delete' : 'leave'}: $e')));
  }
}
