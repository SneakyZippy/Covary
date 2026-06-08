import 'models/enums.dart';
import 'models/metric_definition.dart';

/// Static presets for metrics and tracking windows used for seeding the database.
///
/// Moving these here makes it easier to manage the research data without
/// cluttering the service logic.
class MetricPresets {
  // ---------------------------------------------------------------------------
  // Detailed Help & Measurement Instructions for Seeded Metrics (HCI / Thesis)
  // ---------------------------------------------------------------------------

  static const String _descMood =
      "Rate your emotional state right now on a scale from 1 (Very Low/Negative) to 10 (Very High/Positive).\n\nGuidelines:\n• Take a deep breath and tune in to your immediate feelings.\n• Avoid overthinking; go with your first gut response.\n• This helps researchers correlate subjective state changes with environmental and behavioral factors.";

  static const String _descEnergy =
      "Rate your physical and mental vitality from 1 (Completely Exhausted) to 10 (Fully Charged/Peak Alertness).\n\nGuidelines:\n• Consider your current level of fatigue, alertness, and willingness to exert effort.\n• 1 represents extreme sleepiness/lethargy; 10 represents maximum drive and absolute freshness.";

  static const String _descStress =
      "Rate your current psychological stress and pressure from 1 (Completely Calm/Relaxed) to 10 (Extremely Overwhelmed/Stressed).\n\nGuidelines:\n• Tune in to physical markers of stress (muscle tension, elevated heart rate) and mental state (racing thoughts, anxiety).\n• 1 indicates zero pressure; 10 indicates high crisis or intense cognitive overwhelm.";

  static const String _descWellbeing =
      "Rate your overall life satisfaction and wellness today from 1 (Extremely Poor) to 10 (Flourishing/Excellent).\n\nGuidelines:\n• Reflect on your general health, social connectedness, purpose, and balance over the course of today.";

  static const String _descAnxiety =
      "Rate your current feelings of worry, tension, or apprehension from 1 (None at all) to 10 (Severe/Panic-like).\n\nGuidelines:\n• Assess your nervous system's activation, muscle tightness, and mental rumination or worry.";

  static const String _descSleepQuality =
      "Rate how restorative and restful your sleep was last night from 1 (Extremely Poor/Broken) to 10 (Perfectly Restorative).\n\nGuidelines:\n• Consider how easily you fell asleep, how many times you woke up, and how refreshed you feel this morning.";

  static const String _descNapDuration =
      "Did you take a daytime nap today?\n\nGuidelines:\n• Mark 'Yes' if you slept for any duration during the day (excluding overnight sleep).\n• Helps track circadian rhythm adjustments.";

  static const String _descLightExposure =
      "Rate your exposure to natural or high-intensity bright light in the last 1-2 hours from 1 (Complete Darkness/Dim Screen) to 10 (Direct Bright Outdoor Sunlight).\n\nGuidelines:\n• 1-3: Dim indoor lighting, screen-only environment.\n• 4-6: Well-lit indoor space near a window.\n• 7-10: Outdoor natural daylight, direct sun exposure.\n• Crucial for circadian rhythm and melatonin suppression analysis.";

  static const String _descMealCount =
      "Increment this counter whenever you consume a major meal or significant snack.\n\nGuidelines:\n• Used to track feeding windows, meal frequency, and their downstream effects on sleep onset and energy levels.";

  static const String _descGeneralHealth =
      "Rate your overall physical state right now from 1 (Very Sick/Weak) to 10 (Peak Physical Health).\n\nGuidelines:\n• Focus on physical symptoms, vitality, bodily comfort, and absence of ailments.";

  static const String _descHeadache =
      "Rate any head pain or migraine intensity right now from 1 (No pain) to 10 (Unbearable/Severe Migraine).\n\nGuidelines:\n• If you have no headache, rate this as 1 (or leave it optional if not required).";

