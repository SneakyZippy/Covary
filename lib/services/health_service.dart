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

  /// The data types we request from Health Connect / HealthKit.
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
      // Step 0: Check Health Connect SDK status (Android only).
      if (defaultTargetPlatform == TargetPlatform.android) {
        final status = await _health.getHealthConnectSdkStatus();
        if (status != HealthConnectSdkStatus.sdkAvailable) {
          debugPrint('[HealthService] Health Connect SDK not available: $status. Please ensure Health Connect is installed.');
          return false;
        }
      }

      // Step 1: Request ACTIVITY_RECOGNITION via permission_handler.
      final activityStatus = await Permission.activityRecognition.request();
      if (!activityStatus.isGranted) {
        debugPrint('[HealthService] ACTIVITY_RECOGNITION denied.');
        return false;
      }

      // Step 2: Request Health Connect data permissions.
      // Explicitly specify READ access to be safe.
      final granted = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      debugPrint('[HealthService] Health Connect authorization: $granted');
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
      final now = DateTime.now();
      final effectiveEnd = endTime ?? now;
      final effectiveStart = startTime ?? now.subtract(const Duration(hours: 24));

      final data = await _health.getHealthDataFromTypes(
        startTime: effectiveStart,
        endTime: effectiveEnd,
        types: [HealthDataType.SLEEP_SESSION],
      );

      if (data.isEmpty) {
        debugPrint('[HealthService] No sleep data in last 24h.');
        return null;
      }

      // Sum all sleep session durations (in minutes), then convert to hours.
      double totalMinutes = 0;
      for (final point in data) {
        final durationMs =
            point.dateTo.millisecondsSinceEpoch -
            point.dateFrom.millisecondsSinceEpoch;
        totalMinutes += durationMs / 1000 / 60;
      }

      final hours = totalMinutes / 60;
      debugPrint('[HealthService] Sleep duration: ${hours.toStringAsFixed(2)}h');
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
