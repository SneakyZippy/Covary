import 'package:drift/drift.dart';
import 'table_utils.dart';

/// Defines a custom time window for tracking metrics.
class TrackingWindows extends Table {
  /// Unique identifier (UUID v4).
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  /// Human-readable name for the window (e.g. "Morning Routine").
  TextColumn get label => text().withLength(min: 1, max: 50)();

  /// Start time of the window.
  IntColumn get startHour => integer()();
  IntColumn get startMinute => integer()();

  /// End time of the window.
  IntColumn get endHour => integer()();
  IntColumn get endMinute => integer()();

  /// Whether to send a notification for this window.
  BoolColumn get isNotificationEnabled =>
      boolean().withDefault(const Constant(false))();

  /// The time to send the notification.
  IntColumn get notificationHour => integer()();
  IntColumn get notificationMinute => integer()();
  
  /// Whether this window is active for research.
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();

  @override
  Set<Column> get primaryKey => {id};
}
