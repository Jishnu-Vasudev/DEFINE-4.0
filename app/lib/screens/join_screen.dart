import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import 'scan_screen.dart';

class JoinScreen extends StatefulWidget {
  const JoinScreen({super.key});
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final _name = TextEditingController();
  final _host = TextEditingController();
  final _code = TextEditingController();
  bool _busy = false;
  bool _manual = false;
  String? _err;

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const ScanScreen()));
    if (raw == null) return;
    try {
      final p = jsonDecode(raw) as Map<String, dynamic>;
      _host.text = '${p['host']}:${p['port'] ?? 3000}';
      _code.text = p['code'];
      setState(() => _err = null);
      if (_name.text.trim().isNotEmpty) _join();
    } catch (_) {
      setState(() => _err = 'That QR is not a team invite.');
    }
  }

  Future<void> _join() async {
    if (_name.text.trim().isEmpty) return setState(() => _err = 'Enter your name first.');
    if (_host.text.trim().isEmpty || _code.text.trim().isEmpty)
      return setState(() => _err = 'Scan the invite QR or enter server and code.');
    final parts = _host.text.trim().split(':');
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      await context.read<AppState>().join(parts[0], parts.length > 1 ? int.tryParse(parts[1]) ?? 3000 : 3000, _code.text, _name.text);
    } catch (e) {
      setState(
        () => _err = e.toString().contains('invite')
            ? 'Invite code is invalid or already used.'
            : 'Can\'t reach the server. Are you on the team Wi-Fi?',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = _host.text.isNotEmpty && _code.text.isNotEmpty;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: C.accent, borderRadius: BorderRadius.circular(20)),
              child: const Icon(Icons.settings_input_antenna, color: C.accentInk, size: 34),
            ),
            const SizedBox(height: 24),
            const Text('Join your team', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Private network. Ask your admin for an invite QR.', style: TextStyle(color: C.muted, fontSize: 15)),
            const SizedBox(height: 32),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 16),
            if (ready && !_manual)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: C.panel2,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: C.accent.withValues(alpha: .5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_outlined, color: C.accent),
                    const SizedBox(width: 12),
                    Expanded(child: Text('Invite ${_code.text}\n${_host.text}', style: const TextStyle(height: 1.4))),
                  ],
                ),
              ),
            if (_manual) ...[
              TextField(
                controller: _host,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Server (e.g. 192.168.1.10:3000)', prefixIcon: Icon(Icons.dns_outlined)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(labelText: 'Invite code', prefixIcon: Icon(Icons.key_outlined)),
              ),
            ],
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(_err!, style: const TextStyle(color: C.danger)),
              ),
            const SizedBox(height: 24),
            if (ready || _manual)
              FilledButton(
                onPressed: _busy ? null : _join,
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Join'),
              )
            else
              FilledButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: const Text('Scan invite QR')),
            const SizedBox(height: 12),
            if (!ready || _manual)
              TextButton(
                onPressed: () => setState(() => _manual = !_manual),
                child: Text(_manual ? 'Scan a QR instead' : 'Enter code manually', style: const TextStyle(color: C.muted)),
              ),
            if (ready && !_manual)
              TextButton(
                onPressed: _scan,
                child: const Text('Scan again', style: TextStyle(color: C.muted)),
              ),
          ],
        ),
      ),
    );
  }
}
