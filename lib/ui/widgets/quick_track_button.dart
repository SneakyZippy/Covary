import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import '../../data/database/tables/table_utils.dart';
import '../../data/repositories/profile_repository.dart';
import 'metric_input_card.dart';
import 'metric_icon.dart';
import 'quick_track_value_sheet.dart';
import 'confetti_animation.dart';

// =============================================================================
// Counter Metric Configurations
// =============================================================================

class CounterMetricConfig {
  final String unit;
  final double step;
  final double min;
  final double max;
  final double fallbackDefault;

  const CounterMetricConfig({
    required this.unit,
    required this.step,
    required this.min,
    required this.max,
    required this.fallbackDefault,
  });
}

const Map<String, CounterMetricConfig> _counterConfigs = {
  'core_screen_mindless': CounterMetricConfig(
    unit: 'min',
    step: 5.0,
    min: 5.0,
    max: 120.0,
    fallbackDefault: 10.0,
  ),
  'core_water_intake': CounterMetricConfig(
    unit: 'ml',
    step: 50,
    min: 50,
    max: 1000,
    fallbackDefault: 250,
  ),
  'core_coffee_intake': CounterMetricConfig(
    unit: 'cups',
    step: 0.5,
    min: 0.5,
    max: 4.0,
    fallbackDefault: 1.0,
  ),
  'core_alcohol_intake': CounterMetricConfig(
    unit: 'drinks',
    step: 1.0,
    min: 1.0,
    max: 8.0,
    fallbackDefault: 1.0,
  ),
  'core_meal_count': CounterMetricConfig(
    unit: 'meals',
    step: 1.0,
    min: 1.0,
    max: 3.0,
    fallbackDefault: 2.0, // Default to a standard Meal
  ),
  'core_toilet_urge': CounterMetricConfig(
    unit: 'visits',
    step: 1.0,
    min: 1.0,
    max: 5.0,
    fallbackDefault: 1.0,
  ),
  '4b4ab972-ef92-4344-8573-18bda9e259db': CounterMetricConfig( // Smoked
    unit: 'cigarettes',
    step: 1.0,
    min: 1.0,
    max: 10.0,
    fallbackDefault: 1.0,
  ),
};

CounterMetricConfig getCounterConfig(String metricId) {
  return _counterConfigs[metricId] ?? const CounterMetricConfig(
    unit: 'units',
    step: 1.0,
    min: 1.0,
    max: 10.0,
    fallbackDefault: 1.0,
  );
}

// =============================================================================
// Quick Track Button
// =============================================================================

/// A card button shown in the home screen "Quick Track" grid.
/// Tapping a counter metric logs immediately; other types open a bottom sheet.
class QuickTrackButton extends StatefulWidget {
  final MetricDefinition metric;
  final VoidCallback onLogged;

  const QuickTrackButton({
    super.key,
    required this.metric,
    required this.onLogged,
  });

  @override
  State<QuickTrackButton> createState() => _QuickTrackButtonState();
}

class _QuickTrackButtonState extends State<QuickTrackButton> {
  double _scale = 1.0;
  Offset? _lastTapPosition;

  void _triggerBurst(BuildContext context) {
    if (!mounted) return;
    if (_lastTapPosition != null) {
      ConfettiOverlay.of(context)?.burst(_lastTapPosition!);
    } else {
      // Fallback: burst near the widget center
      final RenderBox? box = context.findRenderObject() as RenderBox?;
      if (box != null) {
        final position = box.localToGlobal(Offset(box.size.width / 2, box.size.height / 2));
        ConfettiOverlay.of(context)?.burst(position);
      }
    }
  }

