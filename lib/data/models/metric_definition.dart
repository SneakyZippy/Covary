import 'enums.dart';

/// Represents a trackable research metric in the app.
///
/// This model is used by both the Settings screen (to show toggles)
/// and the Home screen (to render input cards). It unifies core
/// (built-in) metrics and user-created custom metrics under one type.
class MetricDefinition {
  /// Unique identifier.
  /// - Core metrics use a stable slug (e.g. "core_mood").
  /// - Custom metrics use a UUID v4.
  final String id;

  /// Display name shown on the input card and in settings.
  final String label;

  /// Which research domain this metric belongs to.
  final EventCategory category;

  /// Determines the input widget: toggle, 1–5 chips, or 1–10 slider.
  final MetricInputType inputType;

  /// IDs of custom tracking windows when this metric should be shown.
  /// If empty or contains "anytime", it's always shown.
  final List<String> windowIds;

  /// Optional emoji or icon hint for the UI.
  final String? emoji;

  /// Whether this metric is currently active (shown on the Home screen).
  final bool isEnabled;

  /// Whether logging this metric counts towards the Activity Heatmap and Streak.
  final bool isActivityIndicator;

  /// User-set override for retrospective recall reliability.
  /// - `null`  → auto-derived from [inputType].
  /// - `true`  → always treated as reliable (e.g. a scale the user knows is factual).
  /// - `false` → always treated as unreliable.
  final bool? retroReliableOverride;

  /// Optional description or instructions on how to measure/track the metric.
  final String? description;

  /// Whether this metric's value can be reliably recalled after the fact.
  ///
  /// Factual metrics (Yes/No, counter) are stable even hours later.
  /// Subjective scales (mood, stress) are temporally anchored and suffer
  /// from recall bias — logging them retroactively pollutes the research data.
  ///
  /// The user can override this default per-metric in the settings.
  bool get isRetrospectivelyReliable =>
      retroReliableOverride ??
      (inputType == MetricInputType.yesNo ||
          inputType == MetricInputType.counter);

  const MetricDefinition({
    required this.id,
    required this.label,
    required this.category,
    required this.inputType,
    required this.isEnabled,
    this.windowIds = const ['anytime'],
    this.emoji,
    this.isActivityIndicator = true,
    this.retroReliableOverride,
    this.description,
  });

  /// Creates a copy with the given fields replaced.
  ///
  /// Uses a sentinel pattern so [retroReliableOverride] can be explicitly
  /// set to null (clearing a user override) vs. simply not passed.
  MetricDefinition copyWith({
    String? id,
    String? label,
    EventCategory? category,
    MetricInputType? inputType,
    bool? isEnabled,
    List<String>? windowIds,
    String? emoji,
    bool? isActivityIndicator,
    Object? retroReliableOverride = _unset,
    String? description,
  }) {
    return MetricDefinition(
      id: id ?? this.id,
      label: label ?? this.label,
      category: category ?? this.category,
      inputType: inputType ?? this.inputType,
      isEnabled: isEnabled ?? this.isEnabled,
      windowIds: windowIds ?? this.windowIds,
      emoji: emoji ?? this.emoji,
      isActivityIndicator: isActivityIndicator ?? this.isActivityIndicator,
      retroReliableOverride: retroReliableOverride == _unset
          ? this.retroReliableOverride
          : retroReliableOverride as bool?,
      description: description ?? this.description,
    );
  }
}

/// Sentinel object to distinguish "not passed" from explicit null in
/// [MetricDefinition.copyWith], allowing callers to clear an override.
const _unset = Object();
