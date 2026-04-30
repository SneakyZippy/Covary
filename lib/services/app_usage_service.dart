import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:usage_stats/usage_stats.dart';

/// Tri-state permission result for App Usage Stats.
///
/// - [granted]    : `PACKAGE_USAGE_STATS` is active.
/// - [denied]     : Permission not yet granted; settings page not yet visited.
/// - [restricted] : User visited Usage Access settings but the toggle was
///                  grayed out ("Controlled by restricted setting").
///                  This happens on Android 13+ when the APK is sideloaded.
///                  Fix: Settings → Apps → Covary → ⋮ → Allow restricted settings.
enum AppUsagePermissionStatus { granted, denied, restricted }

const _kSettingsOpenedKey = 'app_usage_settings_opened';

/// SharedPreferences keys for persisted app category sets.
const _kSocialAppsKey = 'social_app_packages';
const _kEntertainmentAppsKey = 'entertainment_app_packages';
const _kCategoriesSeeded = 'app_categories_seeded';

/// Wraps the Android `UsageStats` API to query per-app foreground time.
///
/// [PACKAGE_USAGE_STATS] is a "protected" special permission — it cannot be
/// granted via a runtime dialog. The user must enable it manually at:
/// **Settings → Apps → Special app access → Usage access**
///
/// This service provides:
/// - [isPermissionGranted]: non-intrusive check of current permission state.
/// - [openPermissionSettings]: deep-link to the Usage Access settings page.
/// - [fetchTotalScreenTimeMinutes]: total foreground time for all apps (last 24h).
/// - [fetchSocialScreenTimeMinutes]: foreground time for user-configured Social apps.
/// - [fetchEntertainmentScreenTimeMinutes]: foreground time for user-configured Entertainment apps.
/// - [fetchPerAppScreenTimeMinutes]: per-app breakdown for granular research data.
///
/// ## Thesis Note
/// App usage is divided into three buckets for the research model:
/// 1. **Total screen time** — overall digital exposure.
/// 2. **Social media time** — correlated with mood and FOMO research signals.
/// 3. **Entertainment (video) time** — correlated with passive consumption vs. active metrics.
///
/// Categories are **user-configurable** and overlap is allowed (e.g., TikTok can
/// be both Social and Entertainment). This improves ecological validity since
/// the participant defines their own media boundaries.
///
/// iOS Note: Android-only. This service is a no-op on iOS.
class AppUsageService extends ChangeNotifier {
  /// User-configured social app package names.
  Set<String> _socialPackages = {};

  /// User-configured entertainment app package names.
  Set<String> _entertainmentPackages = {};

  /// Whether the default seed has already been applied.
  bool _seeded = false;

  /// Public read-only access to the current social package set.
  Set<String> get socialPackages => Set.unmodifiable(_socialPackages);

  /// Public read-only access to the current entertainment package set.
  Set<String> get entertainmentPackages => Set.unmodifiable(_entertainmentPackages);

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads persisted category sets from SharedPreferences.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _seeded = prefs.getBool(_kCategoriesSeeded) ?? false;

    // Migration: clear old auto-seeded defaults (v1 → v2).
    const migrationKey = 'app_categories_v2_migrated';
    final v2Migrated = prefs.getBool(migrationKey) ?? false;
    if (_seeded && !v2Migrated) {
      _socialPackages = {};
      _entertainmentPackages = {};
      await _persist(prefs);
      await prefs.setBool(migrationKey, true);
      debugPrint('[AppUsageService] Migrated to v2: cleared auto-seeded categories.');
      return;
    }

