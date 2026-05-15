import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

/// Tri-state permission result for App Usage Stats.
enum AppUsagePermissionStatus { granted, denied, restricted }

const _kSettingsOpenedKey = 'app_usage_settings_opened';

/// SharedPreferences keys for persisted app category sets.
const _kSocialAppsKey = 'social_app_packages';
const _kEntertainmentAppsKey = 'entertainment_app_packages';
const _kCategoriesSeeded = 'app_categories_seeded';
const _kDynamicCategoriesKey = 'app_usage_dynamic_categories';

/// Wraps the Android `UsageStats` API to query per-app foreground time.
class AppUsageService extends ChangeNotifier {
  /// Dynamic map of category names to sets of package names.
  Map<String, Set<String>> _categories = {};

  /// Whether the default seed has already been applied.
  bool _seeded = false;

  /// Public read-only access to the current categories.
  Map<String, Set<String>> get categories => Map.unmodifiable(_categories);

  /// Helper for legacy compatibility (Social).
  Set<String> get socialPackages => _categories['social'] ?? {};

  /// Helper for legacy compatibility (Entertainment).
  Set<String> get entertainmentPackages => _categories['entertainment'] ?? {};

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads persisted category sets from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 1. Check for dynamic categories first
    final dynamicJson = prefs.getString(_kDynamicCategoriesKey);
    if (dynamicJson != null) {
      try {
        final Map<String, dynamic> decoded = jsonDecode(dynamicJson);
        _categories = decoded.map((key, value) => MapEntry(key, (value as List).cast<String>().toSet()));
        debugPrint('[AppUsageService] Loaded ${_categories.length} dynamic categories.');
      } catch (e) {
        debugPrint('[AppUsageService] Error decoding dynamic categories: $e');
      }
    }

    // 2. Migration from legacy v2 (social/entertainment lists)
    if (_categories.isEmpty) {
      final social = prefs.getStringList(_kSocialAppsKey) ?? [];
      final entertainment = prefs.getStringList(_kEntertainmentAppsKey) ?? [];
      
      if (social.isNotEmpty || entertainment.isNotEmpty) {
        _categories['social'] = social.toSet();
        _categories['entertainment'] = entertainment.toSet();
        await _persistCurrent();
        debugPrint('[AppUsageService] Migrated legacy social/entertainment to dynamic categories.');
      }
    }

    // 3. Seeding (if brand new install)
    _seeded = prefs.getBool(_kCategoriesSeeded) ?? false;
    if (!_seeded && _categories.isEmpty) {
      // Default empty categories
      _categories['social'] = {};
      _categories['entertainment'] = {};
      await _persistCurrent();
      await prefs.setBool(_kCategoriesSeeded, true);
      _seeded = true;
      debugPrint('[AppUsageService] Initialized with default empty categories.');
    }
    
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Category Management
  // ---------------------------------------------------------------------------

  /// Adds a new empty category.
  Future<void> addCategory(String name) async {
    final normalized = name.trim().toLowerCase();
    if (normalized.isEmpty || _categories.containsKey(normalized)) return;
    
    _categories[normalized] = {};
    await _persistCurrent();
    notifyListeners();
  }

  /// Deletes a category.
  Future<void> deleteCategory(String name) async {
    if (!_categories.containsKey(name)) return;
    
    _categories.remove(name);
    await _persistCurrent();
    notifyListeners();
  }

  /// Renames a category.
  Future<void> renameCategory(String oldName, String newName) async {
    final normalizedNew = newName.trim().toLowerCase();
    if (normalizedNew.isEmpty || !_categories.containsKey(oldName) || _categories.containsKey(normalizedNew)) return;
    
    final apps = _categories.remove(oldName)!;
    _categories[normalizedNew] = apps;
    await _persistCurrent();
    notifyListeners();
  }

  /// Toggles whether [packageName] is in [categoryName].
  Future<void> toggleAppInCategory(String packageName, String categoryName, bool isActive) async {
    if (!_categories.containsKey(categoryName)) return;
    
    if (isActive) {
      _categories[categoryName]!.add(packageName);
    } else {
      _categories[categoryName]!.remove(packageName);
    }
    await _persistCurrent();
    notifyListeners();
  }

