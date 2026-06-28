import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'screens/offline_edit_screen.dart';
import 'screens/history_screen.dart';
import 'screens/ai_mode_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const MeterSetProApp());
}

class MeterSetProApp extends StatelessWidget {
  const MeterSetProApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MeterSet Pro',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF00E5FF),
        scaffoldBackgroundColor: const Color(0xFF0A0A0A),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00E5FF),
          secondary: Color(0xFFFFD600),
          surface: Color(0xFF1A1A1A),
        ),
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF00E5FF),
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        snackBarTheme: const SnackBarThemeData(
          backgroundColor: Color(0xFF1A1A1A),
          contentTextStyle: TextStyle(color: Colors.white),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const HomeScreen(),
        '/offline-edit': (context) => const OfflineEditScreen(),
        '/history': (context) => const HistoryScreen(),
        '/ai-mode': (context) => const AIModeScreen(),
      },
    );
  }
}
