import 'package:flutter/material.dart';
import '../../services/sync_service.dart';

class SyncSummaryDialog extends StatelessWidget {
  final SyncSummary summary;

  const SyncSummaryDialog({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      icon: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.cloud_done_rounded,
          color: colorScheme.onPrimaryContainer,
          size: 40,
        ),
      ),
      title: Text(
        'Restore Complete',
        style: textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
        textAlign: TextAlign.center,
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Your cloud backup has been merged successfully into the local database.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            if (summary.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      color: colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Everything was already up to date. No new records were added or changed.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else ...[
              _buildSummaryRow(
                context,
                title: 'Tracking Windows',
                icon: Icons.schedule_rounded,
                added: summary.windowsAdded,
                updated: summary.windowsUpdated,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                context,
                title: 'Custom Metrics',
                icon: Icons.tune_rounded,
                added: summary.metricsAdded,
                updated: summary.metricsUpdated,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                context,
                title: 'Logged Events',
                icon: Icons.history_rounded,
                added: summary.eventsAdded,
                updated: summary.eventsUpdated,
              ),
            ],
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Awesome'),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(
    BuildContext context, {
    required String title,
    required IconData icon,
    required int added,
    required int updated,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final hasChanges = added > 0 || updated > 0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: hasChanges
            ? colorScheme.primaryContainer.withAlpha(20)
            : colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasChanges
              ? colorScheme.primary.withAlpha(50)
              : colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: hasChanges ? colorScheme.primary : colorScheme.onSurfaceVariant,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: hasChanges ? FontWeight.bold : FontWeight.normal,
                color: hasChanges ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (!hasChanges)
            Text(
              'No changes',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.outline,
                fontStyle: FontStyle.italic,
              ),
            )
          else ...[
            if (added > 0)
              _buildBadge(
                context,
                count: added,
                label: 'Added',
                bgColor: colorScheme.primaryContainer,
                textColor: colorScheme.onPrimaryContainer,
              ),
            if (added > 0 && updated > 0) const SizedBox(width: 4),
            if (updated > 0)
              _buildBadge(
                context,
                count: updated,
                label: 'Updated',
                bgColor: colorScheme.secondaryContainer,
                textColor: colorScheme.onSecondaryContainer,
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required int count,
    required String label,
    required Color bgColor,
    required Color textColor,
  }) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '+$count $label',
        style: textTheme.labelSmall?.copyWith(
          color: textColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
