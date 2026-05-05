import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/metric_service.dart';
import '../../data/database/app_database.dart';
import '../widgets/edit_window_dialog.dart';

class TrackingWindowsScreen extends StatelessWidget {
  const TrackingWindowsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final metricService = context.watch<MetricService>();
    final windows = metricService.allWindows;

    return Scaffold(
      appBar: AppBar(title: const Text('Tracking Windows')),
      body: ReorderableListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: windows.length,
        onReorder: (oldIndex, newIndex) {
          metricService.reorderTrackingWindows(oldIndex, newIndex);
        },
        proxyDecorator: (child, index, animation) {
          return AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Material(
                elevation: 4,
                color: Colors.transparent,
                child: child,
              );
            },
            child: child,
          );
        },
        itemBuilder: (context, index) {
          final window = windows[index];
          final isEnabled = window.isEnabled;
          return Container(
            key: ValueKey(window.id),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: isEnabled ? Theme.of(context).colorScheme.surface : Theme.of(context).colorScheme.surface.withAlpha(150),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isEnabled ? Theme.of(context).colorScheme.outlineVariant : Theme.of(context).colorScheme.outlineVariant.withAlpha(100),
              ),
              boxShadow: isEnabled ? [
                BoxShadow(
                  color: Theme.of(context).colorScheme.shadow.withAlpha(10),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ] : null,
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isEnabled ? Theme.of(context).colorScheme.primary.withAlpha(30) : Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  color: isEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline,
                ),
              ),
              title: Text(
                window.label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isEnabled ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.outline,
                ),
              ),
              subtitle: Row(
                children: [
                  Icon(Icons.access_time_rounded, size: 12, color: isEnabled ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '${_formatTime(window.startHour, window.startMinute)} – '
                    '${_formatTime(window.endHour, window.endMinute)}',
                    style: TextStyle(
                      color: isEnabled ? Theme.of(context).colorScheme.onSurfaceVariant : Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Switch(
                    value: window.isEnabled,
                    onChanged: (val) => metricService.toggleTrackingWindow(window.id),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () =>
                        _showWindowDialog(context, metricService, window),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded),
                    color: Theme.of(context).colorScheme.error,
                    onPressed: () =>
                        _confirmDelete(context, metricService, window),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showWindowDialog(context, metricService),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Window'),
      ),
    );
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _showWindowDialog(
    BuildContext context,
    MetricService service, [
    TrackingWindow? existing,
  ]) {
    showDialog(
      context: context,
      builder: (context) =>
          EditWindowDialog(service: service, existing: existing),
    );
  }

  void _confirmDelete(
    BuildContext context,
    MetricService service,
    TrackingWindow window,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Window?'),
        content: Text('Are you sure you want to delete "${window.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              service.deleteTrackingWindow(window.id);
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

