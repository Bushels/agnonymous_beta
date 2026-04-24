import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- THEME ---
final theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  primaryColor: const Color(0xFF2F8C43),
  scaffoldBackgroundColor: const Color(0xFFFFF7E8),
  textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
    foregroundColor: Color(0xFF17211A),
  ),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF2F8C43),
    secondary: Color(0xFFE9A318),
    surface: Color(0xFFFFFCF5),
    error: Color(0xFFE5533D),
    onPrimary: Colors.white,
    onSurface: Color(0xFF17211A),
  ),
);
