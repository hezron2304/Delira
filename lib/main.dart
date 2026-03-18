import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/login_page.dart';
import 'package:delira/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pdhvqcbnsncxkfspasjq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkaHZxY2Juc25jeGtmc3Bhc2pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzU4MDAsImV4cCI6MjA4OTQxMTgwMH0.jnKXzrsmsKQ5bq8cvl9FAK70TfggD8XbJuAmgXj6rq8',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'Delira',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E6B4A)),
        useMaterial3: true,
      ),
      home: session != null ? const HomePage() : const LoginPage(),
    );
  }
}
