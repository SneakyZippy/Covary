// Enums for the Universal Event schema.
//
// These enums are stored as text in the Drift database using `textEnum<T>()`.
// They define the taxonomy for categorizing every data point in the app,
// which is critical for clean post-processing in Python/Pandas.

/// The high-level category of an event.
///
/// Used to partition data into research domains for analysis.
enum EventCategory {
  /// Subjective well-being: mood ratings, energy, fatigue.
  mood,

  /// Tracked behaviors: meditations, sport, habits.
  behavior,

  /// Objective health data: steps, sleep, heart rate.
  health,

  /// Nutrition and intake: water, coffee, food.
  nutrition,

  /// Social interactions and relationships.
  social,

  /// Work, focus, and mental performance.
  productivity,

  /// Screen time and per-app usage statistics.
  appUsage,

  /// Biological data: menstrual cycle, flow, libido, cramps.
  biological,

  /// Environmental data: weather, temperature, wind.
  weather,

  /// System-level events: first launch, nickname changes, exports.
  meta,
}

/// How the event was initiated.
///
/// This is a key HCI metric — it tells us whether the user was
/// self-motivated (Manual) or system-prompted (Notification/System).
enum TriggerSource {
  /// User opened the app and logged data voluntarily.
  manual,

  /// User responded to a push notification prompt.
  notification,

  /// Data was collected automatically in the background (e.g., step count).
  system,
}

/// How the user interacted with the prompt.
///
/// Combined with `latencyMs`, this forms the core HCI dataset for the
/// thesis — measuring user engagement vs. resistance to prompts.
enum InteractionType {
  /// User tapped the notification or pressed the save button.
  click,

  /// User dismissed/swiped away the notification without opening it.
  swipeAway,

  /// User chose to be reminded later (via "Remind me at/in").
  snooze,
}

/// The input type for a tracked metric.
///
/// Determines which widget is rendered in the [MetricInputCard]
/// and what values are valid in the `value` field of an [Event].
enum MetricInputType {
  /// Binary toggle: stores "true" or "false".
  yesNo,

  /// 5-point Likert scale: stores "1" through "5".
  /// Used for Mood, Energy, Stress, Fatigue, Sleep Quality.
  scale1to5,

  /// 10-point scale: stores "1" through "10".
  /// Used for Wellbeing (per research methodology).
  scale1to10,

  /// Simple tap counter: each tap logs a new event with value "1".
  /// The UI shows today's running total. Used for frequency tracking
  /// like "Go to the toilet", "Drank a glass of water", etc.
  counter,

  /// Numeric entry: lets the user type a number (e.g. step counts, calorie intakes).
  numeric,
}

enum MetricFrequency {
  /// Show anytime the app is opened.
  anytime,

  /// Show only in the morning (e.g. 5:00 - 11:59).
  morning,

  /// Show only in the afternoon (e.g. 12:00 - 16:59).
  afternoon,

  /// Show only in the evening (e.g. 17:00 - 04:59).
  evening,
}

extension MetricFrequencyX on MetricFrequency {
  /// Checks if the metric should be tracked at the given timestamp.
  bool isApplicable(DateTime timestamp) {
    if (this == MetricFrequency.anytime) return true;
    final hour = timestamp.hour;
    if (this == MetricFrequency.morning && hour >= 5 && hour < 12) return true;
    if (this == MetricFrequency.afternoon && hour >= 12 && hour < 17) {
      return true;
    }
    if (this == MetricFrequency.evening && (hour >= 17 || hour < 5)) return true;
    return false;
  }
}

extension MetricInputTypeX on MetricInputType {
  /// Human-readable label used across the UI (e.g. filter chips, list tiles).
  String get displayLabel {
    switch (this) {
      case MetricInputType.yesNo:
        return 'Yes / No';
      case MetricInputType.scale1to5:
        return 'Scale 1–5';
      case MetricInputType.scale1to10:
        return 'Scale 1–10';
      case MetricInputType.counter:
        return 'Counter (Tap)';
      case MetricInputType.numeric:
        return 'Numeric (Number)';
    }
  }
}

/// Presets for bulk-enabling metrics based on research goals.
enum ResearchPreset {
  /// Mood, Energy, Sleep, Wellbeing.
  essential,
  /// Everything related to circadian anchors and subjective state.
  fullCircadian,
  /// Focus, Bachelor work, and Screen habits.
  productivity,
  /// Physical activity, Nutrition, and Symptoms.
  healthHabits,
  /// Everything enabled.
  allInclusive,
}
