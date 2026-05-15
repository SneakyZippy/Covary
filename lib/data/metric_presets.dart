import 'models/enums.dart';
import 'models/metric_definition.dart';

/// Static presets for metrics and tracking windows used for seeding the database.
///
/// Moving these here makes it easier to manage the research data without
/// cluttering the service logic.
class MetricPresets {
  /// The collection of all metric templates available for research.
  static const List<MetricDefinition> metricTemplates = [
    // --- Internal State (Psychological & Subjective) ---
    MetricDefinition(
      id: 'core_mood',
      label: 'Current Mood',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'sentiment_satisfied',
    ),
    MetricDefinition(
      id: 'core_energy',
      label: 'Energy Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'bolt',
    ),
    MetricDefinition(
      id: 'core_stress',
      label: 'Stress Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'psychology',
    ),
    MetricDefinition(
      id: 'core_wellbeing',
      label: 'General Wellbeing',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'star',
    ),
    MetricDefinition(
      id: 'core_anxiety',
      label: 'Anxiety',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'psychology',
    ),

    // --- Circadian Anchors & Sleep ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['9fb76442-59ad-49cb-8d93-77904690e6ef'], // Morning window
      emoji: 'bedtime',
    ),
    MetricDefinition(
      id: 'core_nap_duration',
      label: 'Daytime Nap?',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'hotel',
    ),
    MetricDefinition(
      id: 'core_light_exposure',
      label: 'Recent Light Exposure',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'wb_sunny',
    ),
    MetricDefinition(
      id: 'core_meal_count',
      label: 'Logged a Meal',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'restaurant',
    ),

    // --- Health & Symptoms ---
    MetricDefinition(
      id: '3a4d43d5-7459-481e-bf3c-97e725fa3105',
      label: 'General Health Status',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'favorite',
    ),
    MetricDefinition(
      id: 'core_headache',
      label: 'Headache Intensity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'psychology',
    ),
    MetricDefinition(
      id: 'core_sick',
      label: 'Sickness Severity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'sick',
    ),
    MetricDefinition(
      id: 'core_digestion',
      label: 'Digestion Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'restaurant',
    ),
    MetricDefinition(
      id: 'core_toilet_urge',
      label: 'Bathroom Visit',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'wc',
      retroReliableOverride: false,
    ),

    // --- Performance & Productivity ---
    MetricDefinition(
      id: 'core_focus',
      label: 'Concentration/Focus',
      category: EventCategory.productivity,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'lightbulb',
    ),
    MetricDefinition(
      id: 'e4a45a3d-a994-4ec8-be8c-fdf0ad511910',
      label: 'Bachelor Work (30min)',
      category: EventCategory.behavior,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'book',
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: 'core_screen_mindless',
      label: 'Mindless Scrolling?',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'phonelink_erase',
    ),

    // --- Behavior & Habits ---
    MetricDefinition(
      id: 'core_sport',
      label: 'Physical Activity',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'],
      emoji: 'run',
    ),
    MetricDefinition(
      id: 'core_meditation',
      label: 'Mindfulness / Meditation',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'],
      emoji: 'meditation',
    ),
    MetricDefinition(
      id: 'core_journaling',
      label: 'Journaling',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'],
      emoji: 'edit',
    ),
    MetricDefinition(
      id: 'core_outside',
      label: 'Time spent Outside',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'],
      emoji: 'forest',
    ),

    // --- Social Interactions ---
    MetricDefinition(
      id: 'core_good_deed',
      label: 'Did a Good Deed',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'],
      emoji: 'favorite',
    ),
    MetricDefinition(
      id: 'c2f69108-3834-4b29-ba98-fae24d85124d',
      label: 'Unexpected Social Interaction',
      category: EventCategory.social,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: [],
      emoji: 'bolt',
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: '4d86d597-6772-4aa0-a4b8-ba9befce1d7a',
      label: 'Spent time with SO',
      category: EventCategory.social,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: [],
      emoji: 'favorite',
      retroReliableOverride: false,
    ),

    // --- Nutrition & Intake ---
    MetricDefinition(
      id: 'core_coffee_intake',
      label: 'Coffee Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'coffee',
    ),
    MetricDefinition(
      id: 'core_water_intake',
      label: 'Water Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'water_drop',
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: 'core_alcohol_intake',
      label: 'Alcoholic Drink',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'liquor',
    ),

    // --- Biological ---
    MetricDefinition(
      id: 'core_period_flow',
      label: 'Period Flow',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'water_drop',
    ),
    MetricDefinition(
      id: 'core_period_desire',
      label: 'Sexual Desire',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'favorite',
    ),
    MetricDefinition(
      id: 'core_period_cramps',
      label: 'Period Cramps',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'personal_injury',
    ),

    // --- Environment & Context ---
    MetricDefinition(
      id: 'core_weather_rain',
      label: 'Is it Raining?',
      category: EventCategory.weather,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'umbrella',
    ),
    MetricDefinition(
      id: 'core_weather_sun',
      label: 'Is it Sunny?',
      category: EventCategory.weather,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'sunny',
    ),
    MetricDefinition(
      id: 'core_weather_wind',
      label: 'Wind Strength',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'air',
    ),

    // --- Research Quality (HCI Thesis) ---
    MetricDefinition(
      id: 'core_prompt_burden',
      label: 'How annoying were the prompts?',
      category: EventCategory.meta,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba'], // Evening/Night only
      emoji: 'announcement',
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
