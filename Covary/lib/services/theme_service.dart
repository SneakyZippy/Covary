import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../ui/theme/design_system.dart';

enum AppAccentColor {
  aquamarine,
  deepViolet,
  gold,
  azure,
  emerald,
  coral,
  ruby,
}

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _accentColorKey = 'accent_color';

  ThemeMode _themeMode = ThemeMode.system;
  AppAccentColor _accentColor = AppAccentColor.aquamarine;

  ThemeMode get themeMode => _themeMode;
  AppAccentColor get accentColor => _accentColor;

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

  /// Helper to get the actual Color based on the selected accent enum.
  Color get primaryColor {
    switch (_accentColor) {
      case AppAccentColor.aquamarine:
        return CovaryDesignSystem.primary;
      case AppAccentColor.deepViolet:
        return CovaryDesignSystem.secondaryContainer; // Deep Violet
      case AppAccentColor.gold:
        return CovaryDesignSystem.tertiary;
      case AppAccentColor.azure:
        return CovaryDesignSystem.azure;
      case AppAccentColor.emerald:
        return CovaryDesignSystem.emerald;
      case AppAccentColor.coral:
        return CovaryDesignSystem.coral;
      case AppAccentColor.ruby:
        return CovaryDesignSystem.ruby;
    }
  }
}
