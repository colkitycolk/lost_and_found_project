import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/login_screen.dart';
import 'views/report_screen.dart';
import 'views/main_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'http://192.168.137.1:60021',
    anonKey:
        'sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH',
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
        '/home': (context) => const MainWrapper(), // Changed from HomeScreen to MainWrapper
        '/report': (context) => const ReportScreen(),
      },
    );
  }
}
