import 'package:flutter/material.dart';
import '../../services/theme_service.dart' show AppBackgroundStyle;
import 'design_system.dart';

class AppTheme {
  static ThemeData buildTheme({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
    required AppBackgroundStyle backgroundStyle,
  }) {
    final textTheme = CovaryDesignSystem.getTextTheme(context);

    // Create a color scheme based on the selected primary color.
    // For dark mode, we inject the specific backgrounds based on selected style.
    final isWhiteAccent = primaryColor == Colors.white;

    final Color surfaceColor = isDark
        ? (backgroundStyle == AppBackgroundStyle.pureBlack
            ? const Color(0xFF0F0F11)
            : (backgroundStyle == AppBackgroundStyle.deepCharcoal
                ? const Color(0xFF1A1A1E)
                : CovaryDesignSystem.surface))
        : Colors.white;

    ColorScheme colorScheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: isWhiteAccent ? const Color(0xFF94A3B8) : primaryColor,
            brightness: Brightness.dark,
            surface: surfaceColor,
            onSurface: CovaryDesignSystem.onSurface,
            error: CovaryDesignSystem.error,
          )
        : ColorScheme.fromSeed(
            seedColor: isWhiteAccent ? const Color(0xFF64748B) : primaryColor,
            brightness: Brightness.light,
          ).copyWith(
            surface: Colors.white,
            surfaceContainer: Colors.white,
            surfaceContainerHigh: Colors.white,
            surfaceContainerHighest: const Color(0xFFE2E8F0),
            surfaceContainerLow: const Color(0xFFF1F5F9),
          );

    if (isWhiteAccent) {
      colorScheme = isDark
          ? colorScheme.copyWith(
              primary: Colors.white,
              onPrimary: Colors.black,
              primaryContainer: Colors.white.withAlpha(30),
              onPrimaryContainer: Colors.white,
              secondary: const Color(0xFFE2E8F0),
              onSecondary: Colors.black,
              secondaryContainer: const Color(0xFF334155),
              onSecondaryContainer: Colors.white,
            )
          : colorScheme.copyWith(
              primary: Colors.black,
              onPrimary: Colors.white,
              primaryContainer: Colors.black.withAlpha(20),
              onPrimaryContainer: Colors.black,
              secondary: const Color(0xFF334155),
              onSecondary: Colors.white,
              secondaryContainer: const Color(0xFFE2E8F0),
              onSecondaryContainer: Colors.black,
            );
    }

    final scaffoldBackgroundColor = isDark 
        ? (backgroundStyle == AppBackgroundStyle.auroraGradient 
            ? Colors.transparent 
            : (backgroundStyle == AppBackgroundStyle.pureBlack 
                ? Colors.black 
                : (backgroundStyle == AppBackgroundStyle.deepCharcoal 
                    ? const Color(0xFF16161A) 
                    : CovaryDesignSystem.level0Background)))
        : const Color(0xFFF8FAFC);

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      
      // App Bars
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        iconTheme: IconThemeData(color: colorScheme.onSurface),
        titleTextStyle: textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: colorScheme.onSurface,
        ),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusLg),
          side: isDark
              ? const BorderSide(color: CovaryDesignSystem.innerBorderColor, width: 1)
              : BorderSide.none,
        ),
      ),
      
      // Buttons
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
          ),
          minimumSize: const Size(64, CovaryDesignSystem.minTouchTarget),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
          ),
          minimumSize: const Size(64, CovaryDesignSystem.minTouchTarget),
        ),
      ),
      
      // Inputs
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? colorScheme.surfaceContainerLow : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
          borderSide: BorderSide(color: colorScheme.outline.withValues(alpha: 0.5)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        labelStyle: textTheme.labelSmall,
      ),

      // Navigation Bar
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
      
      // Dialogs / Modals
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusXl),
          side: isDark
              ? const BorderSide(color: CovaryDesignSystem.innerBorderColor, width: 1)
              : BorderSide.none,
        ),
      ),
    );
  }
}
