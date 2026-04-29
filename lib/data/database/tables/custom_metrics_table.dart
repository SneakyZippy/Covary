import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'table_utils.dart';

/// Stores user-defined custom metrics.
class CustomMetrics extends Table {
  /// Unique identifier (UUID v4).
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  /// Display name for the metric.
  TextColumn get label => text().withLength(min: 1, max: 50)();

  /// Research domain: mood, behavior, health, etc.
  TextColumn get category => textEnum<EventCategory>()();

  /// Determines the input widget.
  TextColumn get inputType => textEnum<MetricInputType>()();

  /// Comma-separated list of TrackingWindow IDs.
  TextColumn get windowIds => text().withDefault(const Constant('anytime'))();

  /// Whether this metric is currently shown on the Home screen.
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  /// Visual identifier (emoji or icon).
  TextColumn get emoji => text().nullable()();

  /// User-set override for retrospective recall reliability.
  /// null  → derived from inputType (yesNo/counter = reliable, scales = not).
  /// true  → always reliable (e.g. a scale metric the user knows is factual).
  /// false → always unreliable (user explicitly marks a yesNo as subjective).
  BoolColumn get isRetroReliable => boolean().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
