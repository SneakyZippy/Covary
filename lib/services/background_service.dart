import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import '../data/database/app_database.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/profile_repository.dart';
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
      final eventRepo = DriftEventRepository(db);
      final profileRepo = SharedPrefsProfileRepository();
      await profileRepo.init();

      final appUsageService = AppUsageService(profileRepo: profileRepo);
      await appUsageService.init();

      final sensingService = PassiveSensingService(
        eventRepo: eventRepo,
        health: HealthService(),
        appUsage: appUsageService,
      );

      // Sync the last 2 days (Yesterday and Today) to ensure completeness.
      await sensingService.syncAll(days: 2);
      
      debugPrint('[WorkManager] Passive sync for yesterday and today completed successfully.');
      return Future.value(true);
    } catch (e) {
      debugPrint('[WorkManager] Passive sync failed: $e');
      return Future.value(false);
    }
  });
}

const kPassiveSyncTask = 'passive_sync';
