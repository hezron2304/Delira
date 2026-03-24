import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:delira/login_page.dart';
import 'package:delira/home_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

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
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: session != null ? const HomePage() : const LoginPage(),
    );
  }
}
