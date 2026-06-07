import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../services/profile_service.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_input_card.dart';
import '../widgets/metric_icon.dart';
import '../widgets/confetti_animation.dart';

/// Defines the two ways a check-in can be performed.
enum CheckinMode {
  /// A guided, sequential questionnaire (Interactive flow).
  guided,

  /// A quick-access grid for logging specific metrics manually.
  manual,
}

/// The "Guided" view — the daily check-in flow.
class DailyCheckinScreen extends StatefulWidget {
  final CheckinMode mode;
  final DateTime? targetTime;
  final String? fulfilledSlotId;
  final String? sessionId;

  /// How the session was initiated — [TriggerSource.manual] when opened
  /// from within the app, [TriggerSource.notification] when launched by
  /// tapping a push notification.
  final TriggerSource triggerSource;

  /// When the notification was displayed, for calculating prompt response delay.
  final DateTime? notificationDisplayedAt;

  const DailyCheckinScreen({
    super.key,
    this.mode = CheckinMode.guided,
    this.targetTime,
    this.fulfilledSlotId,
    this.sessionId,
    this.triggerSource = TriggerSource.manual,
    this.notificationDisplayedAt,
  });

  @override
  State<DailyCheckinScreen> createState() => _DailyCheckinScreenState();
}

class _DailyCheckinScreenState extends State<DailyCheckinScreen> {
  late final PageController _pageController;
  int _currentPage = 0;

  /// Holds the current session's answers, latencies, and custom occurrence times.
  /// Format: { metricId: (value, latencyMs, customTime) }
  final Map<String, (String, int, DateTime?)> _sessionData = {};

