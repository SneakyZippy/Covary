import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/enums.dart';
import 'tables/events_table.dart';
import 'tables/custom_metrics_table.dart';
import 'tables/tracking_windows_table.dart';
import 'tables/table_utils.dart';

part 'app_database.g.dart';

/// The main application database.
@DriftDatabase(tables: [Events, CustomMetrics, TrackingWindows])
class AppDatabase extends _$AppDatabase {
  AppDatabase._internal(super.e);

  /// Singleton instance of the database.
  static AppDatabase? _instance;

  static AppDatabase getInstance() {
    _instance ??= AppDatabase._internal(_openConnection());
    return _instance!;
  }

  @override
  int get schemaVersion => 14;
  
  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async {
      await m.createAll();
    },
    onUpgrade: (Migrator m, int from, int to) async {
      // Helper for safer column addition
      Future<void> addColumnSafe(TableInfo table, GeneratedColumn column) async {
        try {
          await m.addColumn(table, column);
        } catch (e) {
          final error = e.toString().toLowerCase();
          if (error.contains('duplicate column name') || error.contains('already exists')) {
            // Column already exists, we can safely ignore this
            return;
          }
          rethrow;
        }
      }
 
      if (from < 2) await m.createTable(customMetrics);
      if (from < 5) {
        await m.createTable(trackingWindows);
      }
      if (from < 6) {
        // Renaming tables for better terminology (Habit -> Metric, Slot -> Window)
        try {
          await customStatement('ALTER TABLE custom_habits RENAME TO custom_metrics');
        } catch (_) {}
        try {
          await customStatement('ALTER TABLE tracking_slots RENAME TO tracking_windows');
        } catch (_) {}
        
        // Renaming columns
        try {
          await customStatement('ALTER TABLE custom_metrics RENAME COLUMN slot_ids TO window_ids');
        } catch (_) {}
      }
      if (from < 7) {
        // Normalize 'habit' category to 'behavior' for both tables
        await customStatement("UPDATE custom_metrics SET category = 'behavior' WHERE category = 'habit'");
        await customStatement("UPDATE events SET category = 'behavior' WHERE category = 'habit'");
      }
      if (from < 8) {
        // Add sessionId column to events table
        await addColumnSafe(events, events.sessionId);
      }
      if (from < 9) {
        // Add notification columns to tracking_windows table
        await addColumnSafe(trackingWindows, trackingWindows.isNotificationEnabled);
        await addColumnSafe(trackingWindows, trackingWindows.notificationHour);
        await addColumnSafe(trackingWindows, trackingWindows.notificationMinute);
      }
      if (from < 10) {
        // Add nullable recall-reliability override column to custom_metrics
        await addColumnSafe(customMetrics, customMetrics.isRetroReliable);
      }
      if (from < 11) {
        // Add isEnabled column to tracking_windows table
        await addColumnSafe(trackingWindows, trackingWindows.isEnabled);
      }
      if (from < 12) {
        // Rename legacy app usage labels for dynamic category support
        await customStatement("UPDATE events SET label = 'category_time:social' WHERE label = 'social_screen_time_minutes'");
        await customStatement("UPDATE events SET label = 'category_time:entertainment' WHERE label = 'entertainment_screen_time_minutes'");
        await customStatement("UPDATE events SET label = 'total_screen_time' WHERE label = 'total_screen_time_minutes'");
      }
      if (from < 13) {
        // Migration to version 13: Increase label length in events table (Drift-side validation)
        // SQLite doesn't enforce length, so no SQL is strictly needed here, 
        // but we bump the version to trigger code regeneration and maintain schema history.
      }
      if (from < 14) {
        // Add recordedAt column to events table to separate occurrence time from logging time.
        await addColumnSafe(events, events.recordedAt);
      }
    },
  );

  // ---------------------------------------------------------------------------
  // Event CRUD operations
  // ---------------------------------------------------------------------------

  Future<int> insertEvent(EventsCompanion event) {
    return into(events).insert(event);
  }

  Stream<List<Event>> watchAllEvents() {
    return (select(events)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).watch();
  }

  Future<List<Event>> getEventsByCategory(EventCategory category) {
    return (select(events)..where((t) => t.category.equalsValue(category))).get();
  }

  Future<List<Event>> getEventsByLabel(String label, {EventCategory? category}) {
    return (select(events)..where((t) {
      final labelFilter = t.label.equals(label);
      if (category != null) {
        return labelFilter & t.category.equalsValue(category);
      }
      return labelFilter;
    })).get();
  }

  Stream<int> watchTodayCountForLabel(String label) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    return (select(events)
          ..where((t) => t.label.equals(label))
          ..where((t) => t.timestamp.isBiggerOrEqualValue(todayStart)))
        .watch()
        .map((list) => list.length);
  }

  Future<List<Event>> getAllEvents() {
    return (select(events)..orderBy([(t) => OrderingTerm.desc(t.timestamp)])).get();
  }

  Future<int> deleteEvent(String id) {
    return (delete(events)..where((t) => t.id.equals(id))).go();
  }

  Future<int> updateEvent(String id, EventsCompanion companion) {
    return (update(events)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<List<Event>> getUsageEvents(DateTime start, DateTime end) {
    return (select(events)
          ..where((t) => t.category.equalsValue(EventCategory.appUsage))
          ..where((t) => t.timestamp.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
        .get();
  }

  Future<List<Event>> getEventsInDateRange(DateTime start, DateTime end) {
    return (select(events)
          ..where((t) => t.timestamp.isBetweenValues(start, end))
          ..orderBy([(t) => OrderingTerm.desc(t.timestamp)]))
        .get();
  }

  // ---------------------------------------------------------------------------
  // Custom Metrics CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertCustomMetric(CustomMetricsCompanion metric) {
    return into(customMetrics).insertOnConflictUpdate(metric);
  }

  Future<List<CustomMetric>> getAllCustomMetrics() {
    return select(customMetrics).get();
  }

  Stream<List<CustomMetric>> watchCustomMetrics() {
    return select(customMetrics).watch();
  }

  Future<int> setCustomMetricEnabled(String id, bool enabled) {
    return (update(customMetrics)..where((t) => t.id.equals(id))).write(
      CustomMetricsCompanion(isEnabled: Value(enabled)),
    );
  }

  Future<int> updateCustomMetricWindows(String id, String windowIds) {
    return (update(customMetrics)..where((t) => t.id.equals(id))).write(
      CustomMetricsCompanion(windowIds: Value(windowIds)),
    );
  }

  Future<int> updateCustomMetric(String id, CustomMetricsCompanion companion) {
    return (update(customMetrics)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<int> setCustomMetricRetroReliable(String id, bool? value) {
    return (update(customMetrics)..where((t) => t.id.equals(id))).write(
      CustomMetricsCompanion(isRetroReliable: Value(value)),
    );
  }

  Future<int> deleteCustomMetric(String id) {
    if (id.isEmpty) {
      // Defensive check: prevent deletion of all rows if ID is empty
      return Future.value(0);
    }
    return (delete(customMetrics)..where((t) => t.id.equals(id))).go();
  }

  // ---------------------------------------------------------------------------
  // Tracking Windows CRUD
  // ---------------------------------------------------------------------------

  Future<int> insertTrackingWindow(TrackingWindowsCompanion window) {
    return into(trackingWindows).insertOnConflictUpdate(window);
  }

  Future<List<TrackingWindow>> getAllTrackingWindows() {
    return select(trackingWindows).get();
  }

  Stream<List<TrackingWindow>> watchTrackingWindows() {
    return select(trackingWindows).watch();
  }

  Future<int> updateTrackingWindow(String id, TrackingWindowsCompanion companion) {
    return (update(trackingWindows)..where((t) => t.id.equals(id))).write(companion);
  }

  Future<int> deleteTrackingWindow(String id) {
    return (delete(trackingWindows)..where((t) => t.id.equals(id))).go();
  }

  Future<void> clearAllMetrics() async {
    await delete(customMetrics).go();
  }

  Future<void> clearAllTrackingWindows() async {
    await delete(trackingWindows).go();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'covary.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
