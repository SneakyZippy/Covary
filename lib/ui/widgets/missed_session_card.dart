import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/models/metric_definition.dart';
import 'metric_input_card.dart';
import 'metric_icon.dart';

// =============================================================================
// Missed Session Card
// =============================================================================

/// Displays a missed check-in window with metric chips split by recall
/// reliability. Reliable (factual) metrics are tappable; subjective (scale)
/// metrics are dimmed with a "Log anyway" escape hatch.
class MissedSessionCard extends StatefulWidget {
  final TrackingWindow window;
  final DateTime targetTime;
  final List<MetricDefinition> reliableMetrics;
  final List<MetricDefinition> subjectiveMetrics;
  final ColorScheme colorScheme;
  final TextTheme textTheme;
  final VoidCallback onDismissed;
  final VoidCallback onComplete;
  final VoidCallback onMetricLogged;

  const MissedSessionCard({
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
  State<MissedSessionCard> createState() => _MissedSessionCardState();
}

class _MissedSessionCardState extends State<MissedSessionCard> {
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
                      .map((m) => MissedMetricChip(
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
                      .map((m) => MissedMetricChip(
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
class MissedMetricChip extends StatelessWidget {
  final MetricDefinition metric;
  final DateTime targetTime;
  final bool dimmed;
  final bool isSubjectiveOverride;
  final VoidCallback onLogged;

  const MissedMetricChip({
    super.key,
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
