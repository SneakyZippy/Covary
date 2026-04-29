import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import 'app_usage_service.dart';
import 'health_service.dart';

/// Orchestrates all passive data collection for the Covary EMA study.
///
/// This service is the single point of entry for background syncs. It is called:
/// 1. **Every 4 hours** by the WorkManager background task.
/// 2. **On demand** from the [PermissionShieldScreen] "Sync Now" button.
///
/// Each sync cycle reads up to 5 passive data points and writes them to the
/// Drift [Events] table with `triggerSource: system` and `latencyMs: 0`.
///
/// ## HCI Compliance
/// - `triggerSource` = [TriggerSource.system] — data was not user-initiated.
/// - `interactionType` = [InteractionType.click] — system "auto-confirm" action.
/// - `latencyMs` = 0 — no human latency to measure for passive events.
///
/// ## Thesis Note
/// Passive sensing removes self-reporting bias for objective metrics. Comparing
/// [TriggerSource.system] events (e.g., actual step count) against
/// [TriggerSource.manual] events (e.g., subjective metrics) is a core
/// analysis axis in the research design.
class PassiveSensingService {
  final AppDatabase _db;
  final HealthService _health;
  final AppUsageService _appUsage;

  PassiveSensingService({
    required AppDatabase db,
    required HealthService health,
    required AppUsageService appUsage,
  })  : _db = db,
        _health = health,
        _appUsage = appUsage;

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Runs a full passive sync cycle.
  ///
  /// [targetDate]: If provided, syncs the full 24h window for that date.
  /// If null, syncs "Today so far" (from 00:00:00 until now).
  ///
  /// This method is safe to call from a WorkManager background isolate.
  Future<void> syncAll({DateTime? targetDate}) async {
    final sessionId = const Uuid().v4();
    
    // Define the interval
    final DateTime start;
    final DateTime end;
    final DateTime referenceTime; // The timestamp we use for the event row

    if (targetDate != null) {
      // Full day sync (e.g. for Yesterday)
      start = DateTime(targetDate.year, targetDate.month, targetDate.day, 0, 0, 0);
      end = DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59, 59);
      referenceTime = end;
      debugPrint('[PassiveSensingService] Targeting FULL DAY: ${targetDate.toIso8601String().split('T')[0]}');
    } else {
      // "Today so far" sync (Manual trigger)
      final now = DateTime.now();
      start = DateTime(now.year, now.month, now.day, 0, 0, 0);
      end = now;
      referenceTime = now;
      debugPrint('[PassiveSensingService] Targeting TODAY SO FAR');
    }

    debugPrint('[PassiveSensingService] Syncing interval: $start to $end (Session: $sessionId)…');

    // --- Health Connect data ---
    await _syncHealth(sessionId, start, end, referenceTime);

    // --- App Usage data ---
    await _syncAppUsage(sessionId, start, end, referenceTime);

    debugPrint('[PassiveSensingService] Sync cycle complete.');
  }

  // ---------------------------------------------------------------------------
  // Private sync methods
  // ---------------------------------------------------------------------------

  /// Fetches sleep duration and step count and logs them.
  Future<void> _syncHealth(String sessionId, DateTime start, DateTime end, DateTime timestamp) async {
    // Sleep duration
    try {
      final sleepHours = await _health.fetchSleepDurationHours(startTime: start, endTime: end);
      if (sleepHours != null) {
        await _logDailyMetric(
          category: EventCategory.health,
          label: 'sleep_duration_hours',
          value: sleepHours.toStringAsFixed(2),
          sessionId: sessionId,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      debugPrint('[PassiveSensingService] Sleep sync error: $e');
    }

    // Step count
    try {
      final steps = await _health.fetchStepCount(startTime: start, endTime: end);
      if (steps != null) {
        await _logDailyMetric(
          category: EventCategory.health,
          label: 'step_count',
          value: steps.toString(),
          sessionId: sessionId,
          timestamp: timestamp,
        );
      }
    } catch (e) {
      debugPrint('[PassiveSensingService] Step count sync error: $e');
    }
  }

  /// Fetches total, social, and entertainment screen time and logs them.
  Future<void> _syncAppUsage(String sessionId, DateTime start, DateTime end, DateTime timestamp) async {
    final usageTasks = {
      'total_screen_time_minutes': () => _appUsage.fetchTotalScreenTimeMinutes(startTime: start, endTime: end),
      'social_screen_time_minutes': () => _appUsage.fetchSocialScreenTimeMinutes(startTime: start, endTime: end),
      'entertainment_screen_time_minutes': () => _appUsage.fetchEntertainmentScreenTimeMinutes(startTime: start, endTime: end),
    };

    for (final task in usageTasks.entries) {
      try {
        final val = await task.value();
        if (val != null) {
          await _logDailyMetric(
            category: EventCategory.appUsage,
            label: task.key,
            value: val.toString(),
            sessionId: sessionId,
            timestamp: timestamp,
          );
        }
      } catch (e) {
        debugPrint('[PassiveSensingService] ${task.key} sync error: $e');
      }
    }

    // Per-app screen time
    try {
      final perApp = await _appUsage.fetchPerAppScreenTimeMinutes(startTime: start, endTime: end);
      if (perApp != null) {
        for (final entry in perApp.entries) {
          await _logDailyMetric(
            category: EventCategory.appUsage,
            label: 'app_time:${entry.key}',
            value: entry.value.toString(),
            sessionId: sessionId,
            timestamp: timestamp,
          );
        }
      }
    } catch (e) {
      debugPrint('[PassiveSensingService] Per-app time sync error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Event writer with Deduplication
  // ---------------------------------------------------------------------------

  /// Logs a metric while ensuring only one "system" record exists for that day/label.
  Future<void> _logDailyMetric({
    required EventCategory category,
    required String label,
    required String value,
    required String sessionId,
    required DateTime timestamp,
  }) async {
    // Check if a system record for this label already exists on this specific day.
    // We define "same day" by comparing the year, month, and day of the timestamp.
    final dayStart = DateTime(timestamp.year, timestamp.month, timestamp.day);
    final dayEnd = dayStart.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final existing = await (_db.select(_db.events)
          ..where((t) => t.category.equalsValue(category))
          ..where((t) => t.label.equals(label))
          ..where((t) => t.triggerSource.equalsValue(TriggerSource.system))
          ..where((t) => t.timestamp.isBetweenValues(dayStart, dayEnd))
          ..limit(1))
        .getSingleOrNull();

    if (existing != null) {
      // Update existing record with the new value (and new sessionId)
      await (_db.update(_db.events)..where((t) => t.id.equals(existing.id))).write(
        EventsCompanion(
          value: Value(value),
          sessionId: Value(sessionId),
          // We update the timestamp to the end of the window to mark it as the latest
          timestamp: Value(timestamp),
        ),
      );
      debugPrint('[PassiveSensingService] UPDATED → $label = $value for ${dayStart.toIso8601String().split('T')[0]}');
    } else {
      // Insert new record
      await _db.insertEvent(
        EventsCompanion(
          category: Value(category),
          label: Value(label),
          value: Value(value),
          latencyMs: const Value(0),
          triggerSource: const Value(TriggerSource.system),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(sessionId),
          timestamp: Value(timestamp),
        ),
      );
      debugPrint('[PassiveSensingService] LOGGED → $label = $value for ${dayStart.toIso8601String().split('T')[0]}');
    }
  }
}
