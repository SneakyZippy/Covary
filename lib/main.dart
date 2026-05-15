import 'dart:async' show unawaited;
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:workmanager/workmanager.dart';
import 'data/database/app_database.dart';
import 'data/models/enums.dart';
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

  // ── Global Error Handlers ───────────────────────────────────────────────
  // Capture uncaught errors as meta events so crash data appears in exports.
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details); // keep default red-screen in debug
    _logCrash(database, details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _logCrash(database, error.toString(), stack);
    return true; // prevent app termination
  };

  // ── FAST INIT (prefs-only, no DB queries) ──────────────────────────────
  // These two are the only things blocking the first frame.
  final profileService = ProfileService();
  final themeService = ThemeService();
  await Future.wait([
    profileService.initFast(database),
    themeService.init(),
  ]);

  // ── Create services (constructors only, no heavy init) ─────────────────
  final metricService = MetricService();
  final healthService = HealthService();
  final appUsageService = AppUsageService();
  final passiveSensingService = PassiveSensingService(
    db: database,
    health: healthService,
    appUsage: appUsageService,
  );
  final notificationService = NotificationService();
  final exportService = ExportService(
    db: database,
    profileService: profileService,
  );
  final analyticsService = AnalyticsService(database);
  final importService = ImportService(database, profileService);

  // ── SHOW THE UI IMMEDIATELY ────────────────────────────────────────────
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

  // ── DEFERRED INIT (runs after the first frame is painted) ──────────────
  // These are heavy operations (DB queries, platform channels, scheduling)
  // that the UI doesn't need to be visible.
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    // Phase 1: MetricService + ProfileService DB work (parallel)
    await Future.wait([
      metricService.init(database),
      profileService.initDeferred(),
    ]);

    // Phase 2: Notifications + app usage + WorkManager (parallel, non-blocking)
    unawaited(Future.wait([
      notificationService.init(),
      appUsageService.init(),
      _initWorkManager(),
    ]));
  });
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

// =============================================================================
// Crash Logger
// =============================================================================

/// Writes an uncaught error into the Events table so it appears in JSON exports.
/// Truncates the stack to avoid bloating the database.
void _logCrash(AppDatabase db, String error, StackTrace? stack) {
  try {
    final trace = stack?.toString().split('\n').take(5).join('\n') ?? '';
    db.insertEvent(EventsCompanion(
      category: const Value(EventCategory.meta),
      label: const Value('app_crash'),
      value: Value('$error\n$trace'),
      triggerSource: const Value(TriggerSource.system),
      interactionType: const Value(InteractionType.click),
    ));
  } catch (_) {
    // If the DB itself is failing, there's nothing more we can do.
  }
}

// =============================================================================
// WorkManager Setup
// =============================================================================

/// Initializes WorkManager and registers the periodic passive sync task.
/// Extracted so it can run as part of deferred init.
Future<void> _initWorkManager() async {
  if (!Platform.isAndroid) {
    debugPrint('[Main] WorkManager skipped on non-Android platform.');
    return;
  }
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
  debugPrint('[Main] WorkManager periodic task registered: $kPassiveSyncTask');
}
