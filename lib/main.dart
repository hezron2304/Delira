import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:delira/theme/app_colors.dart';
import 'package:delira/splash_page.dart';

Future<void> main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Inisialisasi Environment Variables (API Key)
  await dotenv.load(fileName: ".env");

  await Supabase.initialize(
    url: 'https://pdhvqcbnsncxkfspasjq.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InBkaHZxY2Juc25jeGtmc3Bhc2pxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzM4MzU4MDAsImV4cCI6MjA4OTQxMTgwMH0.jnKXzrsmsKQ5bq8cvl9FAK70TfggD8XbJuAmgXj6rq8',
  );

  // >>> GLOBAL SYSTEM UI / EDGE-TO-EDGE FIX <<<
  // Mengaktifkan mode layar penuh (Edge-to-Edge) sehingga area Status Bar (atas)
  // dan Navigation Bar (bawah - Jendela/Home/Back) menjadi transparan mengikuti warna halaman.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor:
          AppColors.surface, // Background-matching default
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delira',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primary),
        useMaterial3: true,
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      home: const SplashPage(),
    );
  }
}
