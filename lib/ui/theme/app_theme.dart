import 'package:flutter/material.dart';
import 'design_system.dart';

class AppTheme {
  static ThemeData buildTheme({
    required BuildContext context,
    required bool isDark,
    required Color primaryColor,
  }) {
    final textTheme = CovaryDesignSystem.getTextTheme(context);

    // Create a color scheme based on the selected primary color.
    // For dark mode, we inject the specific Midnight Navy backgrounds.
    final ColorScheme colorScheme = isDark
        ? ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.dark,
            surface: CovaryDesignSystem.surface,
            onSurface: CovaryDesignSystem.onSurface,
            error: CovaryDesignSystem.error,
          )
        : ColorScheme.fromSeed(
            seedColor: primaryColor,
            brightness: Brightness.light,
          );

    final scaffoldBackgroundColor = isDark 
        ? CovaryDesignSystem.level0Background 
        : colorScheme.surface;

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: scaffoldBackgroundColor,
      
      // Cards
      cardTheme: CardThemeData(
        color: isDark ? CovaryDesignSystem.level1Surface : colorScheme.surfaceContainerHighest,
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
        fillColor: isDark ? CovaryDesignSystem.level0Background : colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
        backgroundColor: isDark ? CovaryDesignSystem.level1Surface : colorScheme.surface,
        indicatorColor: colorScheme.primary.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.all(textTheme.labelSmall),
      ),
      
      // Dialogs / Modals
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? CovaryDesignSystem.level1Surface : colorScheme.surface,
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
