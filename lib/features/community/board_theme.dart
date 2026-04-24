import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class BoardColors {
  static const Color prairie = Color(0xFFFFF7E8);
  static const Color paper = Color(0xFFFFFCF5);
  static const Color field = Color(0xFFE6F5D0);
  static const Color ink = Color(0xFF17211A);
  static const Color muted = Color(0xFF66715F);
  static const Color line = Color(0xFFE6DEC9);
  static const Color green = Color(0xFF2F8C43);
  static const Color deepGreen = Color(0xFF14642A);
  static const Color amber = Color(0xFFE9A318);
  static const Color monette = Color(0xFFE5533D);
  static const Color sky = Color(0xFF4E8FD8);
}

class BoardText {
  static TextStyle get roomTitle => GoogleFonts.outfit(
        fontSize: 34,
        height: 0.95,
        fontWeight: FontWeight.w800,
        color: BoardColors.ink,
      );

  static TextStyle get title => GoogleFonts.outfit(
        fontSize: 22,
        height: 1.05,
        fontWeight: FontWeight.w800,
        color: BoardColors.ink,
      );

  static TextStyle get body => GoogleFonts.inter(
        fontSize: 15,
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