    if (!_seeded) {
      _socialPackages = {};
      _entertainmentPackages = {};
      await _persist(prefs);
      await prefs.setBool(_kCategoriesSeeded, true);
      await prefs.setBool(migrationKey, true);
      _seeded = true;
      debugPrint('[AppUsageService] Initialized with empty app categories.');
    } else {
      _socialPackages = (prefs.getStringList(_kSocialAppsKey) ?? []).toSet();
      _entertainmentPackages =
          (prefs.getStringList(_kEntertainmentAppsKey) ?? []).toSet();
      debugPrint(
        '[AppUsageService] Loaded ${_socialPackages.length} social, '
        '${_entertainmentPackages.length} entertainment apps.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Category Management
  // ---------------------------------------------------------------------------

  /// Toggles whether [packageName] is classified as a Social app.
  Future<void> toggleSocialApp(String packageName, bool isSocial) async {
    if (isSocial) {
      _socialPackages.add(packageName);
    } else {
      _socialPackages.remove(packageName);
    }
    await _persistCurrent();
    notifyListeners();
  }

  /// Toggles whether [packageName] is classified as an Entertainment app.
  Future<void> toggleEntertainmentApp(
    String packageName,
    bool isEntertainment,
  ) async {
    if (isEntertainment) {
      _entertainmentPackages.add(packageName);
    } else {
      _entertainmentPackages.remove(packageName);
    }
    await _persistCurrent();
    notifyListeners();
  }

  /// Checks if a package is classified as Social.
  bool isSocialApp(String packageName) =>
      _socialPackages.contains(packageName);

  /// Checks if a package is classified as Entertainment.
  bool isEntertainmentApp(String packageName) =>
      _entertainmentPackages.contains(packageName);

  /// Checks if a package is in the curated suggestion list for Social.
  static bool isSuggestedSocial(String packageName) =>
      suggestedSocialPackages.contains(packageName);

  /// Checks if a package is in the curated suggestion list for Entertainment.
  static bool isSuggestedEntertainment(String packageName) =>
      suggestedEntertainmentPackages.contains(packageName);

  // ---------------------------------------------------------------------------
  // Permission Check
  // ---------------------------------------------------------------------------

  /// Returns `true` if the [PACKAGE_USAGE_STATS] special permission is active.
  Future<bool> isPermissionGranted() async {
    if (!Platform.isAndroid) return false;
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (e) {
      debugPrint('[AppUsageService] isPermissionGranted error: $e');
      return false;
    }
  }

  /// Returns a tri-state [AppUsagePermissionStatus] distinguishing between
  /// granted, never-asked-denied, and Android 13+ restricted-setting-blocked.
  ///
  /// **Restricted detection logic:**
  /// Android has no public API to detect whether the toggle is grayed out.
  /// We infer it by checking whether [openPermissionSettings] was previously
  /// called (persisted flag) AND permission is still not granted after returning.
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
      debugPrint(
        '[AppUsageService] Permission still denied after settings visit → restricted.',
      );
      return AppUsagePermissionStatus.restricted;
    }

    return AppUsagePermissionStatus.denied;
  }

  /// Deep-links the user to the **Usage Access** settings page.
  ///
  /// Persists a flag so [checkPermissionStatus] can detect the
  /// restricted-setting state if the user returns without granting access.
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

