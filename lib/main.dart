import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'data/database/app_database.dart';
import 'services/app_usage_service.dart';
import 'services/export_service.dart';
import 'services/metric_service.dart';
import 'services/health_service.dart';
import 'services/notification_service.dart';
import 'services/passive_sensing_service.dart';
import 'services/profile_service.dart';
import 'services/theme_service.dart';
import 'services/background_service.dart';
import 'services/analytics_service.dart';
import 'services/import_service.dart';
import 'ui/screens/app_shell.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/profile_setup_screen.dart';
import 'ui/screens/restore_selection_screen.dart';
import 'ui/theme/app_theme.dart';

// =============================================================================
// App Entry Point
// =============================================================================

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final database = AppDatabase.getInstance();

  final profileService = ProfileService();
  await profileService.init(database);

  final exportService = ExportService(
    db: database,
    profileService: profileService,
  );

  final metricService = MetricService();
  await metricService.init(database);

  final healthService = HealthService();
  final appUsageService = AppUsageService();
  await appUsageService.init();

  final passiveSensingService = PassiveSensingService(
    db: database,
    health: healthService,
    appUsage: appUsageService,
  );

  final notificationService = NotificationService();
  await notificationService.init();

  final themeService = ThemeService();
  await themeService.init();

  final analyticsService = AnalyticsService(database);
  final importService = ImportService(database, profileService);

  if (Platform.isAndroid) {
    await Workmanager().initialize(callbackDispatcher);

    await Workmanager().registerPeriodicTask(
      kPassiveSyncTask,
      kPassiveSyncTask,
      frequency: const Duration(hours: 2),
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      backoffPolicy: BackoffPolicy.exponential,
      backoffPolicyDelay: const Duration(minutes: 15),
    );

    debugPrint(
      '[Main] WorkManager periodic task registered: $kPassiveSyncTask',
    );
  } else {
    debugPrint('[Main] WorkManager skipped on non-Android platform.');
  }

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider<ProfileService>.value(value: profileService),
        Provider<ExportService>.value(value: exportService),
        ChangeNotifierProvider<MetricService>.value(value: metricService),
        Provider<PassiveSensingService>.value(value: passiveSensingService),
        Provider<HealthService>.value(value: healthService),
        ChangeNotifierProvider<AppUsageService>.value(value: appUsageService),
        Provider<NotificationService>.value(value: notificationService),
        ChangeNotifierProvider<ThemeService>.value(value: themeService),
        Provider<AnalyticsService>.value(value: analyticsService),
        Provider<ImportService>.value(value: importService),
      ],
      child: const CovaryApp(),
    ),
  );
}

// =============================================================================
// Root App Widget
// =============================================================================

class CovaryApp extends StatelessWidget {
  const CovaryApp({super.key});

  @override
  Widget build(BuildContext context) {
    final profileService = context.watch<ProfileService>();
    final themeService = context.watch<ThemeService>();

    return MaterialApp(
      navigatorKey: NotificationService.navigatorKey,
      title: 'Covary',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.buildTheme(
        context: context,
        isDark: false,
        primaryColor: themeService.primaryColor,
      ),
      darkTheme: AppTheme.buildTheme(
        context: context,
        isDark: true,
        primaryColor: themeService.primaryColor,
      ),
      themeMode: themeService.themeMode,
      home: profileService.hasRestoredData
          ? const RestoreSelectionScreen()
          : !profileService.hasSeenOnboarding
          ? const OnboardingScreen()
          : profileService.isFirstLaunch
          ? const ProfileSetupScreen()
          : const AppShell(),
    );
  }
}
