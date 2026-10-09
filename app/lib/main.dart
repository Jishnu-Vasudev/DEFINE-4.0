import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/join_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PttApp());
}

class PttApp extends StatelessWidget {
  const PttApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        title: 'PTT Communicator',
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark().copyWith(
          scaffoldBackgroundColor: const Color(0xFF0F172A),
          cardColor: const Color(0xFF1E293B),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF1E293B),
            elevation: 0,
          ),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF3B82F6),
            secondary: Color(0xFF10B981),
            surface: Color(0xFF1E293B),
          ),
        ),
        home: const JoinScreen(),
      ),
    );
  }
}
