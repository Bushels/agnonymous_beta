import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Luxury design system for Agnonymous
/// Refined glassmorphism aesthetics with premium feel
class LuxuryTheme {
  LuxuryTheme._();

  // ═══════════════════════════════════════════════════════════════════════════
  // COLORS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary brand colors - Agricultural green palette
  static const Color primaryLight = Color(0xFFA3E635);  // Bright lime
  static const Color primary = Color(0xFF84CC16);       // Main green
  static const Color primaryDark = Color(0xFF65A30D);   // Deep green
  static const Color primaryDeep = Color(0xFF4D7C0F);   // Forest green

  /// Accent colors
  static const Color accentOrange = Color(0xFFF59E0B); // Warnings, partial
  static const Color accentAmber = Color(0xFFFBBF24);  // Highlights
  static const Color accentRed = Color(0xFFEF4444);    // Errors, negative

  /// Background colors - Deep dark palette
  static const Color backgroundDeep = Color(0xFF0A0F1A);   // Darkest
  static const Color backgroundDark = Color(0xFF111827);   // Main background
  static const Color backgroundMedium = Color(0xFF1F2937); // Cards, surfaces
  static const Color backgroundLight = Color(0xFF374151);  // Elevated surfaces

  /// Text colors
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);

  /// Glass effect colors
  static const Color glassWhite = Color(0xFFFFFFFF);
  static const Color glassBorder = Color(0x1FFFFFFF);  // 12% white
  static const Color glassHighlight = Color(0x33FFFFFF); // 20% white
  static const Color glassShadow = Color(0x66000000);  // 40% black

  // ═══════════════════════════════════════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Primary button gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryLight, primary, primaryDark],
    stops: [0.0, 0.5, 1.0],
  );

  /// Subtle primary glow gradient
  static const RadialGradient primaryGlow = RadialGradient(
    colors: [
      Color(0x4084CC16), // 25% primary
      Color(0x0084CC16), // 0% primary
    ],
  );

  /// Glass surface gradient
  static LinearGradient glassSurfaceGradient({double opacity = 0.1}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        glassWhite.withOpacity(opacity * 1.2),
        glassWhite.withOpacity(opacity * 0.8),
      ],
    );
  }

  /// Card background gradient
  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xE61F2937), // 90% surface
      Color(0xF2111827), // 95% background
    ],
  );

  /// Shimmer gradient for loading states
  static LinearGradient shimmerGradient(double position) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Colors.transparent,
        glassWhite.withOpacity(0.15),
        Colors.transparent,
      ],
      stops: [
        (position - 0.3).clamp(0.0, 1.0),
        position,
        (position + 0.3).clamp(0.0, 1.0),
      ],
    );
  }

  /// Gradient border colors
  static LinearGradient borderGradient({double intensity = 1.0}) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        glassWhite.withOpacity(0.2 * intensity),
        glassWhite.withOpacity(0.05 * intensity),
        glassWhite.withOpacity(0.1 * intensity),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════════════════════════════════════

  /// Standard card shadow
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.2),
      blurRadius: 20,
      spreadRadius: -5,
      offset: const Offset(0, 8),
    ),
  ];

  /// Elevated shadow for focused elements
  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.25),
      blurRadius: 30,
      spreadRadius: -5,
      offset: const Offset(0, 12),
    ),
  ];

  /// Primary glow shadow
  static List<BoxShadow> primaryGlowShadow({double intensity = 0.3}) {
    return [
      BoxShadow(
        color: primary.withOpacity(intensity * 0.5),
        blurRadius: 25,
        spreadRadius: -5,
      ),
      BoxShadow(
        color: Colors.black.withOpacity(0.2),
        blurRadius: 20,
        spreadRadius: -8,
        offset: const Offset(0, 8),
      ),
    ];
  }

  /// Bottom navigation shadow
  static List<BoxShadow> bottomNavShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: -5,
      offset: const Offset(0, -8),
    ),
    BoxShadow(
      color: primary.withOpacity(0.05),
      blurRadius: 40,
      spreadRadius: 0,
      offset: const Offset(0, -15),
    ),
  ];

  /// Button press shadow (reduced)
  static List<BoxShadow> pressedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.3),
      blurRadius: 10,
      spreadRadius: -3,
      offset: const Offset(0, 3),
    ),
  ];

  // ═══════════════════════════════════════════════════════════════════════════
  // BLUR VALUES
  // ═══════════════════════════════════════════════════════════════════════════

  static const double blurLight = 8.0;
  static const double blurMedium = 12.0;
  static const double blurStrong = 20.0;
  static const double blurIntense = 25.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // BORDER RADIUS
  // ═══════════════════════════════════════════════════════════════════════════

  static const double radiusSmall = 8.0;
  static const double radiusMedium = 12.0;
  static const double radiusLarge = 16.0;
  static const double radiusXL = 20.0;
  static const double radiusRound = 100.0;

  static BorderRadius get borderRadiusSmall => BorderRadius.circular(radiusSmall);
  static BorderRadius get borderRadiusMedium => BorderRadius.circular(radiusMedium);
  static BorderRadius get borderRadiusLarge => BorderRadius.circular(radiusLarge);
  static BorderRadius get borderRadiusXL => BorderRadius.circular(radiusXL);

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION DURATIONS
  // ═══════════════════════════════════════════════════════════════════════════

  static const Duration durationFast = Duration(milliseconds: 100);
  static const Duration durationNormal = Duration(milliseconds: 200);
  static const Duration durationMedium = Duration(milliseconds: 300);
  static const Duration durationSlow = Duration(milliseconds: 500);

  /// Glow animation duration (breathing effect)
  static const Duration glowDuration = Duration(milliseconds: 3000);

  /// Pulse animation duration
  static const Duration pulseDuration = Duration(milliseconds: 2000);

  /// Shimmer animation duration
  static const Duration shimmerDuration = Duration(milliseconds: 2500);

  // ═══════════════════════════════════════════════════════════════════════════
  // ANIMATION CURVES
  // ═══════════════════════════════════════════════════════════════════════════

  static const Curve curveEaseOut = Curves.easeOutCubic;
  static const Curve curveEaseIn = Curves.easeInCubic;
  static const Curve curveEaseInOut = Curves.easeInOut;
  static const Curve curveElastic = Curves.elasticOut;
  static const Curve curveBounce = Curves.bounceOut;

  // ═══════════════════════════════════════════════════════════════════════════
  // TYPOGRAPHY
  // ═══════════════════════════════════════════════════════════════════════════

  /// Display text style (large headers)
  static TextStyle displayLarge = GoogleFonts.outfit(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.5,
  );

  static TextStyle displayMedium = GoogleFonts.outfit(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: textPrimary,
    letterSpacing: -0.3,
  );

  static TextStyle displaySmall = GoogleFonts.outfit(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  /// Heading styles
  static TextStyle headingLarge = GoogleFonts.inter(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle headingMedium = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static TextStyle headingSmall = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  /// Body text styles
  static TextStyle bodyLarge = GoogleFonts.inter(
    fontSize: 16,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle bodyMedium = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    color: textPrimary,
    height: 1.5,
  );

  static TextStyle bodySmall = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.normal,
    color: textSecondary,
    height: 1.4,
  );

  /// Label styles
  static TextStyle labelLarge = GoogleFonts.inter(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  static TextStyle labelMedium = GoogleFonts.inter(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: textSecondary,
    letterSpacing: 0.3,
  );

  static TextStyle labelSmall = GoogleFonts.inter(
    fontSize: 10,
    fontWeight: FontWeight.w500,
    color: textMuted,
    letterSpacing: 0.5,
  );

  /// Button text style
  static TextStyle buttonText = GoogleFonts.inter(
    fontSize: 15,
    fontWeight: FontWeight.w600,
    color: textPrimary,
    letterSpacing: 0.3,
  );

  // ═══════════════════════════════════════════════════════════════════════════
  // SPACING
  // ═══════════════════════════════════════════════════════════════════════════

  static const double spacingXS = 4.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;
  static const double spacingXL = 24.0;
  static const double spacingXXL = 32.0;

  // ═══════════════════════════════════════════════════════════════════════════
  // THEME DATA
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create the complete theme
  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: backgroundDark,
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: accentOrange,
        surface: backgroundMedium,
        error: accentRed,
        onPrimary: textPrimary,
        onSecondary: textPrimary,
        onSurface: textPrimary,
        onError: textPrimary,
      ),
      cardTheme: CardThemeData(
        color: backgroundMedium,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusLarge,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: textPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: borderRadiusMedium,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: backgroundMedium.withOpacity(0.6),
        border: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: glassBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: borderRadiusMedium,
          borderSide: BorderSide(color: primary.withOpacity(0.5), width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      dividerTheme: DividerThemeData(
        color: glassBorder,
        thickness: 1,
        space: spacingLG,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: backgroundMedium,
        contentTextStyle: bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: borderRadiusMedium,
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

/// Extension methods for easy access to theme properties
extension LuxuryThemeExtension on BuildContext {
  /// Get primary color
  Color get primaryColor => LuxuryTheme.primary;

  /// Get background color
  Color get backgroundColor => LuxuryTheme.backgroundDark;

  /// Get surface color
  Color get surfaceColor => LuxuryTheme.backgroundMedium;

  /// Check if screen is mobile sized
  bool get isMobile => MediaQuery.of(this).size.width < 600;

  /// Check if screen is compact (very small mobile)
  bool get isCompact => MediaQuery.of(this).size.width < 400;

  /// Get responsive horizontal padding
  double get horizontalPadding {
    final width = MediaQuery.of(this).size.width;
    if (width > 800) return (width - 800) / 2;
    if (width > 600) return 24;
    return 16;
  }
}