  static const String _descSick =
      "Rate the severity of cold, flu, or other acute sickness symptoms from 1 (Healthy/No Symptoms) to 10 (Extremely Ill/Bedridden).";

  static const String _descDigestion =
      "Rate your gastrointestinal comfort and digestion quality today from 1 (Severe discomfort/bloating) to 10 (Perfect comfort/healthy digestion).";

  static const String _descToiletUrge =
      "Increment this counter whenever you have a bowel movement.\n\nGuidelines:\n• Used to monitor circadian regularity, metabolic patterns, and health status.";

  static const String _descFocus =
      "Rate your mental clarity, focus, and cognitive productivity in the last hour from 1 (Extremely Distracted/Brain Fog) to 10 (Deep Flow State/Laser Focus).\n\nGuidelines:\n• Consider your ability to sustain attention on a task without wandering thoughts or digital distractions.";

  static const String _descBachelorWork =
      "Increment this counter for every 30-minute block of focused work completed on your Bachelor's thesis.\n\nGuidelines:\n• Only count blocks where you were actively researching, writing, coding, or editing with high focus.";

  static const String _descScreenMindless =
      "Log your mindless scrolling or doom-scrolling sessions on social media.\n\nGuidelines:\n• Record the duration of scrolling sessions without a specific active purpose.\n• Helps trace the exact patterns, triggers, and downstream effects on your focus and mood.";

  static const String _descSport =
      "Did you complete a session of structured exercise or intense physical activity today?\n\nGuidelines:\n• Mark 'Yes' for workouts, runs, gym sessions, sports, or brisk walks lasting at least 20-30 minutes.";

  static const String _descMeditation =
      "Did you practice mindfulness, meditation, or breathing exercises today?\n\nGuidelines:\n• Mark 'Yes' if you spent at least 5-10 minutes in deliberate stillness, breathwork, or active mindfulness practice.";

  static const String _descJournaling =
      "Did you write in a journal or complete a reflective writing exercise today?\n\nGuidelines:\n• Mark 'Yes' if you took time to write down thoughts, emotional reflections, or daily notes.";

  static const String _descOutside =
      "How many hours did you spend outdoors in nature or fresh air today?\n\nGuidelines:\n• Rate from 1 to 10 hours.\n• Estimate cumulative time spent outside (e.g., walking, sitting in a park, sitting on a balcony).";

  static const String _descGoodDeed =
      "Did you perform an intentional kind act or help someone else today?\n\nGuidelines:\n• Mark 'Yes' if you went out of your way to assist a peer, stranger, or loved one. Helps evaluate altruism's impact on mood.";

  static const String _descSocialInteraction =
      "Increment this counter whenever you have an unplanned conversation or social encounter.\n\nGuidelines:\n• Used to study the spontaneous mood-lifting effects of unexpected human connection.";

  static const String _descSO =
      "Did you spend quality, dedicated time with your significant other (SO) today?\n\nGuidelines:\n• Mark 'Yes' if you had meaningful interactive time together, rather than just sharing space.";

  static const String _descCoffee =
      "Increment this counter for every standard cup of coffee, energy drink, or concentrated caffeine source consumed.\n\nGuidelines:\n• Crucial for charting the impact of caffeine timing on sleep latency and subjective energy.";

  static const String _descWater =
      "Increment this counter for every standard glass (approx. 250ml) of water consumed.\n\nGuidelines:\n• Tracks hydration status and its immediate correlations with mental clarity and physical energy.";

  static const String _descAlcohol =
      "Increment this counter for every standard alcoholic drink consumed (e.g., beer, glass of wine, shot).\n\nGuidelines:\n• Tracks alcohol intake to analyze its profound, delayed effects on sleep architecture and next-day fatigue.";

  static const String _descPeriodFlow =
      "Rate your menstrual flow today on a scale from 1 (Very Light spotting) to 10 (Very Heavy flow).\n\nGuidelines:\n• Used to map hormonal fluctuations against well-being and pain metrics.";

