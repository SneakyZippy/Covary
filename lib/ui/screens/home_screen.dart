import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/app_usage_service.dart';
import '../../services/health_service.dart';
import '../../services/metric_service.dart';
import '../../services/profile_service.dart';
import '../widgets/missed_session_card.dart';
import '../widgets/quick_track_button.dart';
import 'daily_checkin_screen.dart';
import 'compliance_screen.dart';
import 'permission_shield_screen.dart';

/// The primary Home view.
///
/// Provides a welcoming overview and a clear call-to-action to
/// begin the daily tracking session, preventing survey fatigue on app open.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<TrackingWindow> _missedWindows = [];
  List<TrackingWindow> _activeWindows = [];
  Set<String> _completedWindowIds = {};
  
  // Permission Banner State
  bool _healthMissing = false;
  bool _usageMissing = false;
  bool _notificationsMissing = false;
  bool _bannerPermanentlyDismissed = false;

  Timer? _refreshTimer;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    // Refresh every minute to ensure window transitions are smooth
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadTodayStats();
    });

    // Also refresh whenever ANY event is added to the database.
    // This ensures that sessions finished via notifications or deep links
    // also trigger a refresh on the home screen immediately.
    final db = context.read<AppDatabase>();
    _eventSubscription = db.watchAllEvents().listen((_) {
      if (mounted) _loadTodayStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadTodayStats() async {
    if (!mounted) return;
    final db = context.read<AppDatabase>();
    final allEvents = await db.getAllEvents();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (!mounted) return;
    final metricService = context.read<MetricService>();
    
    // Find ALL active windows
    final activeWindows = metricService.allWindows
        .where((w) => metricService.isTimeInWindow(now, w))
        .toList();

    final completedIds = allEvents
        .where((e) =>
            e.timestamp.isAfter(todayStart) &&
            e.category == EventCategory.meta &&
            e.label == 'SessionCompleted')
        .map((e) => e.value)
        .toSet();

    if (mounted) {
      setState(() {
        _activeWindows = activeWindows;
        _completedWindowIds = completedIds;
      });
      _updateMissedSessions(allEvents);
      _checkPermissionsAndDismissal();
    }
  }

  Future<void> _checkPermissionsAndDismissal() async {
    final healthService = context.read<HealthService>();
    final appUsageService = context.read<AppUsageService>();
    final db = context.read<AppDatabase>();

    final healthGranted = await healthService.hasPermissions();
    final usageGranted = await appUsageService.isPermissionGranted();
    final notifGranted = await AwesomeNotifications().isNotificationAllowed();

    // Check if the banner has ever been dismissed
    final dismissEvents = await db.getEventsByLabel('PermissionBannerDismissed');
    final dismissed = dismissEvents.isNotEmpty;

    if (mounted) {
      setState(() {
        _healthMissing = !healthGranted;
        _usageMissing = !usageGranted;
        _notificationsMissing = !notifGranted;
        _bannerPermanentlyDismissed = dismissed;
      });
    }
  }

  void _updateMissedSessions(List<Event> allEvents) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final metricService = context.read<MetricService>();

    final windowsToCheck = <TrackingWindow>[];
    for (var window in metricService.allWindows) {
      if (metricService.hasWindowPassed(now, window)) {
        windowsToCheck.add(window);
      }
    }

    if (windowsToCheck.isEmpty) {
      if (mounted) setState(() => _missedWindows = []);
      return;
    }

    final completedWindows = allEvents
        .where((e) =>
            e.timestamp.isAfter(todayStart) &&
            e.category == EventCategory.meta &&
            (e.label == 'SessionCompleted' || e.label == 'SessionDismissed'))
        .map((e) => e.value)
        .toSet();

    final missed = windowsToCheck.where((w) => !completedWindows.contains(w.id)).toList();

    if (mounted) {
      setState(() {
        _missedWindows = missed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileService = context.watch<ProfileService>();
    final metricService = context.watch<MetricService>();

    final activeMetrics = metricService.activeMetrics;
    final quickMetrics = metricService.allMetrics
        .where((m) => m.isEnabled && m.windowIds.contains('homescreen'))
        .toList();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadTodayStats,
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 32.0,
            ),
            children: [
              if (!_bannerPermanentlyDismissed && (_healthMissing || _usageMissing || _notificationsMissing))
                Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: _buildPermissionBanner(colorScheme, textTheme),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _greeting(),
                          style: textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profileService.nickname.isNotEmpty
                              ? profileService.nickname
                              : 'Researcher',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              ..._activeWindows
                  .where((w) => !_completedWindowIds.contains(w.id))
                  .map((window) => Column(
                        children: [
                          _buildActiveWindowCard(window, colorScheme, textTheme),
                          const SizedBox(height: 24),
                        ],
                      )),

              if (_missedWindows.isNotEmpty) ...[
                ..._missedWindows.map((window) => _buildMissedSessionCard(window)),
                const SizedBox(height: 24),
              ],

              Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ComplianceScreen(),
                        ),
                      );
                    },
                    icon: Icon(Icons.verified_user_rounded, size: 16, color: colorScheme.primary),
                    label: Text(
                      'View Data Quality Metrics',
                      style: textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                    ),
                  ),
                ),
              ),
              
              _buildQuickActions(quickMetrics, colorScheme, textTheme),
              const SizedBox(height: 32),

              _buildActionRow(colorScheme, textTheme),
              
              if (activeMetrics.isEmpty && quickMetrics.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    'Head to Settings to enable metrics to track.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionBanner(ColorScheme colorScheme, TextTheme textTheme) {
    final missingCount = (_healthMissing ? 1 : 0) + (_usageMissing ? 1 : 0) + (_notificationsMissing ? 1 : 0);
    
    return Dismissible(
      key: const ValueKey('permission_banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) async {
        final db = context.read<AppDatabase>();
        await db.insertEvent(
          EventsCompanion(
            category: const Value(EventCategory.meta),
            label: const Value('PermissionBannerDismissed'),
            value: const Value(''),
            triggerSource: const Value(TriggerSource.system),
            interactionType: const Value(InteractionType.swipeAway),
          ),
        );
        setState(() => _bannerPermanentlyDismissed = true);
      },
      child: Card(
        elevation: 0,
        color: colorScheme.errorContainer.withAlpha(50),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: colorScheme.errorContainer, width: 1.5),
        ),
        child: InkWell(
          onTap: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PermissionShieldScreen()),
            );
            _checkPermissionsAndDismissal();
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colorScheme.error.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.security_rounded,
                    color: colorScheme.error,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Research Data Paused',
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      ),
                      Text(
                        'Missing $missingCount research permission${missingCount > 1 ? 's' : ''}. Tap to resolve.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: colorScheme.error.withAlpha(150),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMissedSessionCard(TrackingWindow window) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metricService = context.read<MetricService>();

    // Compute midpoint of the missed window for backdated logging.
    final midHour = (window.startHour + window.endHour) ~/ 2;
    final targetTime = DateTime.now().copyWith(hour: midHour, minute: 0);

    // Split metrics that belonged to this window by recall reliability.
    final windowMetrics = metricService.allMetrics.where((m) {
      if (!m.isEnabled) return false;
      return m.windowIds.contains(window.id);
    }).toList();

    final reliableMetrics =
        windowMetrics.where((m) => m.isRetrospectivelyReliable).toList();
    final subjectiveMetrics =
        windowMetrics.where((m) => !m.isRetrospectivelyReliable).toList();

    return MissedSessionCard(
      key: ValueKey('missed_${window.id}'),
      window: window,
      targetTime: targetTime,
      reliableMetrics: reliableMetrics,
      subjectiveMetrics: subjectiveMetrics,
      colorScheme: colorScheme,
      textTheme: textTheme,
      onDismissed: () async {
        final db = context.read<AppDatabase>();
        await db.insertEvent(
          EventsCompanion(
            category: const Value(EventCategory.meta),
            label: const Value('SessionDismissed'),
            value: Value(window.id),
            triggerSource: const Value(TriggerSource.system),
            interactionType: const Value(InteractionType.swipeAway),
          ),
        );
        _loadTodayStats();
      },
      onComplete: () => _startGuidedCheckin(window.id, targetTime),
      onMetricLogged: _loadTodayStats,
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
  }

  Widget _buildActiveWindowCard(TrackingWindow window, ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.primary.withAlpha(200),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(80),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _startGuidedCheckin(window.id),
          borderRadius: BorderRadius.circular(28),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getWindowIcon(window.label),
                        color: colorScheme.onPrimary,
                        size: 32,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${window.label} Check-in',
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: colorScheme.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (window.isNotificationEnabled)
                                Icon(
                                  Icons.notifications_active_rounded,
                                  color: colorScheme.onPrimary.withAlpha(180),
                                  size: 18,
                                ),
                            ],
                          ),
                          Text(
                            'Ready to track your progress?',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary.withAlpha(200),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _startGuidedCheckin(window.id),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.onPrimary,
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text(
                      'Start Now',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionRow(ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _startGuidedCheckin(),
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
            label: const Text('Check-in'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _startManualLog(),
            icon: const Icon(Icons.grid_view_rounded, size: 20),
            label: const Text('Quick Log'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: colorScheme.outline, width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getWindowIcon(String label) {
    final l = label.toLowerCase();
    if (l.contains('morning')) return Icons.wb_sunny_rounded;
    if (l.contains('evening') || l.contains('night')) return Icons.nights_stay_rounded;
    if (l.contains('afternoon')) return Icons.wb_twilight_rounded;
    return Icons.timer_rounded;
  }

  Future<void> _startGuidedCheckin([String? windowId, DateTime? targetTime]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyCheckinScreen(
          mode: CheckinMode.guided,
          fulfilledSlotId: windowId,
          targetTime: targetTime,
        ),
      ),
    );
    _loadTodayStats();
  }

  Future<void> _startManualLog() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const DailyCheckinScreen(
          mode: CheckinMode.manual,
        ),
      ),
    );
    _loadTodayStats();
  }

  Widget _buildQuickActions(
    List<MetricDefinition> quickMetrics,
    ColorScheme colorScheme,
    TextTheme textTheme,
  ) {
    if (quickMetrics.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Track',
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.5,
          ),
          itemCount: quickMetrics.length,
          itemBuilder: (context, index) {
            return QuickTrackButton(
              key: ValueKey(quickMetrics[index].id),
              metric: quickMetrics[index],
              onLogged: _loadTodayStats,
            );
          },
        ),
      ],
    );
  }
}
