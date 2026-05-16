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
import 'activity_history_screen.dart';

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
  List<Event> _todayEvents = [];
  
  // Activity Overview
  List<int> _activityLevels = List.filled(14, 0);
  int _currentStreak = 0;
  int _totalLogs = 0;
  
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
    _waitForInitAndLoad();
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

  Future<void> _waitForInitAndLoad() async {
    final metricService = context.read<MetricService>();
    while (!metricService.isInitialized) {
      await Future.delayed(const Duration(milliseconds: 100));
      if (!mounted) return;
    }
    _loadTodayStats();
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

    final todayEvents = allEvents.where((e) => e.timestamp.isAfter(todayStart)).toList();

    final completedIds = todayEvents
        .where((e) => e.category == EventCategory.meta && e.label == 'SessionCompleted')
        .map((e) => e.value)
        .toSet();

    // Activity and Streak Computation
    final indicatorLabels = metricService.allMetrics
        .where((m) => m.isActivityIndicator)
        .map((m) => m.label)
        .toSet();

    final userEvents = allEvents.where((e) => 
        e.triggerSource != TriggerSource.system && 
        e.category != EventCategory.meta &&
        indicatorLabels.contains(e.label)
    ).toList();
    
    final activityLevels = List<int>.filled(14, 0);
    int currentStreak = 0;
    int totalLogs = userEvents.length;

    for (final e in userEvents) {
      final eventDay = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      final diff = todayStart.difference(eventDay).inDays;
      if (diff >= 0 && diff < 14) {
        activityLevels[13 - diff]++; // Index 13 is today
      }
    }

    for (int i = 0; i < 365; i++) {
      final d = todayStart.subtract(Duration(days: i));
      final hasActivity = userEvents.any((e) => 
          e.timestamp.year == d.year && 
          e.timestamp.month == d.month && 
          e.timestamp.day == d.day);
      
      if (hasActivity) {
        currentStreak++;
      } else if (i == 0) {
        // Allow today to have no activity yet without breaking the streak.
        continue;
      } else {
        break;
      }
    }

    if (mounted) {
      setState(() {
        _activeWindows = activeWindows;
        _completedWindowIds = completedIds;
        _todayEvents = todayEvents;
        _activityLevels = activityLevels;
        _currentStreak = currentStreak;
        _totalLogs = totalLogs;
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
    final metricService = context.read<MetricService>();
    final profileService = context.read<ProfileService>();
    final firstLaunch = profileService.firstLaunchAt;

    final missed = <TrackingWindow>[];

    for (var window in metricService.allWindows) {
      // Skip disabled windows — they shouldn't show missed cards.
      if (!window.isEnabled) continue;

      if (metricService.hasWindowPassed(now, window)) {
        final targetTime = metricService.getWindowTargetTime(now, window);

        // Don't show "missed" cards for windows that ended before the user
        // first launched the app. On the first day, windows that already
        // passed before setup shouldn't count as missed.
        if (firstLaunch != null) {
          final windowEndToday = DateTime(
            now.year, now.month, now.day,
            window.endHour, window.endMinute,
          );
          if (windowEndToday.isBefore(firstLaunch)) continue;
        }
        
        // Find if there's a completion/dismissal for THIS specific iteration of the window.
        // We match by checking if the meta event timestamp falls on the same date as the targetTime.
        final isCompleted = allEvents.any((e) => 
            e.category == EventCategory.meta &&
            (e.label == 'SessionCompleted' || e.label == 'SessionDismissed') &&
            e.value == window.id &&
            e.timestamp.year == targetTime.year &&
            e.timestamp.month == targetTime.month &&
            e.timestamp.day == targetTime.day
        );

        if (!isCompleted) {
          missed.add(window);
        }
      }
    }

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
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
                            );
                          },
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                            child: _buildActivityOverview(colorScheme, textTheme),
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
              const SizedBox(height: 32),

              _buildTrackingSuggestions(activeMetrics, colorScheme, textTheme),

              _buildTodayTimeline(colorScheme, textTheme),
              
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

  Widget _buildActivityOverview(ColorScheme colorScheme, TextTheme textTheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_fire_department_rounded, size: 16, color: Colors.orange.shade400),
            const SizedBox(width: 4),
            Text(
              '$_currentStreak Day Streak',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 16),
            Icon(Icons.data_usage_rounded, size: 16, color: colorScheme.primary),
            const SizedBox(width: 4),
            Text(
              '$_totalLogs Total Logs',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(14, (index) {
            final count = _activityLevels[index];
            final daysAgo = 13 - index;
            final date = DateTime.now().subtract(Duration(days: daysAgo));
            
            Color boxColor;
            Border? border;
            
            if (count == 0) {
              boxColor = colorScheme.surfaceContainerHighest.withAlpha(80);
              border = Border.all(color: colorScheme.outlineVariant.withAlpha(150), width: 1);
            } else if (count < 3) {
              boxColor = colorScheme.primary.withAlpha(100);
            } else if (count < 6) {
              boxColor = colorScheme.primary.withAlpha(180);
            } else {
              boxColor = colorScheme.primary;
            }
            
            return Tooltip(
              message: '${date.month}/${date.day}: $count logs',
              child: Container(
                margin: const EdgeInsets.only(right: 4),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: boxColor,
                  border: border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Last 14 Days Activity',
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant.withAlpha(150),
            fontSize: 10,
          ),
        ),
      ],
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

    // Compute exact target time (midpoint) of the missed window for backdated logging.
    final targetTime = metricService.getWindowTargetTime(DateTime.now(), window);

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

  Widget _buildTodayTimeline(ColorScheme colorScheme, TextTheme textTheme) {
    // Filter to manual / user-logged events
    final userEvents = _todayEvents.where((e) => e.triggerSource != TriggerSource.system && e.category != EventCategory.meta).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp)); // Newest first

    if (userEvents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          "Today's Timeline",
          style: textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(100),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              ...userEvents.take(5).map((e) {
                final timeStr = "${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}";
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        timeStr,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          e.label,
                          style: textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        e.value == '1' && e.label.toLowerCase().contains('coffee') ? '☕' : (e.value == 'true' ? 'Yes' : (e.value == 'false' ? 'No' : e.value)),
                        style: textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                );
              }),
              if (userEvents.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      '+${userEvents.length - 5} more (See Detailed Records)',
                      style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrackingSuggestions(List<MetricDefinition> activeMetrics, ColorScheme colorScheme, TextTheme textTheme) {
    final userEvents = _todayEvents.where((e) => e.triggerSource != TriggerSource.system && e.category != EventCategory.meta).toList();
    final trackedLabels = userEvents.map((e) => e.label).toSet();
    
    final untrackedMetrics = activeMetrics.where((m) => !trackedLabels.contains(m.label)).toList();

    if (untrackedMetrics.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.secondaryContainer.withAlpha(150),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Icon(Icons.star_rounded, color: colorScheme.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                "You're doing great! All active metrics have been tracked today.",
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Recommend the first untracked metric
    final recommendation = untrackedMetrics.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colorScheme.tertiary.withAlpha(100)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.tertiary.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.lightbulb_outline_rounded, color: colorScheme.tertiary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tracking Suggestion",
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.tertiary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "You haven't tracked '${recommendation.label}' today. Want to log it now?",
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
