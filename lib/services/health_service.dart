import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service responsible for reading health data from Google Health Connect (Android)
/// or Apple HealthKit (iOS) via the `health` package.
///
/// Fetches the last 24 hours of sleep duration and step count, which are the
/// two passive health metrics in the Covary research design. All operations
/// are wrapped in try/catch to prevent background sync failures from crashing
/// the app.
///
/// ## Thesis Note
/// Sleep duration and step count are the primary "objective health" variables
/// in the research model. They are correlated with subjective wellbeing (Mood,
/// Fatigue) to detect lagged effects (e.g., poor sleep → next-day fatigue).
class HealthService {
  final Health _health = Health();
  bool _configured = false;

  /// Ensures the health plugin is configured before any API call.
  /// Must be called once before permissions, data reads, or writes.
  Future<void> _ensureConfigured() async {
    if (!_configured) {
      await _health.configure();
      _configured = true;
    }
  }

  /// The data types we request from Health Connect / HealthKit.
  /// We include both SLEEP_SESSION and SLEEP_ASLEEP for maximum compatibility
  /// across different Android devices (some report sessions, others individual points).
  static const List<HealthDataType> _readTypes = [
    HealthDataType.SLEEP_SESSION,
    HealthDataType.STEPS,
  ];

  // ---------------------------------------------------------------------------
  // Permission Management
  // ---------------------------------------------------------------------------

  /// Requests the ACTIVITY_RECOGNITION runtime permission (required on API 29+
  /// before Health Connect permissions can be granted) and then requests the
  /// Health Connect READ_SLEEP and READ_STEPS permissions.
  ///
  /// Returns `true` if all permissions are granted, `false` otherwise.
  Future<bool> requestPermissions() async {
    try {
      // Step 0: Configure the health plugin (required since health 13.x).
      await _ensureConfigured();

      // Step 0b: Check Health Connect SDK status (Android only).
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('[HealthService] Health Connect SDK not available: $status. Please ensure Health Connect is installed.');
          return false;
        }
      }

      // Step 1: Request ACTIVITY_RECOGNITION via permission_handler.
      // This is often required for step counting to work correctly on Android.
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) {
        debugPrint('[HealthService] ACTIVITY_RECOGNITION denied.');
        // We continue anyway as some devices might not strictly require it for Health Connect
      }

      // Step 2: Request Health Connect data permissions.
      // We let the plugin handle the permission mapping automatically.
      debugPrint('[HealthService] Requesting authorization for: $_readTypes');
      final granted = await _health.requestAuthorization(_readTypes);
      
      debugPrint('[HealthService] Health Connect authorization result: $granted');
      
      if (!granted) {
        // Diagnostic: Check if they are already granted but plugin reported false
        final alreadyGranted = await _health.hasPermissions(_readTypes);
        debugPrint('[HealthService] Diagnostic - already granted: $alreadyGranted');
        return alreadyGranted ?? false;
      }
      
      return granted;
    } catch (e) {
      debugPrint('[HealthService] requestPermissions error: $e');
      return false;
    }
  }

  /// Checks whether the current Health Connect permissions are already granted,
  /// without triggering a new permission dialog.
  ///
  /// Note: On Android, Health Connect does not expose a reliable "check without
  /// ask" API. This method attempts a small data fetch as a proxy check.
  Future<bool> hasPermissions() async {
    try {
      await _ensureConfigured();
      // hasPermissions returns null if status is indeterminate (treat as false).
      final result = await _health.hasPermissions(_readTypes);
      return result ?? false;
    } catch (e) {
      debugPrint('[HealthService] hasPermissions error: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Data Fetching
  // ---------------------------------------------------------------------------

  /// Fetches total sleep duration in hours from the last 24 hours.
  ///
  /// Sums all [HealthDataType.SLEEP_SESSION] records that ended within the
  /// window. Returns `null` if no data is available or an error occurs.
  Future<double?> fetchSleepDurationHours({DateTime? startTime, DateTime? endTime}) async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final effectiveEnd = endTime ?? now;
      final effectiveStart = startTime ?? now.subtract(const Duration(hours: 24));

      final data = await _health.getHealthDataFromTypes(
        startTime: effectiveStart,
        endTime: effectiveEnd,
        types: [HealthDataType.SLEEP_SESSION, HealthDataType.SLEEP_ASLEEP],
      );

      if (data.isEmpty) {
        debugPrint('[HealthService] No sleep data (session or asleep) in last 24h.');
        return null;
      }

      // 1. Extract all intervals (start, end)
      List<({DateTime start, DateTime end})> intervals =
          data.map((p) => (start: p.dateFrom, end: p.dateTo)).toList();

      // 2. Sort by start time
      intervals.sort((a, b) => a.start.compareTo(b.start));

      // 3. Merge overlapping intervals
      List<({DateTime start, DateTime end})> merged = [];
      if (intervals.isNotEmpty) {
        var current = intervals[0];
        for (int i = 1; i < intervals.length; i++) {
          final next = intervals[i];
          if (next.start.isBefore(current.end)) {
            // Overlap: extend current interval to the later end time
            if (next.end.isAfter(current.end)) {
              current = (start: current.start, end: next.end);
            }
          } else {
            // No overlap: save current and move to next
            merged.add(current);
            current = next;
          }
        }
        merged.add(current);
      }

      // 4. Sum total unique minutes
      double totalMinutes = 0;
      for (final interval in merged) {
        totalMinutes += interval.end.difference(interval.start).inSeconds / 60;
      }

      final hours = totalMinutes / 60;
      debugPrint(
          '[HealthService] Sleep duration (merged/deduplicated): ${hours.toStringAsFixed(2)}h');
      return hours;
    } catch (e) {
      debugPrint('[HealthService] fetchSleepDurationHours error: $e');
      return null;
    }
  }

  /// Fetches total step count from the last 24 hours.
  ///
  /// Uses Health Connect's optimized [getTotalStepsInInterval] API, which
  /// avoids iterating individual data points. Returns `null` on error.
  Future<int?> fetchStepCount({DateTime? startTime, DateTime? endTime}) async {
    try {
      await _ensureConfigured();
      final now = DateTime.now();
      final effectiveEnd = endTime ?? now;
      final effectiveStart = startTime ?? now.subtract(const Duration(hours: 24));

      final steps = await _health.getTotalStepsInInterval(effectiveStart, effectiveEnd);
      debugPrint('[HealthService] Step count: $steps');
      return steps;
    } catch (e) {
      debugPrint('[HealthService] fetchStepCount error: $e');
      return null;
    }
  }
}
