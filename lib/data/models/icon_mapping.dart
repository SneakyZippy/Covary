import 'package:flutter/material.dart';

/// Maps icon identifiers to Material [IconData].
/// 
/// If the identifier is a standard Emoji (e.g. '😊'), it is returned as null
/// so the UI can decide to render it as text.
IconData? getIconData(String identifier) {
  switch (identifier) {
    case 'mood':
    case 'sentiment_satisfied':
      return Icons.sentiment_satisfied_alt_rounded;
    case 'energy':
    case 'bolt':
      return Icons.bolt_rounded;
    case 'stress':
    case 'psychology':
      return Icons.psychology_rounded;
    case 'sport':
    case 'run':
      return Icons.directions_run_rounded;
    case 'bike':
      return Icons.directions_bike_rounded;
    case 'sleep':
    case 'bedtime':
      return Icons.bedtime_rounded;
    case 'healthy':
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'meat':
      return Icons.kebab_dining_rounded;
    case 'fruit':
    case 'nutrition':
      return Icons.apple_rounded;
    case 'veg':
    case 'eco':
      return Icons.eco_rounded;
    case 'book':
    case 'reading':
      return Icons.menu_book_rounded;
    case 'edit':
    case 'writing':
      return Icons.edit_note_rounded;
    case 'coffee':
      return Icons.coffee_rounded;
    case 'water':
      return Icons.water_drop_rounded;
    case 'meditation':
    case 'yoga':
      return Icons.self_improvement_rounded;
    case 'gym':
      return Icons.fitness_center_rounded;
    case 'work':
      return Icons.work_outline_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'favorite':
      return Icons.favorite_rounded;
    case 'star':
      return Icons.star_rounded;
    case 'lightbulb':
      return Icons.lightbulb_outline_rounded;
    case 'task':
      return Icons.task_alt_rounded;
    case 'wrench':
      return Icons.build_circle_rounded;
    case 'water_drop':
      return Icons.water_drop_rounded;
    case 'personal_injury':
      return Icons.personal_injury_rounded;
    case 'sick':
      return Icons.sick_rounded;
    case 'wc':
      return Icons.wc_rounded;
    case 'umbrella':
      return Icons.umbrella_rounded;
    case 'sunny':
      return Icons.sunny;
    case 'air':
      return Icons.air_rounded;
    case 'forest':
      return Icons.forest_rounded;
    case 'hotel':
      return Icons.hotel_rounded;
    case 'wb_sunny':
      return Icons.wb_sunny_rounded;
    case 'phonelink_erase':
      return Icons.phonelink_erase_rounded;
    case 'announcement':
      return Icons.campaign_rounded;
    case 'liquor':
      return Icons.liquor_rounded;
    default:
      return null;
  }
}

/// A curated list of minimalistic icons for the user to pick from.
final List<String> curatedIcons = [
  'sentiment_satisfied',
  'bolt',
  'psychology',
  'run',
  'bike',
  'bedtime',
  'restaurant',
  'meat',
  'nutrition',
  'eco',
  'book',
  'edit',
  'coffee',
  'water',
  'meditation',
  'gym',
  'work',
  'home',
  'favorite',
  'star',
  'lightbulb',
  'task',
  'wrench',
  'water_drop',
  'personal_injury',
  'sick',
  'wc',
  'umbrella',
  'sunny',
  'air',
  'forest',
  'hotel',
  'wb_sunny',
  'phonelink_erase',
  'announcement',
  'liquor',
];