  /// Clears the settings-visited flag (called automatically when permission
  /// is confirmed granted, so future denials are not misclassified as restricted).
  Future<void> resetRestrictedFlag() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSettingsOpenedKey);
  }


  // ---------------------------------------------------------------------------
  // Data Fetching
  // ---------------------------------------------------------------------------

  /// Returns total foreground time in minutes across all apps in the specified interval.
  Future<int?> fetchTotalScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      int totalMs = 0;
      for (final stat in stats) {
        totalMs += int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
      }

      final minutes = totalMs ~/ 1000 ~/ 60;
      debugPrint('[AppUsageService] Total screen time: ${minutes}min');
      return minutes;
    } catch (e) {
      debugPrint('[AppUsageService] fetchTotalScreenTimeMinutes error: $e');
      return null;
    }
  }

  /// Returns total foreground time in minutes for Social category apps in the interval.
  Future<int?> fetchSocialScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      int totalMs = 0;
      for (final stat in stats) {
        if (_socialPackages.contains(stat.packageName ?? '')) {
          totalMs += int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        }
      }

      final minutes = totalMs ~/ 1000 ~/ 60;
      debugPrint('[AppUsageService] Social screen time: ${minutes}min');
      return minutes;
    } catch (e) {
      debugPrint('[AppUsageService] fetchSocialScreenTimeMinutes error: $e');
      return null;
    }
  }

  /// Returns total foreground time in minutes for Entertainment apps in the interval.
  Future<int?> fetchEntertainmentScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      int totalMs = 0;
      for (final stat in stats) {
        if (_entertainmentPackages.contains(stat.packageName ?? '')) {
          totalMs += int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        }
      }

      final minutes = totalMs ~/ 1000 ~/ 60;
      debugPrint('[AppUsageService] Entertainment screen time: ${minutes}min');
      return minutes;
    } catch (e) {
      debugPrint(
        '[AppUsageService] fetchEntertainmentScreenTimeMinutes error: $e',
      );
      return null;
    }
  }

  /// Returns per-app foreground time in minutes for all apps with >0 usage in the interval.
  Future<Map<String, int>?> fetchPerAppScreenTimeMinutes({DateTime? startTime, DateTime? endTime}) async {
    if (!Platform.isAndroid) return null;
    try {
      final stats = await _queryStats(startTime: startTime, endTime: endTime);
      if (stats == null) return null;

      final msPerPkg = <String, int>{};
      for (final stat in stats) {
        final pkg = stat.packageName ?? '';
        if (pkg.isEmpty) continue;

        final ms = int.tryParse(stat.totalTimeInForeground ?? '0') ?? 0;
        if (ms > 0) {
          msPerPkg[pkg] = (msPerPkg[pkg] ?? 0) + ms;
        }
      }

      final result = <String, int>{};
      for (final entry in msPerPkg.entries) {
        final minutes = entry.value ~/ 60000;
        if (minutes > 0) {
          result[entry.key] = minutes;
        }
      }

      debugPrint(
        '[AppUsageService] Per-app data: ${result.length} apps with usage',
      );
      return result;
    } catch (e) {
      debugPrint('[AppUsageService] fetchPerAppScreenTimeMinutes error: $e');
      return null;
    }
  }

  /// Returns the set of all package names seen in usage stats over the last 30 days.
  Future<Set<String>?> fetchInstalledPackages() async {
    if (!Platform.isAndroid) return null;
    try {
      final hasPermission = await isPermissionGranted();
      if (!hasPermission) return null;

      final now = DateTime.now();
      final since = now.subtract(const Duration(days: 30));
      final stats = await UsageStats.queryUsageStats(since, now);

      final packages = <String>{};
      for (final stat in stats) {
        final pkg = stat.packageName ?? '';
        if (pkg.isNotEmpty) packages.add(pkg);
      }

      debugPrint(
        '[AppUsageService] Found ${packages.length} installed packages (30d)',
      );
      return packages;
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
    if (!hasPermission) {
      debugPrint('[AppUsageService] No usage permission — skipping query.');
      return null;
    }

    final now = DateTime.now();
    final effectiveEnd = endTime ?? now;
    final effectiveStart = startTime ?? now.subtract(const Duration(hours: 24));

    try {
      final stats = await UsageStats.queryUsageStats(effectiveStart, effectiveEnd);
      return stats;
    } catch (e) {
      debugPrint('[AppUsageService] queryUsageStats error: $e');
      return null;
    }
  }

  Future<void> _persistCurrent() async {
    final prefs = await SharedPreferences.getInstance();
    await _persist(prefs);
  }

  Future<void> _persist(SharedPreferences prefs) async {
    await prefs.setStringList(_kSocialAppsKey, _socialPackages.toList());
    await prefs.setStringList(
      _kEntertainmentAppsKey,
      _entertainmentPackages.toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Utility: Human-readable name from package name
  // ---------------------------------------------------------------------------

  static String readableName(String packageName) {
    final alias = _knownAliases[packageName];
    if (alias != null) return alias;

    final parts = packageName.split('.');
    final meaningfulParts = parts.where((p) =>
        p != 'com' &&
        p != 'org' &&
        p != 'net' &&
        p != 'android' &&
        p != 'app' &&
        p != 'mobile' &&
        p != 'client' &&
        p != 'google' &&
        p != 'apps' &&
        p.length > 2);

    if (meaningfulParts.isEmpty) {
      return parts.last[0].toUpperCase() + parts.last.substring(1);
    }

    final name = meaningfulParts.last;
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
    'com.google.android.apps.youtube.music': 'YouTube Music',
    'com.google.android.gm': 'Gmail',
    'com.google.android.apps.maps': 'Google Maps',
    'com.google.android.apps.photos': 'Google Photos',
    'com.google.android.apps.docs': 'Google Docs',
    'com.google.android.dialer': 'Phone',
    'com.google.android.apps.messaging': 'Messages',
    'com.netflix.mediaclient': 'Netflix',
    'com.spotify.music': 'Spotify',
    'com.deezer.android': 'Deezer',
    'com.soundcloud.android': 'SoundCloud',
    'com.plexapp.android': 'Plex',
    'com.bereal.android': 'BeReal',
    'com.threads.app': 'Threads',
    'com.instagram.android': 'Instagram',
    'com.snapchat.android': 'Snapchat',
    'com.whatsapp': 'WhatsApp',
    'com.discord': 'Discord',
    'org.telegram.messenger': 'Telegram',
    'com.linkedin.android': 'LinkedIn',
    'com.pinterest': 'Pinterest',
    'com.tumblr': 'Tumblr',
    'com.vkontakte.android': 'VKontakte',
    'com.disney.disneyplus': 'Disney+',
    'de.zdf.app.zdftivi': 'ZDF',
    'com.ard.mediathek': 'ARD Mediathek',
    'de.swr.swr2': 'SWR2',
  };

  static const Set<String> suggestedSocialPackages = {
    'com.instagram.android',
    'com.facebook.katana',
    'com.twitter.android',
    'com.zhiliaoapp.musically',
    'com.snapchat.android',
    'com.reddit.frontpage',
    'com.linkedin.android',
    'com.pinterest',
    'com.tumblr',
    'com.vkontakte.android',
    'org.telegram.messenger',
    'com.whatsapp',
    'com.discord',
    'com.bereal.android',
    'com.threads.app',
  };

  static const Set<String> suggestedEntertainmentPackages = {
    'com.google.android.youtube',
    'com.netflix.mediaclient',
    'com.amazon.avod.thirdpartyclient',
    'com.disney.disneyplus',
    'com.hbo.hbonow',
    'com.apple.tv',
    'com.spotify.music',
    'com.deezer.android',
    'com.soundcloud.android',
    'tv.twitch.android.app',
    'com.plexapp.android',
    'de.zdf.app.zdftivi',
    'com.ard.mediathek',
    'de.swr.swr2',
  };
}
