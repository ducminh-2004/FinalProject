import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/main_screen.dart';
import 'screens/now_playing_screen.dart';
import 'screens/liked_songs_screen.dart';
import 'screens/artist_detail_screen.dart';
import 'screens/library_screen.dart';
import 'screens/admin/admin_dashboard_screen.dart';
import 'screens/artist_register_screen.dart';
import 'screens/artist_dashboard_screen.dart';
import 'firebase/firebase_service.dart';
import 'providers/audio_provider.dart';
import 'providers/user_provider.dart';
import 'providers/analytics_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FirebaseService.initialize();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AudioProvider()),
        ChangeNotifierProvider(create: (_) => UserProvider()),
        ChangeNotifierProvider(create: (_) => AnalyticsProvider()),
      ],
      child: MaterialApp(
        title: 'Spotify',
        debugShowCheckedModeBanner: false,
        initialRoute: '/',
        routes: {
          '/': (_) => const SplashScreen(),
          '/login': (_) => const LoginScreen(),
          '/register': (_) => const RegisterScreen(),
          '/forgot-password': (_) => const ForgotPasswordScreen(),
          '/main': (_) => const MainScreen(),
          '/library': (_) => const LibraryScreen(),
          '/admin-dashboard': (_) => const AdminDashboardScreen(),
          '/artist-register': (_) => const ArtistRegisterScreen(),
          '/artist-dashboard': (_) => const ArtistDashboardScreen(),
          '/now-playing': (_) => const NowPlayingScreen(),
          '/liked-songs': (_) => const LikedSongsScreen(),
        },
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E6B5A)),
          useMaterial3: true,
          scaffoldBackgroundColor: Colors.white,
          textTheme: const TextTheme().apply(
            fontFamilyFallback: const ['Roboto', 'Helvetica', 'Arial', 'sans-serif'],
          ),
        ),
      ),
    );
  }
}