  static const String _descPeriodDesire =
      "Rate your libido or sexual desire today from 1 (Extremely Low/None) to 10 (Extremely High).";

  static const String _descPeriodCramps =
      "Rate any menstrual pain or cramping today from 1 (No pain) to 10 (Severe, debilitating cramps).";

  static const String _descRain =
      "Rate the average rain intensity in your location today from 1 (Dry/No rain) to 10 (Torrential Downpour).";

  static const String _descSun =
      "Rate the solar brightness or sunshine in your location today from 1 (Completely Overcast/Gloomy) to 10 (Direct, Intense Sunshine).";

  static const String _descWind =
      "Rate the wind strength in your location today from 1 (Calm/No breeze) to 10 (Strong gale/Storm conditions).";

  static const String _descPromptBurden =
      "Rate the perceived subjective prompt burden of the app's notifications/reminders today from 1 (Not annoying at all/Seamless) to 10 (Extremely intrusive/Frustrating).\n\nGuidelines:\n• 1: You barely noticed them, or they fit perfectly into your day.\n• 5: Moderate disruption; had to put off logging sometimes.\n• 10: Extremely disruptive, made you want to disable notifications.\n• Critical HCI research metric for tuning Ecological Momentary Assessment (EMA) protocols.";

  static const String _descSmoked =
      "Increment this counter whenever you smoke a cigarette or vape.\n\nGuidelines:\n• Designed to log immediate smoking behavior to monitor psychological triggers and correlations with stress levels.";

  /// Map mapping metric ID to its instructions/guidelines.
  static const Map<String, String> metricDescriptions = {
    'core_mood': _descMood,
    'core_energy': _descEnergy,
    'core_stress': _descStress,
    'core_wellbeing': _descWellbeing,
    'core_anxiety': _descAnxiety,
    'core_sleep_quality': _descSleepQuality,
    'core_nap_duration': _descNapDuration,
    'core_light_exposure': _descLightExposure,
    'core_meal_count': _descMealCount,
    '3a4d43d5-7459-481e-bf3c-97e725fa3105': _descGeneralHealth,
    'core_headache': _descHeadache,
    'core_sick': _descSick,
    'core_digestion': _descDigestion,
    'core_toilet_urge': _descToiletUrge,
    'core_focus': _descFocus,
    'e4a45a3d-a994-4ec8-be8c-fdf0ad511910': _descBachelorWork,
    'core_screen_mindless': _descScreenMindless,
    'core_sport': _descSport,
    'core_meditation': _descMeditation,
    'core_journaling': _descJournaling,
    'core_outside': _descOutside,
    'core_good_deed': _descGoodDeed,
    'c2f69108-3834-4b29-ba98-fae24d85124d': _descSocialInteraction,
    '4d86d597-6772-4aa0-a4b8-ba9befce1d7a': _descSO,
    'core_coffee_intake': _descCoffee,
    'core_water_intake': _descWater,
    'core_alcohol_intake': _descAlcohol,
    'core_period_flow': _descPeriodFlow,
    'core_period_desire': _descPeriodDesire,
    'core_period_cramps': _descPeriodCramps,
    'core_weather_rain': _descRain,
    'core_weather_sun': _descSun,
    'core_weather_wind': _descWind,
    'core_prompt_burden': _descPromptBurden,
    '4b4ab972-ef92-4344-8573-18bda9e259db': _descSmoked,
  };

