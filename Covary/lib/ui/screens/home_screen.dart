import 'dart:async';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/metric_service.dart';
import '../../services/profile_service.dart';
import '../widgets/metric_icon.dart';
import '../widgets/metric_input_card.dart';
import 'daily_checkin_screen.dart';

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
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadTodayStats();
    // Refresh every minute to ensure window transitions are smooth
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadTodayStats();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
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

              const SizedBox(height: 8),

              const SizedBox(height: 8),
              const SizedBox(height: 24),

              const SizedBox(height: 8),
              const SizedBox(height: 24),
              
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

    return _MissedSessionCard(
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
      onComplete: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => DailyCheckinScreen(
              mode: CheckinMode.guided,
              targetTime: targetTime,
              fulfilledSlotId: window.id,
            ),
          ),
        );
      },
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
                          Text(
                            '${window.label} Check-in',
                            style: textTheme.headlineSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.bold,
                            ),
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

  Future<void> _startGuidedCheckin([String? windowId]) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DailyCheckinScreen(
          mode: CheckinMode.guided,
          fulfilledSlotId: windowId,
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
            return _QuickTrackButton(
              metric: quickMetrics[index],
              onLogged: _loadTodayStats,
            );
          },
        ),
      ],
    );
  }
}

class _QuickTrackButton extends StatelessWidget {
  final MetricDefinition metric;
  final VoidCallback onLogged;

  const _QuickTrackButton({
    required this.metric,
    required this.onLogged,
  });

