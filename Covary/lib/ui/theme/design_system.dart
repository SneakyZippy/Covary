import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Covary 2026 Design System
///
/// A sleek, research-focused design language emphasizing clarity, 
/// motion, and glassmorphism.
class CovaryDesignSystem {
  // --- Raw Color Palette (Midnight Navy & Accents) ---
  static const Color surface = Color(0xFF0e1512);
  static const Color surfaceDim = Color(0xFF0e1512);
  static const Color surfaceBright = Color(0xFF333b38);
  static const Color surfaceContainerLowest = Color(0xFF09100d);
  static const Color surfaceContainerLow = Color(0xFF161d1b);
  static const Color surfaceContainer = Color(0xFF1a211f);
  static const Color surfaceContainerHigh = Color(0xFF242c29);
  static const Color surfaceContainerHighest = Color(0xFF2f3633);
  static const Color onSurface = Color(0xFFdde4e0);
  static const Color onSurfaceVariant = Color(0xFFbacac3);
  static const Color inverseSurface = Color(0xFFdde4e0);
  static const Color inverseOnSurface = Color(0xFF2b322f);

  static const Color outline = Color(0xFF85948e);
  static const Color outlineVariant = Color(0xFF3c4a45);
  static const Color surfaceTint = Color(0xFF38debb);

  // Default Primary Theme (Aquamarine)
  static const Color primary = Color(0xFF38debb); // Adjusted from #ffffff to match surfaceTint / brand intent
  static const Color onPrimary = Color(0xFF00382d);
  static const Color primaryContainer = Color(0xFF5ffbd6);
  static const Color onPrimaryContainer = Color(0xFF00725e);

  // Secondary Theme (Deep Violet)
  static const Color secondary = Color(0xFFcdbdff);
  static const Color onSecondary = Color(0xFF370096);
  static const Color secondaryContainer = Color(0xFF5203d5);
  static const Color onSecondaryContainer = Color(0xFFc0acff);

  // Tertiary Theme
  static const Color tertiary = Color(0xFFdec65a);
  static const Color onTertiary = Color(0xFF393000);
  static const Color tertiaryContainer = Color(0xFFfbe273);
  static const Color onTertiaryContainer = Color(0xFF756400);

  // Additional Palettes
  static const Color azure = Color(0xFF60a5fa);
  static const Color emerald = Color(0xFF34d399);
  static const Color coral = Color(0xFFfb923c);
  static const Color ruby = Color(0xFFfb7185);

  static const Color error = Color(0xFFffb4ab);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000a);
  static const Color onErrorContainer = Color(0xFFffdad6);

  static const Color background = Color(0xFF0e1512);
  static const Color onBackground = Color(0xFFdde4e0);

  // Elevated Neutrals & Levels (as defined in guidelines)
  static const Color level0Background = Color(0xFF0B1120); // Midnight Navy
  static const Color level1Surface = Color(0xFF162032);    // Layered Navy
  static const Color innerBorderColor = Color(0x662D3748); // 40% opacity 2D3748

  // --- Spacing ---
  static const double unit = 4.0;
  static const double marginMobile = 20.0;
  static const double gutter = 12.0;
  static const double stackSm = 8.0;
  static const double stackMd = 16.0;
  static const double stackLg = 32.0;
  static const double minTouchTarget = 48.0;

  // --- Rounded Shapes ---
  static const double radiusSm = 4.0;       // 0.25rem
  static const double radiusDefault = 8.0;  // 0.5rem
  static const double radiusMd = 12.0;      // 0.75rem (Interactive elements)
  static const double radiusLg = 16.0;      // 1rem (Cards)
  static const double radiusXl = 24.0;      // 1.5rem
  static const double radiusFull = 9999.0;  // Pills/Chips

  // --- Typography ---
  static TextTheme getTextTheme(BuildContext context) {
    return TextTheme(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        height: 40 / 32, // lineHeight / fontSize
        letterSpacing: -0.02 * 32,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 32 / 24,
        letterSpacing: -0.01 * 24,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 24 / 16,
        letterSpacing: 0,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 20 / 14,
        letterSpacing: 0,
      ),
      labelSmall: GoogleFonts.spaceGrotesk( // label-caps equivalent
        fontSize: 12,
        fontWeight: FontWeight.w600,
        height: 16 / 12,
        letterSpacing: 0.08 * 12,
      ),
      labelLarge: GoogleFonts.spaceGrotesk( // data-mono equivalent
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 20 / 14,
        letterSpacing: 0,
      ),
    );
  }
}
