import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/theme/design_system.dart';

enum AppAccentColor {
  white,
  aquamarine,
  mint,
  emerald,
  azure,
  indigo,
  deepViolet,
  orchid,
  ruby,
  crimson,
  coral,
  gold,
}

enum AppBackgroundStyle {
  midnightNavy,
  pureBlack,
  deepCharcoal,
  auroraGradient,
}

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';
  static const String _backgroundStyleKey = 'background_style';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccentColor _accentColor = AppAccentColor.aquamarine;
  AppBackgroundStyle _backgroundStyle = AppBackgroundStyle.midnightNavy;

  ThemeMode get themeMode => _themeMode;
  AppAccentColor get accentColor => _accentColor;
  AppBackgroundStyle get backgroundStyle => _backgroundStyle;

  ThemeService();

  Future<void> init() async {
    await _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    final themeModeIndex = prefs.getInt(_themeModeKey);
    if (themeModeIndex != null && themeModeIndex >= 0 && themeModeIndex < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[themeModeIndex];
    }

    final accentIndex = prefs.getInt(_accentColorKey);
    if (accentIndex != null && accentIndex >= 0 && accentIndex < AppAccentColor.values.length) {
      _accentColor = AppAccentColor.values[accentIndex];
    }

    final bgIndex = prefs.getInt(_backgroundStyleKey);
    if (bgIndex != null && bgIndex >= 0 && bgIndex < AppBackgroundStyle.values.length) {
      _backgroundStyle = AppBackgroundStyle.values[bgIndex];
    }

    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, mode.index);
  }

  Future<void> setAccentColor(AppAccentColor color) async {
    if (_accentColor == color) return;
    _accentColor = color;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.index);
  }

  Future<void> setBackgroundStyle(AppBackgroundStyle style) async {
    if (_backgroundStyle == style) return;
    _backgroundStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_backgroundStyleKey, style.index);
  }

  /// Helper to get the actual Color based on the selected accent enum.
  Color get primaryColor {
    switch (_accentColor) {
      case AppAccentColor.white:
        return Colors.white;
      case AppAccentColor.aquamarine:
        return CovaryDesignSystem.primary;
      case AppAccentColor.mint:
        return const Color(0xFF4ADE80);
      case AppAccentColor.emerald:
        return CovaryDesignSystem.emerald;
      case AppAccentColor.azure:
        return CovaryDesignSystem.azure;
      case AppAccentColor.indigo:
        return const Color(0xFF6366F1);
      case AppAccentColor.deepViolet:
        return CovaryDesignSystem.secondaryContainer; // Deep Violet
      case AppAccentColor.orchid:
        return const Color(0xFFF472B6);
      case AppAccentColor.ruby:
        return CovaryDesignSystem.ruby;
      case AppAccentColor.crimson:
        return const Color(0xFFE11D48);
      case AppAccentColor.coral:
        return CovaryDesignSystem.coral;
      case AppAccentColor.gold:
        return CovaryDesignSystem.tertiary;
    }
  }
}
