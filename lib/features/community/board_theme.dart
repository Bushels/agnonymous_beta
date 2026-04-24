import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BoardColors {
  static const Color prairie = Color(0xFF171812);
  static const Color paper = Color(0xFF25271F);
  static const Color field = Color(0xFF1D301D);
  static const Color ink = Color(0xFFF7F3E7);
  static const Color muted = Color(0xFFB1B6A4);
  static const Color line = Color(0xFF3C4034);
  static const Color green = Color(0xFF59C85D);
  static const Color deepGreen = Color(0xFF2E8B37);
  static const Color amber = Color(0xFFE2BE63);
  static const Color monette = Color(0xFFD68651);
  static const Color sky = Color(0xFF7EA6C8);
  static const Color soil = Color(0xFF2D2419);
  static const Color clay = Color(0xFF4A3420);
}

class BoardText {
  static TextStyle get roomTitle => GoogleFonts.outfit(
        fontSize: 32,
        height: 0.95,
        fontWeight: FontWeight.w800,
        color: BoardColors.ink,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 19,
        height: 1.12,
        fontWeight: FontWeight.w800,
        color: BoardColors.ink,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        height: 1.35,
        fontWeight: FontWeight.w500,
        color: BoardColors.ink,
      );

  static TextStyle get meta => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: BoardColors.muted,
      );
}

Color boardCategoryColor(String category) {
  switch (category.toLowerCase()) {
    case 'monette':
      return BoardColors.monette;
    case 'grain':
      return BoardColors.green;
    case 'ag business':
      return BoardColors.sky;
    case 'equipment':
      return const Color(0xFF7C5C2B);
    case 'land':
      return const Color(0xFF7E9F35);
    case 'politics':
      return const Color(0xFF7C4D9E);
    case 'weather':
      return const Color(0xFF2A7BA7);
    default:
      return BoardColors.amber;
  }
}
