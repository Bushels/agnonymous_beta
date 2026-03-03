import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// --- THEME ---
final theme = ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  primaryColor: const Color(0xFF84CC16),
  scaffoldBackgroundColor: const Color(0xFF111827),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.transparent,
    elevation: 0,
  ),
  colorScheme: const ColorScheme.dark(
    primary: Color(0xFF84CC16),
    secondary: Color(0xFFF59E0B),
    surface: Color(0xFF1F2937),
    error: Color(0xFFEF4444),
  ),
);
