import 'package:drift/drift.dart';
import '../database/app_database.dart';
import '../models/enums.dart';

abstract class EventRepository {
  Future<int> insertEvent(EventsCompanion event);
  Stream<List<Event>> watchAllEvents();
  Future<List<Event>> getEventsByCategory(EventCategory category);
  Future<List<Event>> getEventsByLabel(String label, {EventCategory? category});
  Stream<int> watchTodayCountForLabel(String label);
  Future<List<Event>> getAllEvents();
  Future<int> deleteEvent(String id);
  Future<int> updateEvent(String id, EventsCompanion companion);
  Future<List<Event>> getUsageEvents(DateTime start, DateTime end);
  Future<List<Event>> getEventsInDateRange(DateTime start, DateTime end);
  Future<void> clearAllEvents();
  Future<void> insertRawMap(Map<String, dynamic> map);
  Future<void> insertEventOrReplace(Event event);
  Future<Event?> findSystemEvent({
    required EventCategory category,
    required String label,
    required DateTime start,
    required DateTime end,
  });
  Future<Event?> findSystemEventAtTimestamp({
    required EventCategory category,
    required String label,
    required DateTime timestamp,
  });
}

class DriftEventRepository implements EventRepository {
  final AppDatabase _db;

  DriftEventRepository(this._db);

  @override
  Future<int> insertEvent(EventsCompanion event) {
    return _db.insertEvent(event);
  }

  @override
  Stream<List<Event>> watchAllEvents() {
    return _db.watchAllEvents();
  }

  @override
  Future<List<Event>> getEventsByCategory(EventCategory category) {
    return _db.getEventsByCategory(category);
  }

  @override
  Future<List<Event>> getEventsByLabel(String label, {EventCategory? category}) {
    return _db.getEventsByLabel(label, category: category);
  }

  @override
  Stream<int> watchTodayCountForLabel(String label) {
    return _db.watchTodayCountForLabel(label);
  }

  @override
  Future<List<Event>> getAllEvents() {
    return _db.getAllEvents();
  }

  @override
  Future<int> deleteEvent(String id) {
    return _db.deleteEvent(id);
  }

  @override
  Future<int> updateEvent(String id, EventsCompanion companion) {
    return _db.updateEvent(id, companion);
  }

  @override
  Future<List<Event>> getUsageEvents(DateTime start, DateTime end) {
    return _db.getUsageEvents(start, end);
  }

  @override
  Future<List<Event>> getEventsInDateRange(DateTime start, DateTime end) {
    return _db.getEventsInDateRange(start, end);
  }

  @override
  Future<void> clearAllEvents() {
    return _db.delete(_db.events).go();
  }

  @override
  Future<void> insertRawMap(Map<String, dynamic> map) async {
    final entity = _db.events.map(map);
    await _db.into(_db.events).insert(entity, mode: InsertMode.insertOrReplace);
  }

  @override
  Future<void> insertEventOrReplace(Event event) async {
    await _db.into(_db.events).insert(event, mode: InsertMode.insertOrReplace);
  }

  @override
  Future<Event?> findSystemEvent({
    required EventCategory category,
    required String label,
    required DateTime start,
    required DateTime end,
  }) {
    return (_db.select(_db.events)
          ..where((t) => t.category.equalsValue(category))
          ..where((t) => t.label.equals(label))
          ..where((t) => t.triggerSource.equalsValue(TriggerSource.system))
          ..where((t) => t.timestamp.isBetweenValues(start, end))
          ..limit(1))
        .getSingleOrNull();
  }

  @override
  Future<Event?> findSystemEventAtTimestamp({
    required EventCategory category,
    required String label,
    required DateTime timestamp,
  }) {
    return (_db.select(_db.events)
          ..where((t) => t.category.equalsValue(category))
          ..where((t) => t.label.equals(label))
          ..where((t) => t.triggerSource.equalsValue(TriggerSource.system))
          ..where((t) => t.timestamp.equals(timestamp))
          ..limit(1))
        .getSingleOrNull();
  }
}
