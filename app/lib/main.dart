import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:provider/provider.dart';

import 'app_state.dart';
import 'ptt.dart';
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
      child: const RelayApp(),
    ),
  );
}

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<AppState>(); // theme switches rebuild the app
    return MaterialApp(
      title: 'Bunny Hop',
      debugShowCheckedModeBanner: false,
      theme: appTheme(),
      navigatorKey: navigatorKey,
      builder: (_, child) => Stack(children: [child!, const IncomingCall(), const AlertOverlay()]),
      home: const SplashGate(),
    );
  }
}