  /// Static helper to resolve descriptions dynamically.
  static String? getMetricDescription(String id) => metricDescriptions[id];

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
      description: _descMood,
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
      description: _descEnergy,
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
      description: _descStress,
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
      description: _descWellbeing,
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
      description: _descAnxiety,
    ),

    // --- Circadian Anchors & Sleep ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['9fb76442-59ad-49cb-8d93-77904690e6ef'],
      emoji: 'bedtime',
      isActivityIndicator: true,
      description: _descSleepQuality,
    ),
    MetricDefinition(
      id: 'core_nap_duration',
      label: 'Daytime Nap?',
      category: EventCategory.health,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'hotel',
      isActivityIndicator: false,
      description: _descNapDuration,
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
      description: _descLightExposure,
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
      retroReliableOverride: false,
      description: _descMealCount,
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
      description: _descGeneralHealth,
    ),
    MetricDefinition(
      id: 'core_headache',
      label: 'Headache Intensity',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: [], // Quick Log Only
      emoji: 'psychology',
      isActivityIndicator: false,
      description: _descHeadache,
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
      description: _descSick,
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
      description: _descDigestion,
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
      description: _descToiletUrge,
    ),

    // --- Performance & Productivity ---
    MetricDefinition(
      id: 'core_focus',
      label: 'Concentration/Focus',
      category: EventCategory.productivity,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: [
        '4c62fdff-7942-4848-8140-3c483a54daba',
        'ce3317fd-5fa3-41d9-a729-4e94539a8e23',
      ],
      emoji: 'lightbulb',
      isActivityIndicator: false,
      description: _descFocus,
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
      description: _descBachelorWork,
    ),
    MetricDefinition(
      id: 'core_screen_mindless',
      label: 'Mindless Scrolling',
      category: EventCategory.behavior,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'phonelink_erase',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descScreenMindless,
    ),

    // --- Behavior & Habits ---
    MetricDefinition(
      id: 'core_sport',
      label: 'Physical Activity',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['homescreen', 'b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'run',
      isActivityIndicator: false,
      description: _descSport,
    ),
    MetricDefinition(
      id: 'core_meditation',
      label: 'Mindfulness / Meditation',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'meditation',
      isActivityIndicator: false,
      description: _descMeditation,
    ),
    MetricDefinition(
      id: 'core_journaling',
      label: 'Journaling',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'edit',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descJournaling,
    ),
    MetricDefinition(
      id: 'core_outside',
      label: 'Time spent Outside (hours)',
      category: EventCategory.behavior,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'forest',
      isActivityIndicator: true,
      description: _descOutside,
    ),

    // --- Social Interactions ---
    MetricDefinition(
      id: 'core_good_deed',
      label: 'Did a Good Deed',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'favorite',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descGoodDeed,
    ),
    MetricDefinition(
      id: 'c2f69108-3834-4b29-ba98-fae24d85124d',
      label: 'Unexpected Social Interaction',
      category: EventCategory.social,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: [],
      emoji: 'bolt',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descSocialInteraction,
    ),
    MetricDefinition(
      id: '4d86d597-6772-4aa0-a4b8-ba9befce1d7a',
      label: 'Spent time with SO',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'favorite',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descSO,
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
      description: _descCoffee,
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
      description: _descWater,
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
      description: _descAlcohol,
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
      description: _descPeriodFlow,
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
      description: _descPeriodDesire,
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
      description: _descPeriodCramps,
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
      description: _descRain,
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
      description: _descSun,
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
      description: _descWind,
    ),

    // --- Research Quality (HCI Thesis) ---
    MetricDefinition(
      id: 'core_prompt_burden',
      label: 'How annoying were the prompts?',
      category: EventCategory.meta,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      windowIds: ['b7e1f2a3-4c5d-6e7f-8a9b-0c1d2e3f4a5b'],
      emoji: 'announcement',
      isActivityIndicator: true,
      description: _descPromptBurden,
    ),

    MetricDefinition(
      id: '4b4ab972-ef92-4344-8573-18bda9e259db',
      label: 'Smoked',
      category: EventCategory.behavior,
      inputType: MetricInputType.counter,
      isEnabled: true,
      windowIds: ['homescreen'],
      emoji: 'air',
      isActivityIndicator: false,
      retroReliableOverride: false,
      description: _descSmoked,
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
      label: 'Afternoon',
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