  /// Legacy helper for Social.
  Future<void> toggleSocialApp(String packageName, bool isSocial) => toggleAppInCategory(packageName, 'social', isSocial);

  /// Legacy helper for Entertainment.
  Future<void> toggleEntertainmentApp(String packageName, bool isEnt) => toggleAppInCategory(packageName, 'entertainment', isEnt);

  /// Checks if a package is in a specific category.
  bool isAppInCategory(String packageName, String categoryName) =>
      _categories[categoryName]?.contains(packageName) ?? false;

  /// Checks if a package is classified as Social.
  bool isSocialApp(String packageName) => isAppInCategory(packageName, 'social');

  /// Checks if a package is classified as Entertainment.
  bool isEntertainmentApp(String packageName) => isAppInCategory(packageName, 'entertainment');

  /// Checks if a package is in the curated suggestion list for Social.
  static bool isSuggestedSocial(String packageName) =>
      suggestedSocialPackages.contains(packageName);

  /// Checks if a package is in the curated suggestion list for Entertainment.
  static bool isSuggestedEntertainment(String packageName) =>
      suggestedEntertainmentPackages.contains(packageName);

  // ---------------------------------------------------------------------------
  // Permission Check
  // ---------------------------------------------------------------------------

  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      debugPrint('[AppUsageService] isPermissionGranted error: $e');
      return false;
    }
  }

  Future<AppUsagePermissionStatus> checkPermissionStatus() async {
    if (!Platform.isAndroid) return AppUsagePermissionStatus.denied;

    final granted = await isPermissionGranted();
    if (granted) {
      await resetRestrictedFlag();
      return AppUsagePermissionStatus.granted;
    }

    final prefs = await SharedPreferences.getInstance();
    final settingsOpened = prefs.getBool(_kSettingsOpenedKey) ?? false;

    if (settingsOpened) {
      return AppUsagePermissionStatus.restricted;
    }

    return AppUsagePermissionStatus.denied;
  }

  Future<void> openPermissionSettings() async {
    if (!Platform.isAndroid) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kSettingsOpenedKey, true);
      await UsageStats.grantUsagePermission();
    } on PlatformException catch (e) {
      debugPrint('[AppUsageService] openPermissionSettings error: $e');
    }
  }

  Future<void> resetRestrictedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSettingsOpenedKey);
  }

  // ---------------------------------------------------------------------------
  // Data Fetching
  // ---------------------------------------------------------------------------

  /// Returns total foreground time in minutes across all apps in the interval.
  Future<int?> fetchTotalScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      int totalMs = 0;
      for (final stat in stats) {
        totalMs += int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
      }

      return totalMs ~/ 60000;
    } catch (e) {
      debugPrint('[AppUsageService] fetchTotalScreenTimeMinutes error: $e');
      return null;
    }
  }

  /// Returns total foreground time in minutes for a specific category.
  Future<int?> fetchCategoryUsage(String categoryName, {DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    final apps = _categories[categoryName];
    if (apps == null || apps.isEmpty) return 0;

    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      int totalMs = 0;
      for (final stat in stats) {
        if (apps.contains(stat.packageName ?? '')) {
          totalMs += int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        }
      }

      return totalMs ~/ 60000;
    } catch (e) {
      debugPrint('[AppUsageService] fetchCategoryUsage($categoryName) error: $e');
      return null;
    }
  }

  /// Legacy helpers.
  Future<int?> fetchSocialScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) => fetchCategoryUsage('social', startTime: startTime, endTime: endTime);
  Future<int?> fetchEntertainmentScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) => fetchCategoryUsage('entertainment', startTime: startTime, endTime: endTime);

  /// Returns per-app foreground time in minutes for all apps with >0 usage.
  Future<Map<String, int>?> fetchPerAppScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      final Map<String, int> msResult = {};
      for (final stat in stats) {
        final pkg = stat.packageName ?? '';
        if (pkg.isEmpty) continue;
        final ms = int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        if (ms > 0) {
          msResult[pkg] = (msResult[pkg] ?? 0) + ms;
        }
      }

      final result = <String, int>{};
      for (final entry in msResult.entries) {
        final mins = entry.value ~/ 60000;
        if (mins > 0) {
          result[entry.key] = mins;
        }
      }
      return result;
    } catch (e) {
      debugPrint('[AppUsageService] fetchPerAppScreenTimeMinutes error: $e');
      return null;
    }
  }

  /// Returns hourly usage breakdown for a specific day.
  /// Result map: {hourIndex (0-23): foregroundMinutes}
  Future<Map<int, int>?> fetchHourlyUsage(DateTime date) async {
    if (!Platform.isAndroid) return null;
    
    final dayStart = DateTime(date.year, date.month, date.day, 0, 0, 0);
    final dayEnd = DateTime(date.year, date.month, date.day, 23, 59, 59);

    try {
      final events = await UsageStats.queryEvents(dayStart, dayEnd);
      final hourlyMs = Map<int, int>.fromIterable(List.generate(24, (i) => i), value: (_) => 0);
      
      final Map<String, int?> lastMoveToForeground = {};

      for (final event in events) {
        final pkg = event.packageName ?? '';
        final timeMs = int.tryParse(event.timeStamp ?? '0') ?? 0;
        final type = event.eventType;

        if (type == '1') { // MOVE_TO_FOREGROUND
          lastMoveToForeground[pkg] = timeMs;
        } else if (type == '2') { // MOVE_TO_BACKGROUND
          final startTime = lastMoveToForeground[pkg];
          if (startTime != null) {
            final duration = timeMs - startTime;
            if (duration > 0) {
              final startDt = DateTime.fromMillisecondsSinceEpoch(startTime);
              hourlyMs[startDt.hour] = (hourlyMs[startDt.hour] ?? 0) + duration;
            }
            lastMoveToForeground[pkg] = null;
          }
        }
      }

      // Convert MS to Minutes
      return hourlyMs.map((hour, ms) => MapEntry(hour, ms ~/ 60000));
    } catch (e) {
      debugPrint('[AppUsageService] fetchHourlyUsage error: $e');
      return null;
    }
  }

  /// Returns a nested map of usage per hour per app for the given interval.
  /// Result map: {hourIndex (0-23): {packageName: foregroundMinutes}}
  Future<Map<int, Map<String, int>>?> fetchHourlyAppUsage({required DateTime startTime, required DateTime endTime}) async {
    if (!Platform.isAndroid) return null;
    
    try {
      final events = await UsageStats.queryEvents(startTime, endTime);
      final Map<int, Map<String, int>> result = {};
      final Map<String, int?> lastMoveToForeground = {};

      for (final event in events) {
        final pkg = event.packageName ?? '';
        final timeMs = int.tryParse(event.timeStamp ?? '0') ?? 0;
        final type = event.eventType;

        if (type == '1') { // MOVE_TO_FOREGROUND
          lastMoveToForeground[pkg] = timeMs;
        } else if (type == '2') { // MOVE_TO_BACKGROUND
          final startMs = lastMoveToForeground[pkg];
          if (startMs != null) {
            _addDurationToResult(result, pkg, startMs, timeMs);
            lastMoveToForeground[pkg] = null;
          }
        }
      }

      // Convert MS to Minutes
      return result.map((hour, appMap) => MapEntry(
        hour, 
        appMap.map((pkg, ms) => MapEntry(pkg, ms ~/ 60000))
      ));
    } catch (e) {
      debugPrint('[AppUsageService] fetchHourlyAppUsage error: $e');
      return null;
    }
  }

  void _addDurationToResult(Map<int, Map<String, int>> result, String pkg, int startMs, int endMs) {
    var currentMs = startMs;
    while (currentMs < endMs) {
      final currentDt = DateTime.fromMillisecondsSinceEpoch(currentMs);
      final nextHourDt = DateTime(currentDt.year, currentDt.month, currentDt.day, currentDt.hour + 1);
      final nextHourMs = nextHourDt.millisecondsSinceEpoch;
      
      final chunkEnd = (endMs < nextHourMs) ? endMs : nextHourMs;
      final chunkDuration = chunkEnd - currentMs;
      
      final hour = currentDt.hour;
      result.putIfAbsent(hour, () => {});
      result[hour]![pkg] = (result[hour]![pkg] ?? 0) + chunkDuration;
      
      currentMs = chunkEnd;
    }
  }

  Future<Set<String>?> fetchInstalledPackages() async {
    if (!Platform.isAndroid) return null;
    try {
      final now = DateTime.now();
      final since = now.subtract(const Duration(days: 30));
      final stats = await UsageStats.queryUsageStats(since, now);
      return stats.map((s) => s.packageName ?? '').where((p) => p.isNotEmpty).toSet();
    } catch (e) {
      debugPrint('[AppUsageService] fetchInstalledPackages error: $e');
      return null;
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  Future<List<UsageInfo>?> _queryStats({DateTime? startTime, DateTime? endTime}) async {
    final hasPermission = await isPermissionGranted();
    if (!hasPermission) return null;

    final now = DateTime.now();
    final effectiveEnd = endTime ?? now;
    final effectiveStart = startTime ?? now.subtract(const Duration(hours: 24));

    try {
      return await UsageStats.queryUsageStats(effectiveStart, effectiveEnd);
    } catch (e) {
      debugPrint('[AppUsageService] queryUsageStats error: $e');
      return null;
    }
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_categories.map((key, value) => MapEntry(key, value.toList())));
    await prefs.setString(_kDynamicCategoriesKey, json);
  }

  static String readableName(String packageName) {
    final alias = _knownAliases[packageName];
    if (alias != null) return alias;
    final parts = packageName.split('.');
    final meaningful = parts.where((p) => !['com','org','net','android','app','mobile','client','google','apps'].contains(p) && p.length > 2);
    if (meaningful.isEmpty) return parts.last[0].toUpperCase() + parts.last.substring(1);
    final name = meaningful.last;
    return name[0].toUpperCase() + name.substring(1);
  }

  static const Map<String, String> _knownAliases = {
    'com.zhiliaoapp.musically': 'TikTok',
    'com.facebook.katana': 'Facebook',
    'com.facebook.orca': 'Messenger',
    'com.twitter.android': 'X (Twitter)',
    'com.reddit.frontpage': 'Reddit',
    'com.amazon.avod.thirdpartyclient': 'Prime Video',
    'com.hbo.hbonow': 'HBO Max',
    'com.apple.tv': 'Apple TV+',
    'tv.twitch.android.app': 'Twitch',
    'com.google.android.youtube': 'YouTube',
    'com.netflix.mediaclient': 'Netflix',
    'com.spotify.music': 'Spotify',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
    'com.whatsapp': 'WhatsApp',
    'com.discord': 'Discord',
    'org.telegram.messenger': 'Telegram',
    'com.disney.disneyplus': 'Disney+',
  };

  static const Set<String> suggestedSocialPackages = {
    'com.instagram.android', 'com.facebook.katana', 'com.twitter.android', 'com.zhiliaoapp.musically',
    'com.snapchat.android', 'com.reddit.frontpage', 'org.telegram.messenger', 'com.whatsapp', 'com.discord',
    'com.bereal.android', 'com.threads.app', 'com.linkedin.android', 'com.pinterest', 'com.tumblr',
  };

  static const Set<String> suggestedEntertainmentPackages = {
    'com.google.android.youtube', 'com.netflix.mediaclient', 'com.amazon.avod.thirdpartyclient',
    'com.disney.disneyplus', 'com.spotify.music', 'tv.twitch.android.app', 'com.hbo.hbonow',
    'com.apple.tv', 'com.plexapp.android', 'de.zdf.app.zdftivi', 'com.ard.mediathek',
  };
}