  Future<void> _handleTap(BuildContext context, {DateTime? customTime, double? customValue}) async {
    if (widget.metric.inputType == MetricInputType.counter) {
      try {
        final db = context.read<AppDatabase>();
        final profileRepo = context.read<ProfileRepository>();
        final eventId = uuid.v4();
        final now = DateTime.now();

        // 1. Get the current default value (either from SharedPreferences or fallback)
        final config = getCounterConfig(widget.metric.id);
        final savedValStr = profileRepo.getStringSetting('quick_track_default_value_${widget.metric.id}');
        final defaultValue = savedValStr != null
            ? (double.tryParse(savedValStr) ?? config.fallbackDefault)
            : config.fallbackDefault;

        final valueToLog = customValue ?? defaultValue;
        final valueStr = valueToLog == valueToLog.toInt()
            ? valueToLog.toInt().toString()
            : valueToLog.toString();

        await db.insertEvent(
          EventsCompanion(
            id: Value(eventId),
            category: Value(widget.metric.category),
            label: Value(widget.metric.label),
            value: Value(valueStr),
            latencyMs: const Value(0),
            triggerSource: const Value(TriggerSource.manual),
            interactionType: const Value(InteractionType.click),
            timestamp: Value(customTime ?? now),
            recordedAt: Value(now),
          ),
        );

        if (context.mounted) {
          widget.onLogged();
          _triggerBurst(context);
          ScaffoldMessenger.of(context).clearSnackBars();
          
          String snackbarText;
          if (widget.metric.id == 'core_meal_count') {
            final mealType = valueToLog == 1.0 ? 'Snack' : (valueToLog == 2.0 ? 'Meal' : 'Feast');
            snackbarText = '$mealType logged! ✓';
          } else if (widget.metric.id == 'core_toilet_urge') {
            snackbarText = 'Bathroom visit logged! ✓';
          } else {
            final displayVal = valueToLog == valueToLog.toInt() ? valueToLog.toInt().toString() : valueToLog.toStringAsFixed(1);
            String unitLabel = config.unit;
            if (valueToLog == 1.0) {
              if (config.unit == 'cups') unitLabel = 'cup';
              if (config.unit == 'drinks') unitLabel = 'drink';
              if (config.unit == 'cigarettes') unitLabel = 'cigarette';
              if (config.unit == 'visits') unitLabel = 'visit';
              if (config.unit == 'meals') unitLabel = 'meal';
            }
            snackbarText = '${widget.metric.label} logged! ($displayVal $unitLabel) ✓';
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Expanded(child: Text(snackbarText)),
                  TextButton(
                    onPressed: () async {
                      await db.deleteEvent(eventId);
                      if (context.mounted) {
                        widget.onLogged();
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
        debugPrint('Error logging quick track: $e');
      }
    } else {
      _showInputModal(context, customTime: customTime);
    }
  }

  void _showValueSliderSheet(BuildContext context) {
    final profileRepo = context.read<ProfileRepository>();
    final config = getCounterConfig(widget.metric.id);
    final savedValStr = profileRepo.getStringSetting('quick_track_default_value_${widget.metric.id}');
    final defaultValue = savedValStr != null
        ? (double.tryParse(savedValStr) ?? config.fallbackDefault)
        : config.fallbackDefault;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => QuickTrackValueSheet(
        metric: widget.metric,
        initialValue: defaultValue,
        unit: config.unit,
        step: config.step,
        min: config.min,
        max: config.max,
        onConfirm: (value, time, saveAsDefault) async {
          if (saveAsDefault) {
            await profileRepo.setStringSetting('quick_track_default_value_${widget.metric.id}', value.toString());
          }
          if (context.mounted) {
            await _handleTap(context, customTime: time, customValue: value);
          }
        },
      ),
    );
  }

  void _showInputModal(BuildContext context, {DateTime? customTime}) {
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
              metric: widget.metric,
              onChanged: (value) async {
                try {
                  final latency = DateTime.now()
                      .difference(openedAt)
                      .inMilliseconds;
                  final db = ctx.read<AppDatabase>();
                  final eventId = uuid.v4();
                  final now = DateTime.now();
                  await db.insertEvent(
                    EventsCompanion(
                      id: Value(eventId),
                      category: Value(widget.metric.category),
                      label: Value(widget.metric.label),
                      value: Value(value),
                      latencyMs: Value(latency),
                      triggerSource: const Value(TriggerSource.manual),
                      interactionType: const Value(InteractionType.click),
                      timestamp: Value(customTime ?? now),
                      recordedAt: Value(now),
                    ),
                  );
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    widget.onLogged();
                    _triggerBurst(context);
                    ScaffoldMessenger.of(ctx).clearSnackBars();
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Expanded(child: Text('${widget.metric.label} logged!')),
                            TextButton(
                              onPressed: () async {
                                await db.deleteEvent(eventId);
                                if (ctx.mounted) {
                                  widget.onLogged();
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

  String _formatValueString(double val) {
    if (val == val.toInt()) {
      return val.toInt().toString();
    }
    return val.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final db = context.read<AppDatabase>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final config = getCounterConfig(widget.metric.id);
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    final todayEventsStream = (db.select(db.events)
          ..where((t) => t.label.equals(widget.metric.label))
          ..where((t) => t.timestamp.isBiggerOrEqualValue(todayStart)))
        .watch();

    return StreamBuilder<List<Event>>(
      stream: todayEventsStream,
      builder: (context, snapshot) {
        final list = snapshot.data ?? [];

        String displayLabel = 'Today: None yet';

        if (list.isNotEmpty) {
          if (widget.metric.id == 'core_meal_count') {
            // Count meals by category
            final snacks = list.where((e) => e.value == '1').length;
            final meals = list.where((e) => e.value == '2').length;
            final feasts = list.where((e) => e.value == '3').length;

            final List<String> segments = [];
            if (meals > 0) segments.add('$meals Meal${meals > 1 ? 's' : ''}');
            if (snacks > 0) segments.add('$snacks Snack${snacks > 1 ? 's' : ''}');
            if (feasts > 0) segments.add('$feasts Feast${feasts > 1 ? 's' : ''}');

            displayLabel = segments.isEmpty ? 'Today: None yet' : 'Today: ${segments.join(', ')}';
          } else {
            // Calculate sum
            double sum = 0.0;
            for (var e in list) {
              sum += double.tryParse(e.value) ?? 1.0;
            }

            final formattedVal = _formatValueString(sum);
            
            if (widget.metric.id == 'core_toilet_urge') {
              displayLabel = 'Today: ${sum.toInt()} visit${sum.toInt() == 1 ? '' : 's'}';
            } else {
              String unitLabel = config.unit;
              if (sum == 1.0) {
                if (config.unit == 'cups') unitLabel = 'cup';
                if (config.unit == 'drinks') unitLabel = 'drink';
                if (config.unit == 'cigarettes') unitLabel = 'cigarette';
                if (config.unit == 'visits') unitLabel = 'visit';
                if (config.unit == 'meals') unitLabel = 'meal';
              }
              
              displayLabel = config.unit == 'units' || config.unit.isEmpty
                  ? 'Today: $formattedVal'
                  : 'Today: $formattedVal $unitLabel';
            }
          }
        }

        return AnimatedScale(
          scale: _scale,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutBack,
          child: Material(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTapDown: (details) {
                setState(() {
                  _scale = 0.94; // shrink slightly
                  _lastTapPosition = details.globalPosition;
                });
              },
              onTapCancel: () {
                setState(() {
                  _scale = 1.0;
                });
              },
              onTap: () {
                setState(() {
                  _scale = 1.0;
                });
                _handleTap(context);
              },
              onLongPress: () async {
                setState(() {
                  _scale = 1.0;
                });
                if (widget.metric.inputType == MetricInputType.counter) {
                  _showValueSliderSheet(context);
                } else {
                  final now = DateTime.now();
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.now(),
                  );
                  if (time != null && context.mounted) {
                    final customTime = DateTime(
                      now.year,
                      now.month,
                      now.day,
                      time.hour,
                      time.minute,
                    );
                    _handleTap(context, customTime: customTime);
                  }
                }
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    MetricIcon(iconName: widget.metric.emoji, size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.metric.label,
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            displayLabel,
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
          ),
        );
      },
    );
  }
}