  /// Tracks when the current card became visible.
  DateTime _cardVisibleAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.9);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metricService = context.watch<MetricService>();

    DateTime currentTime = widget.targetTime ?? DateTime.now();
    bool isMissedWindow = widget.targetTime != null;

    if (widget.targetTime == null && widget.fulfilledSlotId != null) {
      final window = metricService.allWindows.where((w) => w.id == widget.fulfilledSlotId).firstOrNull;
      if (window != null && metricService.hasWindowPassed(DateTime.now(), window)) {
        final midHour = (window.startHour + window.endHour) ~/ 2;
        currentTime = DateTime.now().copyWith(hour: midHour, minute: 0);
        isMissedWindow = true;
      }
    }
    
    // Guided mode: only metrics assigned to the current time window.
    // Manual/Quick Log mode: ALL enabled metrics (including "Quick Log Only"
    // metrics that have no window assignments).
    final List<MetricDefinition> metrics;
    if (widget.mode == CheckinMode.manual) {
      metrics = metricService.allMetrics.where((m) => m.isEnabled).toList();
    } else {
      metrics = metricService.activeMetricsAt(currentTime);
    }
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.mode == CheckinMode.guided
            ? 'Daily Check-in'
            : 'Quick Log'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: metrics.isEmpty
            ? _buildEmptyState(colorScheme, textTheme)
            : widget.mode == CheckinMode.guided
                ? _buildGuidedFlow(metrics, colorScheme, textTheme, isMissedWindow, currentTime)
                : _buildManualGrid(metrics, colorScheme, textTheme, currentTime),
      ),
    );
  }

  /// The guided PageView flow.
  Widget _buildGuidedFlow(
    List<MetricDefinition> metrics,
    ColorScheme colorScheme,
    TextTheme textTheme,
    bool isMissedWindow,
    DateTime effectiveTargetTime,
  ) {
    final totalPages = metrics.length + 1;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: LinearProgressIndicator(
            value: (_currentPage + 1) / totalPages,
            borderRadius: BorderRadius.circular(4),
            minHeight: 8,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
          ),
        ),

        // Recall-reliability warning banner for missed-window mode.
        if (isMissedWindow)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.schedule_rounded,
                    size: 18, color: colorScheme.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Logging for a past window. Subjective ratings (mood, stress) may not be accurate.',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 8),

        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: totalPages,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
                _cardVisibleAt = DateTime.now();
              });
            },
            itemBuilder: (context, index) {
              if (index < metrics.length) {
                final metric = metrics[index];
                final showRecallWarning =
                    isMissedWindow && !metric.isRetrospectivelyReliable;
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 16.0,
                  ),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          if (showRecallWarning)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.warning_amber_rounded,
                                      size: 14,
                                      color: colorScheme.error),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Best-effort recall',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: colorScheme.error,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          MetricInputCard(
                            key: ValueKey(metric.id),
                            metric: metric,
                            initialValue: _sessionData[metric.id]?.$1,
                            onChanged: (value) {
                              final latency = DateTime.now()
                                  .difference(_cardVisibleAt)
                                  .inMilliseconds;
                              final customTime = _sessionData[metric.id]?.$3;

                              if (metric.inputType == MetricInputType.counter) {
                                _logCounterTap(metric, latency, customTime: customTime);
                                setState(() {
                                  _sessionData[metric.id] = ('1', latency, customTime);
                                });
                              } else {
                                setState(() {
                                  _sessionData[metric.id] = (value, latency, customTime);
                                });
                              }
                              // Auto-advance for all types
                              const shouldAutoAdvance = true;
                              if (shouldAutoAdvance && index < metrics.length) {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          _buildTimePickerButton(
                            metric.id, 
                            _sessionData[metric.id]?.$3 ?? effectiveTargetTime,
                            colorScheme,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return _CheckinReviewCard(
                  metrics: metrics,
                  sessionData: _sessionData,
                  onJumpToPage: (page) => _pageController.animateToPage(
                    page,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeInOut,
                  ),
                  onSubmit: () => _submitSession(metrics, effectiveTargetTime),
                );
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTimePickerButton(String metricId, DateTime currentTime, ColorScheme colorScheme) {
    final now = DateTime.now();
    final isToday = currentTime.year == now.year &&
                    currentTime.month == now.month &&
                    currentTime.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = currentTime.year == yesterday.year &&
                        currentTime.month == yesterday.month &&
                        currentTime.day == yesterday.day;

    final dateStr = isToday
        ? 'Today'
        : (isYesterday ? 'Yesterday' : DateFormat('MMM d').format(currentTime));
    final timeStr = "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}";
    final textTheme = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Happened at ',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        InkWell(
          onTap: () async {
            final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(currentTime),
            );
            if (time != null && mounted) {
              final newTime = DateTime(
                currentTime.year,
                currentTime.month,
                currentTime.day,
                time.hour,
                time.minute,
              );
              setState(() {
                final existing = _sessionData[metricId];
                _sessionData[metricId] = (existing?.$1 ?? '', existing?.$2 ?? 0, newTime);
              });
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              timeStr,
              style: textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
        ),
        Text(
          ' on ',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        InkWell(
          onTap: () async {
            final date = await showDatePicker(
              context: context,
              initialDate: currentTime,
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );
            if (date != null && mounted) {
              final newTime = DateTime(
                date.year,
                date.month,
                date.day,
                currentTime.hour,
                currentTime.minute,
              );
              setState(() {
                final existing = _sessionData[metricId];
                _sessionData[metricId] = (existing?.$1 ?? '', existing?.$2 ?? 0, newTime);
              });
            }
          },
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isToday ? colorScheme.surfaceContainerHighest : colorScheme.tertiaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isToday) ...[
                  Icon(Icons.calendar_today_rounded, size: 10, color: colorScheme.onTertiaryContainer),
                  const SizedBox(width: 4),
                ],
                Text(
                  dateStr,
                  style: textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: isToday ? colorScheme.onSurface : colorScheme.onTertiaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// The quick-access grid for manual logging.
  Widget _buildManualGrid(
    List<MetricDefinition> metrics,
    ColorScheme colorScheme,
    TextTheme textTheme,
    DateTime effectiveTargetTime,
  ) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.1,
      ),
      itemCount: metrics.length,
      itemBuilder: (context, index) {
        final metric = metrics[index];
        return InkWell(
          onTap: () async {
            if (metric.inputType == MetricInputType.counter) {
              final latency = DateTime.now().difference(_cardVisibleAt).inMilliseconds;
              await _logCounterTap(metric, latency, effectiveTargetTime: effectiveTargetTime);
            } else {
              await _showSingleMetricInput(metric, effectiveTargetTime);
            }
            if (mounted) {
              setState(() {
                _cardVisibleAt = DateTime.now();
              });
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Card(
            elevation: 0,
            color: colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: colorScheme.outlineVariant),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                MetricIcon(
                  iconName: metric.emoji,
                  size: 40,
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    metric.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (metric.inputType == MetricInputType.counter)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Tap to log',
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _logCounterTap(MetricDefinition metric, int latencyMs, {DateTime? customTime, DateTime? effectiveTargetTime}) async {
    try {
      final eventRepo = context.read<EventRepository>();
      final now = DateTime.now();
      await eventRepo.insertEvent(
        EventsCompanion(
          category: Value(metric.category),
          label: Value(metric.label),
          value: const Value('1'),
          latencyMs: Value(latencyMs),
          triggerSource: Value(widget.triggerSource),
          interactionType: const Value(InteractionType.click),
          timestamp: Value(customTime ?? effectiveTargetTime ?? widget.targetTime ?? now),
          recordedAt: Value(now),
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${metric.label} logged! ✓'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error logging counter tap: $e');
    }
  }

  Future<void> _showSingleMetricInput(MetricDefinition metric, DateTime effectiveTargetTime) async {
    final openedAt = DateTime.now();
    DateTime customTime = effectiveTargetTime;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final now = DateTime.now();
            final isToday = customTime.year == now.year &&
                            customTime.month == now.month &&
                            customTime.day == now.day;
            final yesterday = now.subtract(const Duration(days: 1));
            final isYesterday = customTime.year == yesterday.year &&
                                customTime.month == yesterday.month &&
                                customTime.day == yesterday.day;

            final dateStr = isToday
                ? 'Today'
                : (isYesterday ? 'Yesterday' : DateFormat('MMM d').format(customTime));
            final timeStr = "${customTime.hour.toString().padLeft(2, '0')}:${customTime.minute.toString().padLeft(2, '0')}";
            final colorScheme = Theme.of(context).colorScheme;
            final textTheme = Theme.of(context).textTheme;

            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: colorScheme.surface,
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
                        final eventRepo = context.read<EventRepository>();
                        final now = DateTime.now();
                        await eventRepo.insertEvent(
                          EventsCompanion(
                            category: Value(metric.category),
                            label: Value(metric.label),
                            value: Value(value),
                            latencyMs: Value(latency),
                            triggerSource: Value(widget.triggerSource),
                            interactionType: const Value(InteractionType.click),
                            timestamp: Value(customTime),
                            recordedAt: Value(now),
                          ),
                        );
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('${metric.label} logged!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        debugPrint('Error logging metric: $e');
                        if (context.mounted) Navigator.pop(context);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Happened at ',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      InkWell(
                        onTap: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(customTime),
                          );
                          if (time != null && context.mounted) {
                            setModalState(() {
                              customTime = DateTime(
                                customTime.year,
                                customTime.month,
                                customTime.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            timeStr,
                            style: textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        ' on ',
                        style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                      ),
                      InkWell(
                        onTap: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: customTime,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (date != null && context.mounted) {
                            setModalState(() {
                              customTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                customTime.hour,
                                customTime.minute,
                              );
                            });
                          }
                        },
                        borderRadius: BorderRadius.circular(6),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isToday ? colorScheme.surfaceContainerHighest : colorScheme.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (!isToday) ...[
                                Icon(Icons.calendar_today_rounded, size: 10, color: colorScheme.onTertiaryContainer),
                                const SizedBox(width: 4),
                              ],
                              Text(
                                dateStr,
                                style: textTheme.bodySmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isToday ? colorScheme.onSurface : colorScheme.onTertiaryContainer,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitSession(List<MetricDefinition> metrics, DateTime effectiveTargetTime) async {
    final eventRepo = context.read<EventRepository>();
    final metricService = context.read<MetricService>();
    final colorScheme = Theme.of(context).colorScheme;
    final sessionId = widget.sessionId ?? const Uuid().v4();

    int? notificationDelayMs;
    if (widget.notificationDisplayedAt != null) {
      notificationDelayMs = DateTime.now().difference(widget.notificationDisplayedAt!).inMilliseconds;
    }

    for (var metric in metrics) {
      if (metric.inputType == MetricInputType.counter) continue;

      final data = _sessionData[metric.id];
      if (data != null) {
        final now = DateTime.now();
        await eventRepo.insertEvent(
          EventsCompanion(
            category: Value(metric.category),
            label: Value(metric.label),
            value: Value(data.$1),
            latencyMs: Value(data.$2),
            notificationDelayMs: Value(notificationDelayMs),
            triggerSource: Value(widget.triggerSource),
            interactionType: const Value(InteractionType.click),
            timestamp: Value(data.$3 ?? effectiveTargetTime),
            recordedAt: Value(now),
            sessionId: Value(sessionId),
          ),
        );
      }
    }

    if (widget.mode == CheckinMode.guided) {
      String? windowId = widget.fulfilledSlotId;
      
      if (windowId == null) {
        final now = effectiveTargetTime;
        final currentWindows = metricService.allWindows.where((w) {
          final nowMinutes = now.hour * 60 + now.minute;
          final startMinutes = w.startHour * 60 + w.startMinute;
          final endMinutes = w.endHour * 60 + w.endMinute;
          if (startMinutes < endMinutes) {
            return nowMinutes >= startMinutes && nowMinutes < endMinutes;
          } else {
            return nowMinutes >= startMinutes || nowMinutes < endMinutes;
          }
        }).toList();
        
        if (currentWindows.isNotEmpty) {
          windowId = currentWindows.first.id;
        }
      }

      await eventRepo.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.meta),
          label: const Value('SessionCompleted'),
          value: Value(windowId ?? 'anytime'),
          timestamp: Value(effectiveTargetTime),
          triggerSource: const Value(TriggerSource.system),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(sessionId),
        ),
      );
    }

    if (mounted) {
      try {
        final profileService = Provider.of<ProfileService>(context, listen: false);
        if (profileService.hapticsEnabled) {
          HapticFeedback.mediumImpact();
        }
      } catch (_) {}
      ConfettiOverlay.of(context)?.celebrate();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'All metrics logged! 🎉',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: colorScheme.primary,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _buildEmptyState(ColorScheme colorScheme, TextTheme textTheme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle_outline_rounded,
              size: 80,
              color: colorScheme.primary.withAlpha(150),
            ),
            const SizedBox(height: 24),
            Text(
              'No active metrics',
              style: textTheme.headlineSmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Head to Settings to enable metrics\nyou want to track.',
              style: textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckinReviewCard extends StatelessWidget {
  final List<MetricDefinition> metrics;
  final Map<String, (String, int, DateTime?)> sessionData;
  final ValueChanged<int> onJumpToPage;
  final VoidCallback onSubmit;

  const _CheckinReviewCard({
    required this.metrics,
    required this.sessionData,
    required this.onJumpToPage,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          Expanded(
            child: Card(
              elevation: 0,
              color: colorScheme.surfaceContainerHighest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Review Session',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tap any item to make a quick fix.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: ListView.separated(
                        itemCount: metrics.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, indent: 48),
                        itemBuilder: (context, index) {
                          final metric = metrics[index];
                          final data = sessionData[metric.id];
                          final hasValue = data != null;

                          return ListTile(
                            onTap: () => onJumpToPage(index),
                            contentPadding: EdgeInsets.zero,
                            leading: MetricIcon(
                              iconName: metric.emoji,
                              size: 24,
                            ),
                            title: Text(
                              metric.label,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            trailing: hasValue
                                ? Text(
                                    _formatValue(data.$1, inputType: metric.inputType),
                                    style: TextStyle(
                                      color: colorScheme.primary,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : const Icon(Icons.warning_amber_rounded,
                                    color: Colors.orange),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 64,
            child: FilledButton(
              onPressed: onSubmit,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Finish & Submit',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(String value, {MetricInputType? inputType}) {
    if (inputType == MetricInputType.counter) return '+1';
    if (value == 'true') return 'Yes';
    if (value == 'false') return 'No';
    return value;
  }
}
