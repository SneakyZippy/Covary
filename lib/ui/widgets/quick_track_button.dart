import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import 'metric_input_card.dart';
import 'metric_icon.dart';

// =============================================================================
// Quick Track Button
// =============================================================================

/// A card button shown in the home screen "Quick Track" grid.
/// Tapping a counter metric logs immediately; other types open a bottom sheet.
class QuickTrackButton extends StatelessWidget {
  final MetricDefinition metric;
  final VoidCallback onLogged;

  const QuickTrackButton({
    super.key,
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
