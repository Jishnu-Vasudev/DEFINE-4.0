import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ptt.dart';
import 'screens/channels_screen.dart';
import 'screens/join_screen.dart';
import 'screens/splash_screen.dart';
import 'theme.dart';
import 'widgets/alert_overlay.dart';
import 'widgets/incoming_call.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterForegroundTask.initCommunicationPort();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppState()..init()),
        ChangeNotifierProvider(create: (c) => Ptt(c.read<AppState>()), lazy: false),
      ],
      child: const BunnyHopApp(),
    ),
  );
}

class BunnyHopApp extends StatefulWidget {
  const BunnyHopApp({super.key});
  @override
  State<BunnyHopApp> createState() => _BunnyHopAppState();
}

class _BunnyHopAppState extends State<BunnyHopApp> {
  bool _minSplash = true;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _minSplash = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>();
    return MaterialApp(
      title: 'BunnyHop',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      navigatorKey: navigatorKey,
      builder: (_, child) => Stack(children: [child!, const IncomingCall(), const AlertOverlay()]),
      home: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: (!s.ready || _minSplash)
            ? const SplashScreen(key: ValueKey('splash'))
            : s.loggedIn
            ? const ChannelsScreen(key: ValueKey('home'))
            : const JoinScreen(key: ValueKey('join')),
      ),
    );
  }
}
