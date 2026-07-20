import 'package:flutter/material.dart';

const _mint = Color(0xFF0E6B5A);
const _mintLight = Color(0xFF1A8A6E);

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mint,
          brightness: Brightness.light,
        ).copyWith(primary: _mint, secondary: _mintLight),
        scaffoldBackgroundColor: const Color(0xFFF7F9F8),
        cardColor: Colors.white,
        dividerColor: Colors.black12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          foregroundColor: Color(0xFF0A1F1A),
          elevation: 0,
        ),
        textTheme: const TextTheme().apply(
          fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'],
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _mint,
          brightness: Brightness.dark,
        ).copyWith(primary: _mint, secondary: _mintLight),
        scaffoldBackgroundColor: const Color(0xFF0D0D0D),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: Colors.white12,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          surfaceTintColor: Color(0xFF141414),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme().apply(
          fontFamilyFallback: ['Roboto', 'Arial', 'sans-serif'],
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
      );
}

// Extension giúp truy cập màu theo theme từ bất kỳ widget nào
extension AppColors on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bg => isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF7F9F8);
  Color get surface => isDark ? const Color(0xFF1E1E1E) : Colors.white;
  Color get surface2 => isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF2F4F1);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0A1F1A);
  Color get textSecondary =>
      isDark ? Colors.white60 : const Color(0xFF0A1F1A).withOpacity(0.55);
  Color get divider => isDark ? Colors.white12 : Colors.black.withOpacity(0.06);
  Color get iconMuted =>
      isDark ? Colors.white38 : const Color(0xFF0A1F1A).withOpacity(0.35);
  static const Color mint = _mint;
}
