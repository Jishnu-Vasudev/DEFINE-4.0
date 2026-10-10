import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../theme.dart';
import '../widgets/radar_logo.dart';
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
      setState(() => _err = 'That QR is not a channel invite.');
    }
  }

  Future<void> _join() async {
    if (_name.text.trim().isEmpty) return setState(() => _err = 'Enter your name first.');
    if (_host.text.trim().isEmpty || _code.text.trim().isEmpty)
      return setState(() => _err = 'Scan the channel QR or enter the code and server.');
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
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final ready = _host.text.trim().isNotEmpty && _code.text.trim().isNotEmpty;
    return Scaffold(
      body: EmberBackdrop(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            children: [
              const Center(child: RadarLogo()),
              const SizedBox(height: 8),
              const Text(
                'Join a channel',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -.8),
              ),
              const SizedBox(height: 8),
              Text(
                'Private network. Scan the channel QR from your admin, or type its code.',
                textAlign: TextAlign.center,
                style: TextStyle(color: C.muted, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: 'Your name',
                  prefixIcon: const Icon(Icons.person_outline_rounded),
                  suffixIcon: AnimatedScale(
                    scale: _name.text.trim().isEmpty ? 0 : 1,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutBack,
                    child: Icon(Icons.check_circle_rounded, color: C.accent),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: _busy ? null : _scan,
                child: const Row(
                  children: [
                    SizedBox(width: 4),
                    Icon(Icons.qr_code_scanner_rounded),
                    SizedBox(width: 12),
                    Expanded(child: Text('Scan channel QR')),
                    Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('or enter the code', style: TextStyle(color: C.muted)),
                    ),
                    Expanded(child: Divider()),
                  ],
                ),
              ),
              TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(letterSpacing: 3, fontWeight: FontWeight.w700),
                decoration: const InputDecoration(hintText: 'Channel code', prefixIcon: Icon(Icons.key_rounded)),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _host,
                keyboardType: TextInputType.url,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(hintText: 'Server, e.g. 192.168.1.10:3000', prefixIcon: Icon(Icons.dns_outlined)),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                child: _err == null
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 14),
                        child: Text(_err!, style: TextStyle(color: C.danger)),
                      ),
              ),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: _busy || !ready ? null : _join,
                style: OutlinedButton.styleFrom(side: BorderSide(color: ready ? C.accent : C.line)),
                child: _busy
                    ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
                    : const Text('Join with code', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
