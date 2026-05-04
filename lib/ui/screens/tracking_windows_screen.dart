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
          return Card(
            key: ValueKey(window.id),
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              leading: const Icon(Icons.schedule_rounded),
              title: Text(
                window.label,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Row(
                children: [
                  Text(
                    '${_formatTime(window.startHour, window.startMinute)} – '
                    '${_formatTime(window.endHour, window.endMinute)}',
                  ),
                  if (window.isNotificationEnabled) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.notifications_active_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatTime(window.notificationHour, window.notificationMinute),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
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

