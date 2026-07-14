import 'models/enums.dart';

/// A selectable entry for passively (system) collected data in the export
/// metric picker. Unlike [MetricPresets.metricTemplates], these don't map to
/// a single fixed event label — some are exact matches, others cover a
/// family of dynamically-generated labels (e.g. one per installed app),
/// signalled by [matchKey] ending in ':'.
class PassiveMetricOption {
  /// Human-readable name shown in the export picker.
  final String label;

  /// The raw [Event.label] to match, or (if it ends in ':') a prefix that
  /// matches all dynamically-generated labels sharing that prefix.
  final String matchKey;

  final EventCategory category;
  final String? emoji;

  const PassiveMetricOption({
    required this.label,
    required this.matchKey,
    required this.category,
    this.emoji,
  });

  bool get isPrefixMatch => matchKey.endsWith(':');
}

/// Static catalog of passively-sensed data exposed by [PassiveSensingService]
/// and [WeatherSensingService], surfaced as selectable entries in the export
/// metric picker so they aren't silently dropped from exports.
class PassiveMetricPresets {
  static const List<PassiveMetricOption> options = [
    // --- Sleep (from PassiveSensingService._syncHealth) ---
    PassiveMetricOption(
      label: 'Sleep Duration (Auto-tracked)',
      matchKey: 'sleep_duration_hours',
      category: EventCategory.health,
      emoji: 'bedtime',
    ),
    PassiveMetricOption(
      label: 'Bedtime (Auto-tracked)',
      matchKey: 'sleep_bedtime',
      category: EventCategory.health,
      emoji: 'bedtime',
    ),
    PassiveMetricOption(
      label: 'Wake-up Time (Auto-tracked)',
      matchKey: 'sleep_wakeup',
      category: EventCategory.health,
      emoji: 'bedtime',
    ),
    PassiveMetricOption(
      label: 'Sleep Midpoint (Auto-tracked)',
      matchKey: 'sleep_midpoint',
      category: EventCategory.health,
      emoji: 'bedtime',
    ),

    // --- Steps (from PassiveSensingService._syncHealth) ---
    PassiveMetricOption(
      label: 'Step Count (Auto-tracked)',
      matchKey: 'step_count',
      category: EventCategory.health,
      emoji: 'run',
    ),
    PassiveMetricOption(
      label: 'Step Count Segments (Auto-tracked)',
      matchKey: 'step_segment',
      category: EventCategory.health,
      emoji: 'run',
    ),

    // --- Screen time & app usage (from PassiveSensingService._syncAppUsage) ---
    PassiveMetricOption(
      label: 'Total Screen Time (Auto-tracked)',
      matchKey: 'total_screen_time',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),
    PassiveMetricOption(
      label: 'App Usage Segments (Auto-tracked)',
      matchKey: 'app_usage_segment',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),
    PassiveMetricOption(
      label: 'Per-App Screen Time (Auto-tracked)',
      matchKey: 'app_time:',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),
    PassiveMetricOption(
      label: 'Per-App Screen Time Segments (Auto-tracked)',
      matchKey: 'app_segment:',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),
    PassiveMetricOption(
      label: 'App Category Usage (Auto-tracked)',
      matchKey: 'category_time:',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),
    PassiveMetricOption(
      label: 'App Category Usage Segments (Auto-tracked)',
      matchKey: 'category_segment:',
      category: EventCategory.appUsage,
      emoji: 'phonelink_erase',
    ),

    // --- Weather (from WeatherSensingService) ---
    PassiveMetricOption(
      label: 'Weather Location (Auto-tracked)',
      matchKey: 'core_weather_location',
      category: EventCategory.weather,
      emoji: 'wb_sunny',
    ),
    PassiveMetricOption(
      label: 'Rain Intensity (Auto-tracked)',
      matchKey: 'core_weather_rain',
      category: EventCategory.weather,
      emoji: 'umbrella',
    ),
    PassiveMetricOption(
      label: 'Sun Intensity (Auto-tracked)',
      matchKey: 'core_weather_sun',
      category: EventCategory.weather,
      emoji: 'sunny',
    ),
    PassiveMetricOption(
      label: 'Wind Strength (Auto-tracked)',
      matchKey: 'core_weather_wind',
      category: EventCategory.weather,
      emoji: 'air',
    ),
  ];
}
