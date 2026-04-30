import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../data/database/app_database.dart';
import 'app_usage_service.dart';
import 'health_service.dart';
import 'passive_sensing_service.dart';

/// Callback for WorkManager to execute background tasks.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    debugPrint('[WorkManager] Task fired: $taskName');
    try {
      final db = AppDatabase.getInstance();

      final appUsageService = AppUsageService();
      await appUsageService.init();

      final sensingService = PassiveSensingService(
        db: db,
        health: HealthService(),
        appUsage: appUsageService,
      );

      // Sync the full previous day to ensure completeness.
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await sensingService.syncAll(targetDate: yesterday);
      
      // Also sync the last 24 hours for real-time data visibility today.
      await sensingService.syncAll();
      
      debugPrint('[WorkManager] Passive sync for yesterday and today completed successfully.');
      return Future.value(true);
    } catch (e) {
      debugPrint('[WorkManager] Passive sync failed: $e');
      return Future.value(false);
    }
  });
}

const kPassiveSyncTask = 'passive_sync';
