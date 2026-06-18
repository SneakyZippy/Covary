import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../data/models/window_occurrence.dart';
import '../../data/repositories/event_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../services/app_usage_service.dart';
import '../../services/health_service.dart';
import '../../services/metric_service.dart';
import '../../services/profile_service.dart';
import '../widgets/metric_input_card.dart';
import '../widgets/quick_track_button.dart';
import 'daily_checkin_screen.dart';
import 'permission_shield_screen.dart';
import '../widgets/quick_track_value_sheet.dart';
import 'activity_history_screen.dart';
import '../../services/notification_service.dart';
import '../../services/pwa_push_interop.dart';
import '../widgets/staggered_entrance.dart';
import '../widgets/confetti_animation.dart';
import '../widgets/help_button.dart';

/// The primary Home view.
///
/// Provides a welcoming overview and a clear call-to-action to
/// begin the daily tracking session, preventing survey fatigue on app open.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<WindowOccurrence> _timelineOccurrences = [];
  List<Event> _allEvents = [];
  List<Event> _todayEvents = [];
  
  // Activity Overview
  List<int> _activityLevels = List.filled(14, 0);
  int _currentStreak = 0;
  int _totalLogs = 0;
  int _streakShields = 0;
  
  // Permission Banner State
  bool _healthMissing = false;
  bool _usageMissing = false;
  bool _notificationsMissing = false;
  bool _bannerPermanentlyDismissed = false;
  String? _expandedEventId;

  Timer? _refreshTimer;
  StreamSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _waitForInitAndLoad();
    // Refresh every minute to ensure window transitions are smooth
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadTodayStats();
    });

    // Also refresh whenever ANY event is added to the database.
    // This ensures that sessions finished via notifications or deep links
    // also trigger a refresh on the home screen immediately.
    final eventRepo = context.read<EventRepository>();
    _eventSubscription = eventRepo.watchAllEvents().listen((_) {
      if (mounted) _loadTodayStats();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refreshTimer?.cancel();
    _eventSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadTodayStats();
      // Try to schedule reminders if notifications are now granted.
      // This handles cases where they enabled them in Settings and returned.
      NotificationService.scheduleDailyReminders();
    }
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
    final eventRepo = context.read<EventRepository>();
    final allEvents = await eventRepo.getAllEvents();

    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    if (!mounted) return;
    final metricService = context.read<MetricService>();
    
    final todayEvents = allEvents.where((e) => e.timestamp.isAfter(todayStart)).toList();

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

    // Dynamic compliance calculations for shields
    final sessionEvents = allEvents.where((e) => 
      e.category == EventCategory.meta && 
      e.label == 'SessionCompleted'
    ).toList();

    final totalWindows = metricService.allWindows.where((w) => w.isEnabled).length;

    // 1. Calculate daily session completions
    final Map<DateTime, int> dailyCompletions = {};
    for (final e in sessionEvents) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      dailyCompletions[date] = (dailyCompletions[date] ?? 0) + 1;
    }

    // 2. Calculate daily user activity counts
    final Map<DateTime, int> dailyActivityCount = {};
    DateTime? earliest;
    for (final e in userEvents) {
      final date = DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day);
      dailyActivityCount[date] = (dailyActivityCount[date] ?? 0) + 1;
      if (earliest == null || date.isBefore(earliest)) {
        earliest = date;
      }
    }

    final earliestDate = earliest ?? todayStart;
    final earliestDateStart = DateTime(earliestDate.year, earliestDate.month, earliestDate.day);

    // 3. Chronological trace to calculate currentStreak and shields
    final totalDays = todayStart.difference(earliestDateStart).inDays + 1;
    
    currentStreak = 0;
    int streakShields = 0;
    int consecutivePerfectDays = 0;

    for (int i = 0; i < totalDays; i++) {
      final date = earliestDateStart.add(Duration(days: i));
      final hasActivity = (dailyActivityCount[date] ?? 0) > 0;
      final completed = dailyCompletions[date] ?? 0;
      final isPerfect = totalWindows > 0 && completed >= totalWindows;

      // Perfect days counting
      if (isPerfect) {
        consecutivePerfectDays++;
        if (consecutivePerfectDays % 3 == 0) {
          streakShields = (streakShields + 1).clamp(0, 2);
        }
      } else {
        if (date.isBefore(todayStart)) {
          consecutivePerfectDays = 0;
        }
      }

      // Streak & Shield consumption logic
      if (hasActivity) {
        currentStreak++;
      } else {
        if (date == todayStart) {
          continue; // Today doesn't break streak yet
        }
        if (streakShields > 0) {
          streakShields--;
          currentStreak++; // Shielded gap day
        } else {
          currentStreak = 0; // Streak broken
        }
      }
    }

    if (mounted) {
      setState(() {
        _allEvents = allEvents;
        _todayEvents = todayEvents;
        _activityLevels = activityLevels;
        _currentStreak = currentStreak;
        _totalLogs = totalLogs;
        _streakShields = streakShields;
      });
      _updateTimelineOccurrences(allEvents);
      _checkPermissionsAndDismissal();
    }
  }

  Future<void> _checkPermissionsAndDismissal() async {
    final healthService = context.read<HealthService>();
    final appUsageService = context.read<AppUsageService>();
    final eventRepo = context.read<EventRepository>();

    final healthGranted = kIsWeb ? true : await healthService.hasPermissions();
    final usageGranted = kIsWeb ? true : await appUsageService.isPermissionGranted();
    final notifGranted = kIsWeb
        ? PwaPushInterop.getPermissionStatus() == 'granted'
        : await AwesomeNotifications().isNotificationAllowed();

    // Check if the banner has ever been dismissed
    final dismissEvents = await eventRepo.getEventsByLabel('PermissionBannerDismissed');
    final dismissed = dismissEvents.isNotEmpty;

    if (mounted) {
      setState(() {
        _healthMissing = !healthGranted;
        _usageMissing = !usageGranted;
        _notificationsMissing = !notifGranted;
        _bannerPermanentlyDismissed = dismissed || _bannerPermanentlyDismissed;
      });
    }
  }

  void _updateTimelineOccurrences(List<Event> allEvents) {
    final now = DateTime.now();
    final metricService = context.read<MetricService>();
    final profileService = context.read<ProfileService>();
    final firstLaunch = profileService.firstLaunchAt;

    final occurrences = metricService.getTimelineOccurrences(now, allEvents);

    // Filter out occurrences that ended before the user first launched the app
    if (firstLaunch != null) {
      occurrences.removeWhere((occ) => occ.end.isBefore(firstLaunch));
    }

    if (mounted) {
      setState(() {
        _timelineOccurrences = occurrences;
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

    return ConfettiOverlay(
      child: Scaffold(
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            onRefresh: _loadTodayStats,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                24.0,
                32.0,
                24.0,
                100.0,
              ),
              children: [
                if (!_bannerPermanentlyDismissed && (_healthMissing || _usageMissing || _notificationsMissing))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24.0),
                    child: _buildPermissionBanner(colorScheme, textTheme),
                  ),
                StaggeredEntrance(
                  delay: Duration.zero,
                  child: Row(
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
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
                                  );
                                },
                                borderRadius: BorderRadius.circular(24),
                                child: _buildActivityOverview(colorScheme, textTheme),
                              ),
                            ),
                          ],
                        ),
                      ),
                      AppBarHelpButton(screenKey: 'home'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
  
                if (_timelineOccurrences.isNotEmpty)
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 150),
                    child: Column(
                      children: [
                        _buildDailyProgressTimeline(colorScheme, textTheme),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 200),
                  child: _buildQuickActions(quickMetrics, colorScheme, textTheme),
                ),
                const SizedBox(height: 32),
  
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 250),
                  child: _buildActionRow(colorScheme, textTheme),
                ),
                const SizedBox(height: 32),
  
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 300),
                  child: _buildTrackingSuggestions(activeMetrics, colorScheme, textTheme),
                ),
  
                StaggeredEntrance(
                  delay: const Duration(milliseconds: 350),
                  child: _buildTodayTimeline(colorScheme, textTheme),
                ),
                
                if (activeMetrics.isEmpty && quickMetrics.isEmpty)
                  StaggeredEntrance(
                    delay: const Duration(milliseconds: 400),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Text(
                        'Head to Settings to enable metrics to track.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.error,
                        ),
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

  Widget _buildActivityOverview(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withAlpha(70),
            colorScheme.surfaceContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StreakPulseIcon(icon: Icons.local_fire_department_rounded, size: 16, color: Colors.orange.shade400),
              const SizedBox(width: 4),
              Text(
                '$_currentStreak Day Streak',
                style: textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (_streakShields > 0) ...[
                const SizedBox(width: 12),
                Icon(Icons.shield_rounded, size: 16, color: Colors.teal.shade300),
                const SizedBox(width: 4),
                Text(
                  '$_streakShields Shield${_streakShields > 1 ? 's' : ''}',
                  style: textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Last 14 Days Activity',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                  fontSize: 10,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'View Achievements',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.primary.withAlpha(200),
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 10,
                    color: colorScheme.primary.withAlpha(200),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionBanner(ColorScheme colorScheme, TextTheme textTheme) {
    final missingCount = (_healthMissing ? 1 : 0) + (_usageMissing ? 1 : 0) + (_notificationsMissing ? 1 : 0);
    
    return Dismissible(
      key: const ValueKey('permission_banner'),
      direction: DismissDirection.horizontal,
      onDismissed: (_) async {
        setState(() => _bannerPermanentlyDismissed = true);
        final eventRepo = context.read<EventRepository>();
        await eventRepo.insertEvent(
          EventsCompanion(
            category: const Value(EventCategory.meta),
            label: const Value('PermissionBannerDismissed'),
            value: const Value(''),
            triggerSource: const Value(TriggerSource.system),
            interactionType: const Value(InteractionType.swipeAway),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              colorScheme.errorContainer.withAlpha(50),
              colorScheme.errorContainer.withAlpha(20),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: colorScheme.error.withAlpha(80),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(15),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PermissionShieldScreen()),
              );
              _checkPermissionsAndDismissal();
            },
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
      ),
    );
  }

  Widget _buildDailyProgressTimeline(ColorScheme colorScheme, TextTheme textTheme) {
    final completedCount = _timelineOccurrences.where((occ) {
      return _allEvents.any((e) =>
          e.category == EventCategory.meta &&
          e.label == 'SessionCompleted' &&
          e.value == occ.window.id &&
          (e.timestamp.isAfter(occ.start) || e.timestamp.isAtSameMomentAs(occ.start)) &&
          e.timestamp.isBefore(occ.end));
    }).length;

    final totalCount = _timelineOccurrences.length;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withAlpha(70),
            colorScheme.surfaceContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Progress',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              Text(
                '$completedCount of $totalCount Done',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(_timelineOccurrences.length, (index) {
            final occ = _timelineOccurrences[index];
            final isLast = index == _timelineOccurrences.length - 1;

            final isCompleted = _allEvents.any((e) =>
                e.category == EventCategory.meta &&
                e.label == 'SessionCompleted' &&
                e.value == occ.window.id &&
                (e.timestamp.isAfter(occ.start) || e.timestamp.isAtSameMomentAs(occ.start)) &&
                e.timestamp.isBefore(occ.end));

            final isDismissed = _allEvents.any((e) =>
                e.category == EventCategory.meta &&
                e.label == 'SessionDismissed' &&
                e.value == occ.window.id &&
                (e.timestamp.isAfter(occ.start) || e.timestamp.isAtSameMomentAs(occ.start)) &&
                e.timestamp.isBefore(occ.end));

            final now = DateTime.now();
            final isActive = !isCompleted && !isDismissed &&
                (now.isAfter(occ.start) || now.isAtSameMomentAs(occ.start)) &&
                now.isBefore(occ.end);

            final isMissed = !isCompleted && !isDismissed && now.isAfter(occ.end);
            final isUpcoming = now.isBefore(occ.start);

            final startStr = "${occ.window.startHour.toString().padLeft(2, '0')}:${occ.window.startMinute.toString().padLeft(2, '0')}";
            final endStr = "${occ.window.endHour.toString().padLeft(2, '0')}:${occ.window.endMinute.toString().padLeft(2, '0')}";

            String statusText = '';
            Color statusColor = colorScheme.onSurfaceVariant;
            Widget? actionWidget;

            if (isCompleted) {
              final completionEvent = _allEvents.where((e) =>
                  e.category == EventCategory.meta &&
                  e.label == 'SessionCompleted' &&
                  e.value == occ.window.id &&
                  (e.timestamp.isAfter(occ.start) || e.timestamp.isAtSameMomentAs(occ.start)) &&
                  e.timestamp.isBefore(occ.end)).firstOrNull;
              final timeToUse = completionEvent?.recordedAt ?? completionEvent?.timestamp ?? now;
              statusText = "Completed at ${timeToUse.hour.toString().padLeft(2, '0')}:${timeToUse.minute.toString().padLeft(2, '0')}";
              statusColor = colorScheme.primary;
            } else if (isDismissed) {
              statusText = "Dismissed";
              statusColor = colorScheme.error.withAlpha(150);
            } else if (isActive) {
              statusText = "Active now ($startStr - $endStr)";
              statusColor = colorScheme.primary;
              actionWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => _dismissWindowOccurrence(occ.window.id, occ.targetTime),
                    tooltip: 'Dismiss Check-in',
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: colorScheme.error.withAlpha(150),
                    ),
                  ),
                  const SizedBox(width: 4),
                  FilledButton.icon(
                    onPressed: () => _startGuidedCheckin(occ.window.id),
                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                    label: const Text('Log Now'),
                    style: FilledButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      backgroundColor: colorScheme.primary,
                      foregroundColor: colorScheme.onPrimary,
                    ),
                  ),
                ],
              );
            } else if (isMissed) {
              final todayStart = DateTime(now.year, now.month, now.day);
              final isYesterday = occ.start.isBefore(todayStart);
              if (isYesterday) {
                statusText = "Yesterday's missed window ($startStr - $endStr)";
              } else {
                statusText = "Missed window ($startStr - $endStr)";
              }
              statusColor = colorScheme.error.withAlpha(180);
              actionWidget = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () => _dismissWindowOccurrence(occ.window.id, occ.targetTime),
                    tooltip: 'Dismiss Check-in',
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      foregroundColor: colorScheme.error.withAlpha(150),
                    ),
                  ),
                  const SizedBox(width: 4),
                  OutlinedButton.icon(
                    onPressed: () => _startGuidedCheckin(occ.window.id, occ.targetTime),
                    icon: const Icon(Icons.history_rounded, size: 14),
                    label: const Text('Log Late'),
                    style: OutlinedButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(color: colorScheme.error.withAlpha(120)),
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ],
              );
            } else if (isUpcoming) {
              statusText = "Upcoming ($startStr - $endStr)";
              statusColor = colorScheme.onSurfaceVariant.withAlpha(120);
            }

            Widget nodeIcon;
            if (isCompleted) {
              nodeIcon = Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.primary.withAlpha(30),
                  border: Border.all(color: colorScheme.primary, width: 2),
                ),
                child: Icon(Icons.check, size: 12, color: colorScheme.primary),
              );
            } else if (isDismissed) {
              nodeIcon = Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.error.withAlpha(30),
                  border: Border.all(color: colorScheme.error.withAlpha(150), width: 2),
                ),
                child: Icon(Icons.close, size: 12, color: colorScheme.error.withAlpha(150)),
              );
            } else if (isActive) {
              nodeIcon = _TimelinePulseNode(color: colorScheme.primary);
            } else if (isMissed) {
              nodeIcon = Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.error.withAlpha(15),
                  border: Border.all(color: colorScheme.error.withAlpha(120), width: 2),
                ),
                child: Icon(Icons.access_time_rounded, size: 12, color: colorScheme.error.withAlpha(180)),
              );
            } else {
              nodeIcon = Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.transparent,
                  border: Border.all(color: colorScheme.outlineVariant.withAlpha(150), width: 2),
                ),
              );
            }

            Widget contentWidget;
            if (isActive) {
              contentWidget = Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.primary.withAlpha(25),
                      colorScheme.primary.withAlpha(5),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(60),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occ.window.label,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionWidget != null) ...[
                      const SizedBox(width: 8),
                      actionWidget,
                    ],
                  ],
                ),
              );
            } else {
              contentWidget = Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            occ.window.label,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isUpcoming ? colorScheme.onSurface.withAlpha(120) : colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusText,
                            style: textTheme.bodySmall?.copyWith(
                              color: statusColor,
                              fontWeight: isCompleted || isActive ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (actionWidget != null) ...[
                      const SizedBox(width: 8),
                      actionWidget,
                    ],
                  ],
                ),
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Column(
                    children: [
                      SizedBox(height: isActive ? 16 : 4),
                      nodeIcon,
                      if (!isLast)
                        Expanded(
                          child: Container(
                            width: 2,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: colorScheme.outlineVariant.withAlpha(80),
                          ),
                        )
                      else
                        const SizedBox(height: 24),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: contentWidget,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning 👋';
    if (hour < 17) return 'Good afternoon 👋';
    return 'Good evening 👋';
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

  Future<void> _dismissWindowOccurrence(String windowId, DateTime targetTime) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Dismiss Check-in?'),
        content: const Text(
          'This will hide this window from your timeline. You will not be able to log it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      try {
        final eventRepo = context.read<EventRepository>();
        await eventRepo.insertEvent(
          EventsCompanion(
            category: const Value(EventCategory.meta),
            label: const Value('SessionDismissed'),
            value: Value(windowId),
            triggerSource: const Value(TriggerSource.manual),
            interactionType: const Value(InteractionType.swipeAway),
            timestamp: Value(targetTime),
            recordedAt: Value(DateTime.now()),
          ),
        );
        _loadTodayStats();
      } catch (e) {
        debugPrint('Error dismissing window occurrence: $e');
      }
    }
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

    final visibleEvents = userEvents.take(5).toList();

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
            color: colorScheme.surfaceContainer.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.5)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              ...visibleEvents.asMap().entries.map((entry) {
                final idx = entry.key;
                final e = entry.value;
                final isLast = idx == visibleEvents.length - 1;
                final isExpanded = _expandedEventId == e.id;
                final timeStr = "${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}";
                final displayValue = e.value == '1' && e.label.toLowerCase().contains('coffee')
                    ? '☕'
                    : (e.value == 'true'
                        ? 'Yes'
                        : (e.value == 'false' ? 'No' : e.value));

                final catColor = _getCategoryColor(e.category, colorScheme);

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Node column
                    Column(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _expandedEventId = isExpanded ? null : e.id;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 16,
                            height: 16,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: catColor,
                              border: Border.all(
                                  color: isExpanded ? Colors.white : Colors.transparent,
                                  width: 1.5,
                                ),
                              boxShadow: [
                                BoxShadow(
                                  color: catColor.withValues(alpha: 0.4),
                                  blurRadius: isExpanded ? 8 : 4,
                                  spreadRadius: isExpanded ? 2 : 0,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (!isLast)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 2,
                            height: isExpanded ? 115 : 24,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: colorScheme.outlineVariant.withValues(alpha: 0.3),
                          )
                        else
                          const SizedBox(height: 24),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Details column
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              setState(() {
                                _expandedEventId = isExpanded ? null : e.id;
                              });
                            },
                            child: Row(
                              children: [
                                Text(
                                  timeStr,
                                  style: textTheme.bodySmall?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    e.label,
                                    style: textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  displayValue,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: catColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          AnimatedCrossFade(
                            firstChild: const SizedBox.shrink(),
                            secondChild: Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(top: 8, bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildTimelineDetailRow('Category', e.category.name.toUpperCase(), colorScheme, textTheme),
                                  const SizedBox(height: 4),
                                  _buildTimelineDetailRow('Source', e.triggerSource.name.toUpperCase(), colorScheme, textTheme),
                                  if (e.latencyMs > 0) ...[
                                    const SizedBox(height: 4),
                                    _buildTimelineDetailRow('Latency', '${(e.latencyMs / 1000).toStringAsFixed(1)}s', colorScheme, textTheme),
                                  ],
                                ],
                              ),
                            ),
                            crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                            duration: const Duration(milliseconds: 200),
                          ),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ],
                );
              }),
              if (userEvents.length > 5)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Center(
                    child: Text(
                      '+${userEvents.length - 5} more',
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

  Widget _buildTimelineDetailRow(String label, String value, ColorScheme colorScheme, TextTheme textTheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 10,
          ),
        ),
        Text(
          value,
          style: textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Color _getCategoryColor(EventCategory category, ColorScheme colorScheme) {
    switch (category) {
      case EventCategory.mood:
        return colorScheme.primary;
      case EventCategory.behavior:
        return colorScheme.secondary;
      case EventCategory.health:
        return const Color(0xFFC71585); // Ruby
      case EventCategory.productivity:
        return colorScheme.tertiary;
      case EventCategory.social:
        return const Color(0xFF007FFF); // Azure
      case EventCategory.nutrition:
        return const Color(0xFFFF7F50); // Coral
      default:
        return colorScheme.onSurfaceVariant;
    }
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

    return Material(
      color: colorScheme.tertiaryContainer.withAlpha(150),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () => _handleSuggestionTap(recommendation),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
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
        ),
      ),
    );
  }

  Future<void> _handleSuggestionTap(MetricDefinition metric) async {
    if (metric.inputType == MetricInputType.counter) {
      _showSuggestionCounterSheet(context, metric);
    } else {
      _showSuggestionInputModal(context, metric);
    }
  }

  void _showSuggestionCounterSheet(BuildContext context, MetricDefinition metric) {
    final profileRepo = context.read<ProfileRepository>();
    final config = getCounterConfig(metric.id);
    final savedValStr = profileRepo.getStringSetting('quick_track_default_value_${metric.id}');
    final defaultValue = savedValStr != null
        ? (double.tryParse(savedValStr) ?? config.fallbackDefault)
        : config.fallbackDefault;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickTrackValueSheet(
        metric: metric,
        initialValue: defaultValue,
        unit: config.unit,
        step: config.step,
        min: config.min,
        max: config.max,
        onConfirm: (value, time, saveAsDefault) async {
          if (saveAsDefault) {
            await profileRepo.setStringSetting('quick_track_default_value_${metric.id}', value.toString());
          }
          if (context.mounted) {
            try {
              final eventRepo = context.read<EventRepository>();
              final eventId = const Uuid().v4();
              final now = DateTime.now();
              
              final valueStr = value == value.toInt()
                  ? value.toInt().toString()
                  : value.toString();

              await eventRepo.insertEvent(
                EventsCompanion(
                  id: Value(eventId),
                  category: Value(metric.category),
                  label: Value(metric.label),
                  value: Value(valueStr),
                  latencyMs: const Value(0),
                  triggerSource: const Value(TriggerSource.manual),
                  interactionType: const Value(InteractionType.click),
                  timestamp: Value(time),
                  recordedAt: Value(now),
                ),
              );
              
              if (context.mounted) {
                _loadTodayStats();
                
                // Trigger confetti burst overlay from center of screen
                final size = MediaQuery.of(context).size;
                ConfettiOverlay.of(context)?.burst(Offset(size.width / 2, size.height / 2));
                
                ScaffoldMessenger.of(context).clearSnackBars();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Row(
                      children: [
                        Expanded(child: Text('${metric.label} logged! ✓')),
                        TextButton(
                          onPressed: () async {
                            await eventRepo.deleteEvent(eventId);
                            if (context.mounted) {
                              _loadTodayStats();
                              ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            }
                          },
                          child: Text('UNDO', style: TextStyle(color: Theme.of(context).colorScheme.inversePrimary)),
                        ),
                      ],
                    ),
                    behavior: SnackBarBehavior.floating,
                    duration: const Duration(seconds: 5),
                  ),
                );
              }
            } catch (e) {
              debugPrint('Error logging suggestion counter: $e');
            }
          }
        },
      ),
    );
  }

  void _showSuggestionInputModal(BuildContext context, MetricDefinition metric) {
    final openedAt = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          top: 24,
          left: 24,
          right: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MetricInputCard(
              metric: metric,
              onChanged: (value) async {
                try {
                  final latency = DateTime.now()
                      .difference(openedAt)
                      .inMilliseconds;
                  final eventRepo = context.read<EventRepository>();
                  final eventId = const Uuid().v4();
                  final now = DateTime.now();
                  await eventRepo.insertEvent(
                    EventsCompanion(
                      id: Value(eventId),
                      category: Value(metric.category),
                      label: Value(metric.label),
                      value: Value(value),
                      latencyMs: Value(latency),
                      triggerSource: const Value(TriggerSource.manual),
                      interactionType: const Value(InteractionType.click),
                      timestamp: Value(now),
                      recordedAt: Value(now),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    _loadTodayStats();
                    ScaffoldMessenger.of(ctx).clearSnackBars();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Expanded(child: Text('${metric.label} logged!')),
                            TextButton(
                              onPressed: () async {
                                await eventRepo.deleteEvent(eventId);
                                if (ctx.mounted) {
                                  _loadTodayStats();
                                  ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
                                }
                              },
                              child: Text('UNDO', style: TextStyle(color: Theme.of(ctx).colorScheme.inversePrimary)),
                            ),
                          ],
                        ),
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error logging metric suggestion: $e');
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Helper Widgets
// =============================================================================

class _StreakPulseIcon extends StatefulWidget {
  final IconData icon;
  final Color color;
  final double size;

  const _StreakPulseIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  @override
  State<_StreakPulseIcon> createState() => _StreakPulseIconState();
}

class _StreakPulseIconState extends State<_StreakPulseIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.16); // gentle 16% pulse
        return Transform.scale(
          scale: scale,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        );
      },
    );
  }
}

class _TimelinePulseNode extends StatefulWidget {
  final Color color;

  const _TimelinePulseNode({required this.color});

  @override
  State<_TimelinePulseNode> createState() => _TimelinePulseNodeState();
}

class _TimelinePulseNodeState extends State<_TimelinePulseNode>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 20,
      height: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned(
                child: Container(
                  width: 20 + (12 * _controller.value),
                  height: 20 + (12 * _controller.value),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withAlpha((40 * (1.0 - _controller.value)).toInt()),
                  ),
                ),
              ),
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withAlpha(40),
                  border: Border.all(color: widget.color, width: 2),
                ),
                child: Icon(Icons.play_arrow_rounded, size: 12, color: widget.color),
              ),
            ],
          );
        },
      ),
    );
  }
}
