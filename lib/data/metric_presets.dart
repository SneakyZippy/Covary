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
      isActivityIndicator: true,
    ),
    MetricDefinition(
      id: 'core_energy',
      label: 'Energy Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'bolt',
      isActivityIndicator: true,
    ),
    MetricDefinition(
      id: 'core_stress',
      label: 'Stress Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'psychology',
      isActivityIndicator: true,
    ),
    MetricDefinition(
      id: 'core_wellbeing',
      label: 'General Wellbeing',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'star',
      isActivityIndicator: true,
    ),
    MetricDefinition(
      id: 'core_anxiety',
      label: 'Anxiety',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'psychology',
      isActivityIndicator: false,
    ),

    // --- Circadian Anchors & Sleep ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      // Morning + Late Morning windows
      windowIds: ['9fb76442-59ad-49cb-8d93-77904690e6ef', 'e31d345d-e7f9-4c96-b8b5-f5e9e72a9d60'],
      emoji: 'bedtime',
      isActivityIndicator: true,
    ),
    MetricDefinition(
      id: 'core_nap_duration',
      label: 'Daytime Nap?',
      category: EventCategory.health,
      inputType: MetricInputType.yesNo,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'hotel',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_light_exposure',
      label: 'Recent Light Exposure',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'wb_sunny',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_meal_count',
      label: 'Logged a Meal',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'restaurant',
      isActivityIndicator: false,
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
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_headache',
      label: 'Headache Intensity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'psychology',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_sick',
      label: 'Sickness Severity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'sick',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_digestion',
      label: 'Digestion Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'restaurant',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_toilet_urge',
      label: 'Bathroom Visit',
      category: EventCategory.health,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'wc',
      isActivityIndicator: false,
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
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'e4a45a3d-a994-4ec8-be8c-fdf0ad511910',
      label: 'Bachelor Work (30min)',
      category: EventCategory.behavior,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'book',
      isActivityIndicator: false,
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
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),

    // --- Behavior & Habits ---
    MetricDefinition(
      id: 'core_sport',
      label: 'Physical Activity',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      // Afternoon + Evening windows
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba', 'ce3317fd-5fa3-41d9-a729-4e94539a8e23'],
      emoji: 'run',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_meditation',
      label: 'Mindfulness / Meditation',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba', 'ce3317fd-5fa3-41d9-a729-4e94539a8e23'],
      emoji: 'meditation',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_journaling',
      label: 'Journaling',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba', 'ce3317fd-5fa3-41d9-a729-4e94539a8e23'],
      emoji: 'edit',
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: 'core_outside',
      label: 'Time spent Outside',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba', 'ce3317fd-5fa3-41d9-a729-4e94539a8e23'],
      emoji: 'forest',
      isActivityIndicator: true,
    ),

    // --- Social Interactions ---
    MetricDefinition(
      id: 'core_good_deed',
      label: 'Did a Good Deed',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: [], // Quick Log Only
      emoji: 'favorite',
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: 'c2f69108-3834-4b29-ba98-fae24d85124d',
      label: 'Unexpected Social Interaction',
      category: EventCategory.social,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: [], // Quick Log Only
      emoji: 'bolt',
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: '4d86d597-6772-4aa0-a4b8-ba9befce1d7a',
      label: 'Spent time with SO',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['ce3317fd-5fa3-41d9-a729-4e94539a8e23'], // Evening only
      emoji: 'favorite',
      isActivityIndicator: false,
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
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),
    MetricDefinition(
      id: 'core_water_intake',
      label: 'Water Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'water_drop',
      isActivityIndicator: false,
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
      isActivityIndicator: false,
      retroReliableOverride: false,
    ),

    // --- Biological ---
    MetricDefinition(
      id: 'core_period_flow',
      label: 'Period Flow',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'water_drop',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_period_desire',
      label: 'Sexual Desire',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'favorite',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_period_cramps',
      label: 'Period Cramps',
      category: EventCategory.biological,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      windowIds: ['anytime'],
      emoji: 'personal_injury',
      isActivityIndicator: false,
    ),

    // --- Environment & Context ---
    MetricDefinition(
      id: 'core_weather_rain',
      label: 'Rain Intensity',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'umbrella',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_weather_sun',
      label: 'Sun Intensity',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'sunny',
      isActivityIndicator: false,
    ),
    MetricDefinition(
      id: 'core_weather_wind',
      label: 'Wind Strength',
      category: EventCategory.weather,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['anytime'],
      emoji: 'air',
      isActivityIndicator: false,
    ),

    // --- Research Quality (HCI Thesis) ---
    MetricDefinition(
      id: 'core_prompt_burden',
      label: 'How annoying were the prompts?',
      category: EventCategory.meta,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      // Afternoon + Evening windows
      windowIds: ['4c62fdff-7942-4848-8140-3c483a54daba', 'ce3317fd-5fa3-41d9-a729-4e94539a8e23'],
      emoji: 'announcement',
      isActivityIndicator: true,
    ),
  ];

  /// Standard tracking windows to seed on first launch.
  ///
  /// Stable UUIDs are used so they can be safely referenced by metrics in
  /// [metricTemplates] above — even before the database is seeded.
  static const List<WindowPreset> windowPresets = [
    WindowPreset(
      id: '9fb76442-59ad-49cb-8d93-77904690e6ef',
      label: 'Early Morning',
      startHour: 7,
      startMinute: 0,
      endHour: 9,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      id: 'e31d345d-e7f9-4c96-b8b5-f5e9e72a9d60',
      label: 'Late Morning',
      startHour: 10,
      startMinute: 0,
      endHour: 12,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      id: '4c62fdff-7942-4848-8140-3c483a54daba',
      label: 'Afternoon Sync',
      startHour: 14,
      startMinute: 0,
      endHour: 16,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      id: 'ce3317fd-5fa3-41d9-a729-4e94539a8e23',
      label: 'Evening Review',
      startHour: 19,
      startMinute: 0,
      endHour: 21,
      endMinute: 0,
      isEnabled: true,
    ),
    WindowPreset(
      id: 'b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b',
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
  final String? id;
  final String label;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final bool isEnabled;
  final int? notificationHour;
  final int? notificationMinute;

  const WindowPreset({
    this.id,
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