  Future<void> _handleTap(BuildContext context) async {
    if (metric.inputType == MetricInputType.counter) {
      try {
        final db = context.read<AppDatabase>();
        await db.insertEvent(
          EventsCompanion(
            category: Value(metric.category),
            label: Value(metric.label),
            value: const Value('1'),
            latencyMs: const Value(0),
            triggerSource: const Value(TriggerSource.manual),
            interactionType: const Value(InteractionType.click),
            timestamp: Value(DateTime.now()),
          ),
        );
        if (context.mounted) {
          onLogged();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${metric.label} logged! ✓'),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        debugPrint('Error logging quick track: $e');
      }
    } else {
      _showInputModal(context);
    }
  }

  void _showInputModal(BuildContext context) {
    final openedAt = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
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
                  final latency = DateTime.now().difference(openedAt).inMilliseconds;
                  final db = ctx.read<AppDatabase>();
                  await db.insertEvent(
                    EventsCompanion(
                      category: Value(metric.category),
                      label: Value(metric.label),
                      value: Value(value),
                      latencyMs: Value(latency),
                      triggerSource: const Value(TriggerSource.manual),
                      interactionType: const Value(InteractionType.click),
                      timestamp: Value(DateTime.now()),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    onLogged();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text('${metric.label} logged!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } catch (e) {
                  debugPrint('Error logging metric: $e');
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

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return StreamBuilder<int>(
      stream: db.watchTodayCountForLabel(metric.label),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;

        return Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            onTap: () => _handleTap(context),
            borderRadius: BorderRadius.circular(20),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  MetricIcon(
                    iconName: metric.emoji,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          metric.label,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Today: $count',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
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
      },
    );
  }
}

// =============================================================================
// Missed Session Card
// =============================================================================

/// Displays a missed check-in window with metric chips split by recall
/// reliability. Reliable (factual) metrics are tappable; subjective (scale)
/// metrics are dimmed with a "Log anyway" escape hatch.
class _MissedSessionCard extends StatefulWidget {
  final TrackingWindow window;
  final DateTime targetTime;
  final List<MetricDefinition> reliableMetrics;
  final List<MetricDefinition> subjectiveMetrics;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onDismissed;
  final VoidCallback onComplete;
  final VoidCallback onMetricLogged;

  const _MissedSessionCard({
    super.key,
    required this.window,
    required this.targetTime,
    required this.reliableMetrics,
    required this.subjectiveMetrics,
    required this.colorScheme,
    required this.textTheme,
    required this.onDismissed,
    required this.onComplete,
    required this.onMetricLogged,
  });

  @override
  State<_MissedSessionCard> createState() => _MissedSessionCardState();
}

class _MissedSessionCardState extends State<_MissedSessionCard> {
  /// Whether the user has chosen to log despite the recall warning.
  bool _showSubjectiveAnyway = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final tt = widget.textTheme;

    return Dismissible(
      key: ValueKey('missed_dismiss_${widget.window.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (_) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Skip Check-in?'),
            content: const Text(
                'Do you really want to leave out this check-in?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  foregroundColor: cs.onError,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Skip'),
              ),
            ],
          ),
        ) ??
            false;
      },
      background: _dismissBackground(cs, Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 24)),
      secondaryBackground: _dismissBackground(cs, Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24)),
      onDismissed: (_) => widget.onDismissed(),
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: cs.errorContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ────────────────────────────────────────────────
              Row(
                children: [
                  Icon(Icons.history_rounded, color: cs.error, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Missed ${widget.window.label} Check-in',
                      style: tt.titleSmall?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: widget.onComplete,
                    icon: const Icon(Icons.open_in_new_rounded, size: 14),
                    label: const Text('Complete'),
                    style: TextButton.styleFrom(
                      foregroundColor: cs.error,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ],
              ),

              // ── Reliable metrics ───────────────────────────────────────
              if (widget.reliableMetrics.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 14, color: cs.error),
                    const SizedBox(width: 4),
                    Text(
                      'Still accurate — log now',
                      style: tt.labelSmall?.copyWith(
                        color: cs.onErrorContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.reliableMetrics
                      .map((m) => _MetricChip(
                            metric: m,
                            targetTime: widget.targetTime,
                            dimmed: false,
                            onLogged: widget.onMetricLogged,
                          ))
                      .toList(),
                ),
              ],

              // ── Subjective metrics ─────────────────────────────────────
              if (widget.subjectiveMetrics.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded,
                        size: 14, color: cs.error),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Recall may be unreliable',
                        style: tt.labelSmall?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!_showSubjectiveAnyway)
                      GestureDetector(
                        onTap: () =>
                            setState(() => _showSubjectiveAnyway = true),
                        child: Text(
                          'Log anyway',
                          style: tt.labelSmall?.copyWith(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: widget.subjectiveMetrics
                      .map((m) => _MetricChip(
                            metric: m,
                            targetTime: widget.targetTime,
                            dimmed: !_showSubjectiveAnyway,
                            isSubjectiveOverride: _showSubjectiveAnyway,
                            onLogged: widget.onMetricLogged,
                          ))
                      .toList(),
                ),
              ],

              if (widget.reliableMetrics.isEmpty &&
                  widget.subjectiveMetrics.isEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'No metrics assigned to this window.',
                  style: tt.bodySmall
                      ?.copyWith(color: cs.onErrorContainer),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _dismissBackground(
    ColorScheme cs,
    Alignment alignment, {
    required EdgeInsets padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cs.error,
        borderRadius: BorderRadius.circular(16),
      ),
      alignment: alignment,
      padding: padding,
      child: Icon(Icons.delete_sweep_rounded, color: cs.onError),
    );
  }
}

// =============================================================================
// Metric Chip (for missed card)
// =============================================================================

/// A tappable chip representing one metric in the missed-session card.
/// When [dimmed] is true the chip is shown at reduced opacity and is
/// non-interactive (used for subjective metrics before "Log anyway").
class _MetricChip extends StatelessWidget {
  final MetricDefinition metric;
  final DateTime targetTime;
  final bool dimmed;
  final bool isSubjectiveOverride;
  final VoidCallback onLogged;

  const _MetricChip({
    required this.metric,
    required this.targetTime,
    required this.dimmed,
    required this.onLogged,
    this.isSubjectiveOverride = false,
  });

  void _onTap(BuildContext context) {
    if (dimmed) return;
    _showRetroLogSheet(context);
  }

  /// Opens a bottom sheet for quick retro-logging of this metric.
  void _showRetroLogSheet(BuildContext context) {
    final openedAt = DateTime.now();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: Theme.of(ctx).colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isSubjectiveOverride)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: 16,
                          color: Theme.of(ctx).colorScheme.error),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Best-effort recall — subjective data logged retroactively.',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              MetricInputCard(
                metric: metric,
                onChanged: (value) async {
                  try {
                    final latency =
                        DateTime.now().difference(openedAt).inMilliseconds;
                    final db = ctx.read<AppDatabase>();

                    // Log the metric event with the backdated target time.
                    await db.insertEvent(
                      EventsCompanion(
                        category: Value(metric.category),
                        label: Value(metric.label),
                        value: Value(value),
                        latencyMs: Value(latency),
                        triggerSource: const Value(TriggerSource.manual),
                        interactionType: const Value(InteractionType.click),
                        timestamp: Value(targetTime),
                      ),
                    );

                    // Log a meta event if the user overrode the subjective warning.
                    if (isSubjectiveOverride) {
                      await db.insertEvent(
                        EventsCompanion(
                          category: const Value(EventCategory.meta),
                          label: const Value('SubjectiveRetroOverride'),
                          value: Value(metric.id),
                          triggerSource: const Value(TriggerSource.manual),
                          interactionType: const Value(InteractionType.click),
                        ),
                      );
                    }

                    if (ctx.mounted) {
                      Navigator.pop(ctx);
                      onLogged();
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        SnackBar(
                          content: Text('${metric.label} logged!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    debugPrint('[MissedCard] Error logging metric: $e');
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final chip = InkWell(
      onTap: dimmed ? null : () => _onTap(context),
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: colorScheme.error.withAlpha(dimmed ? 20 : 40),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: colorScheme.error.withAlpha(dimmed ? 40 : 100),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            MetricIcon(iconName: metric.emoji, size: 16),
            const SizedBox(width: 6),
            Text(
              metric.label,
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onErrorContainer
                    .withAlpha(dimmed ? 120 : 220),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return dimmed ? Opacity(opacity: 0.55, child: chip) : chip;
  }
}
