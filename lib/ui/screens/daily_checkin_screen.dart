import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../services/metric_service.dart';
import '../widgets/metric_input_card.dart';
import '../widgets/metric_icon.dart';

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

  const DailyCheckinScreen({
    super.key,
    this.mode = CheckinMode.guided,
    this.targetTime,
    this.fulfilledSlotId,
    this.sessionId,
    this.triggerSource = TriggerSource.manual,
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
    final timeStr = "${currentTime.hour.toString().padLeft(2, '0')}:${currentTime.minute.toString().padLeft(2, '0')}";
    return TextButton.icon(
      onPressed: () async {
        final time = await showTimePicker(
          context: context,
          initialTime: TimeOfDay.fromDateTime(currentTime),
        );
        if (time != null && mounted) {
          final now = DateTime.now();
          var newTime = DateTime(
            now.year, now.month, now.day, time.hour, time.minute,
          );
          if (newTime.isAfter(now)) {
            newTime = newTime.subtract(const Duration(days: 1));
          }
          setState(() {
            final existing = _sessionData[metricId];
            _sessionData[metricId] = (existing?.$1 ?? '', existing?.$2 ?? 0, newTime);
          });
        }
      },
      icon: Icon(Icons.access_time_rounded, size: 16, color: colorScheme.onSurfaceVariant),
      label: Text(
        'Happened at $timeStr',
        style: TextStyle(color: colorScheme.onSurfaceVariant),
      ),
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
          onTap: () {
            if (metric.inputType == MetricInputType.counter) {
              final latency = DateTime.now().difference(_cardVisibleAt).inMilliseconds;
              _logCounterTap(metric, latency, effectiveTargetTime: effectiveTargetTime);
            } else {
              _showSingleMetricInput(metric, effectiveTargetTime);
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
      final db = context.read<AppDatabase>();
      final now = DateTime.now();
      await db.insertEvent(
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

  void _showSingleMetricInput(MetricDefinition metric, DateTime effectiveTargetTime) {
    final openedAt = DateTime.now();
    DateTime customTime = effectiveTargetTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final timeStr = "${customTime.hour.toString().padLeft(2, '0')}:${customTime.minute.toString().padLeft(2, '0')}";
            
            return Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
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
                        final db = context.read<AppDatabase>();
                        final now = DateTime.now();
                        await db.insertEvent(
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
            TextButton.icon(
              onPressed: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(customTime),
                );
                if (time != null && context.mounted) {
                  setModalState(() {
                    final now = DateTime.now();
                    customTime = DateTime(
                      now.year, now.month, now.day, time.hour, time.minute,
                    );
                    if (customTime.isAfter(now)) {
                      customTime = customTime.subtract(const Duration(days: 1));
                    }
                  });
                }
              },
              icon: Icon(Icons.access_time_rounded, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
              label: Text(
                'Happened at $timeStr',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
              ),
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
    final db = context.read<AppDatabase>();
    final metricService = context.read<MetricService>();
    final colorScheme = Theme.of(context).colorScheme;
    final sessionId = widget.sessionId ?? const Uuid().v4();

    for (var metric in metrics) {
      if (metric.inputType == MetricInputType.counter) continue;

      final data = _sessionData[metric.id];
      if (data != null) {
        final now = DateTime.now();
        await db.insertEvent(
          EventsCompanion(
            category: Value(metric.category),
            label: Value(metric.label),
            value: Value(data.$1),
            latencyMs: Value(data.$2),
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

      await db.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.meta),
          label: const Value('SessionCompleted'),
          value: Value(windowId ?? 'anytime'),
          triggerSource: const Value(TriggerSource.system),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(sessionId),
        ),
      );
    }

    if (mounted) {
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
