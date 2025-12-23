import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/login_screen.dart';
import 'views/home_screen.dart';
import 'views/report_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://banykdabftrzqbuhlcvl.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJhbnlrZGFiZnRyenFidWhsY3ZsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjYzMjA2MTEsImV4cCI6MjA4MTg5NjYxMX0._CRZtLWCTdlxqcV5PBNYWcQbu-sJ8TiB01HTkyBd8Ek',
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/report': (context) => const ReportScreen(),
      },
    );
  }
}