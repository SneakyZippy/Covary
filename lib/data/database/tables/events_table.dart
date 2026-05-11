import 'package:drift/drift.dart';
import '../../models/enums.dart';
import 'table_utils.dart';

/// The central "Universal Event" table.
///
/// Every data point in the app is stored as a single row in this table.
class Events extends Table {
  /// Unique identifier for each event (UUID v4).
  TextColumn get id => text().clientDefault(() => uuid.v4())();

  /// When the event occurred.
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();

  /// High-level research domain: Mood, Behavior, Health, AppUsage, or Meta.
  TextColumn get category => textEnum<EventCategory>()();

  /// Specific metric name, e.g. 'Instagram', 'Steps', 'Good Deed', 'Fatigue'.
  TextColumn get label => text().withLength(min: 1, max: 100)();

  /// The actual data value, stored as text for flexibility.
  TextColumn get value => text()();

  /// HCI metric: milliseconds from opening the input form to pressing save.
  IntColumn get latencyMs => integer().withDefault(const Constant(0))();

  /// How the event was triggered: Manual, Notification, or System.
  TextColumn get triggerSource => textEnum<TriggerSource>()();

  /// How the user interacted: Click, SwipeAway, or Snooze.
  TextColumn get interactionType => textEnum<InteractionType>()();

  /// Optional grouping ID to correlate events that belong to the same session.
  TextColumn get sessionId => text().nullable()();

  /// When the event was actually logged in the app (for HCI/compliance metrics).
  /// Null for older data (meaning recordedAt == timestamp).
  DateTimeColumn get recordedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
