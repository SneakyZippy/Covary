import 'models/enums.dart';
import 'models/metric_definition.dart';

/// Static presets for metrics and tracking windows used for seeding the database.
///
/// Moving these here makes it easier to manage the research data without
/// cluttering the service logic.
class MetricPresets {
  /// The collection of all metric templates available for research.
  static const List<MetricDefinition> metricTemplates = [
    // --- Mood & State ---
    MetricDefinition(
      id: 'core_mood',
      label: 'Current Mood',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'sentiment_satisfied',
    ),
    MetricDefinition(
      id: 'core_energy',
      label: 'Energy Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'bolt',
    ),
    MetricDefinition(
      id: 'core_stress',
      label: 'Stress Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'psychology',
    ),

    // --- Period & Biological (New) ---
    MetricDefinition(
      id: 'core_period_flow',
      label: 'Period Flow',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      emoji: 'water_drop',
    ),
    MetricDefinition(
      id: 'core_period_desire',
      label: 'Sexual Desire',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'favorite',
    ),
    MetricDefinition(
      id: 'core_period_cramps',
      label: 'Period Cramps',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'personal_injury',
    ),

    // --- Health & Symptoms ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'bedtime',
    ),
    MetricDefinition(
      id: 'core_sick',
      label: 'Sickness Severity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'sick',
    ),
    MetricDefinition(
      id: 'core_digestion',
      label: 'Digestion Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      emoji: 'restaurant',
    ),
    MetricDefinition(
      id: 'core_headache',
      label: 'Headache Intensity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'psychology',
    ),
    MetricDefinition(
      id: 'core_toilet_urge',
      label: 'Urge to pee',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: false,
      emoji: 'wc',
    ),

    // --- Weather (New) ---
    MetricDefinition(
      id: 'core_weather_rain',
      label: 'Is it Raining?',
      category: EventCategory.weather,
      inputType: MetricInputType.yesNo,
      isEnabled: false,
      emoji: 'umbrella',
    ),
    MetricDefinition(
      id: 'core_weather_sun',
      label: 'Is it Sunny?',
      category: EventCategory.weather,
      inputType: MetricInputType.yesNo,
      isEnabled: false,
      emoji: 'sunny',
    ),
    MetricDefinition(
      id: 'core_weather_wind',
      label: 'Wind Strength',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      emoji: 'air',
    ),

    // --- Behavior & Wellbeing ---
    MetricDefinition(
      id: 'core_wellbeing',
      label: 'General Wellbeing',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'star',
    ),
    MetricDefinition(
      id: 'core_sport',
      label: 'Physical Activity',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'run',
    ),
    MetricDefinition(
      id: 'core_meditation',
      label: 'Mindfulness / Meditation',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'meditation',
    ),
    MetricDefinition(
      id: 'core_journaling',
      label: 'Journaling',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'edit',
    ),
    MetricDefinition(
      id: 'core_outside',
      label: 'Was I outside?',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: false,
      emoji: 'forest',
    ),
    MetricDefinition(
      id: 'core_good_deed',
      label: 'Good Deed',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'favorite',
    ),

    // --- Nutrition & Intake ---
    MetricDefinition(
      id: 'core_water_intake',
      label: 'Water Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: false,
      emoji: 'water_drop',
    ),
    MetricDefinition(
      id: 'core_coffee_intake',
      label: 'Coffee Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'coffee',
      windowIds: ['homescreen'],
    ),

    // --- Optional/Secondary ---
    MetricDefinition(
      id: 'core_focus',
      label: 'Focus',
      category: EventCategory.productivity,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'lightbulb',
    ),
    MetricDefinition(
      id: 'core_anxiety',
      label: 'Anxiety',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'psychology',
    ),
  ];

  /// Standard tracking windows to seed on first launch.
  static const List<WindowPreset> windowPresets = [
    WindowPreset(
      label: 'Early Morning',
      startHour: 7,
      startMinute: 0,
      endHour: 9,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      label: 'Late Morning',
      startHour: 10,
      startMinute: 0,
      endHour: 12,
      endMinute: 0,
      isEnabled: false,
    ),
    WindowPreset(
      label: 'Afternoon Sync',
      startHour: 14,
      startMinute: 0,
      endHour: 16,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      label: 'Evening Review',
      startHour: 19,
      startMinute: 0,
      endHour: 21,
      endMinute: 0,
      isEnabled: false,
    ),
    WindowPreset(
      label: 'Night/Bedtime',
      startHour: 22,
      startMinute: 0,
      endHour: 0,
      endMinute: 0,
      isEnabled: true,
    ),
  ];
}

/// Simple model for window seeding data.
class WindowPreset {
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isEnabled;
  final int? notificationHour;
  final int? notificationMinute;

  const WindowPreset({
    required this.label,
    required this.startHour,
    required this.startMinute,
    required this.endHour,
    required this.endMinute,
    this.isEnabled = true,
    this.notificationHour,
    this.notificationMinute,
  });
}
