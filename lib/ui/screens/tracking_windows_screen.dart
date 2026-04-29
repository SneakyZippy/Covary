import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/metric_service.dart';
import '../../data/database/app_database.dart';

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
          _EditWindowDialog(service: service, existing: existing),
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

class _EditWindowDialog extends StatefulWidget {
  final MetricService service;
  final TrackingWindow? existing;

  const _EditWindowDialog({required this.service, this.existing});

  @override
  State<_EditWindowDialog> createState() => _EditWindowDialogState();
}

class _EditWindowDialogState extends State<_EditWindowDialog> {
  final _labelController = TextEditingController();
  TimeOfDay _startTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 9, minute: 0);
  bool _isNotificationEnabled = false;
  TimeOfDay _notificationTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      _labelController.text = widget.existing!.label;
      _startTime = TimeOfDay(
        hour: widget.existing!.startHour,
        minute: widget.existing!.startMinute,
      );
      _endTime = TimeOfDay(
        hour: widget.existing!.endHour,
        minute: widget.existing!.endMinute,
      );
      _isNotificationEnabled = widget.existing!.isNotificationEnabled;
      _notificationTime = TimeOfDay(
        hour: widget.existing!.notificationHour,
        minute: widget.existing!.notificationMinute,
      );
    } else {
      _notificationTime = _startTime;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'New Window' : 'Edit Window'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              decoration: const InputDecoration(
                labelText: 'Window Name',
                hintText: 'e.g. Morning Routine',
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('Start Time'),
              trailing: Text(_startTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _startTime,
                );
                if (picked != null) {
                  setState(() {
                    // If notification time was the same as start time, sync it to the new start time
                    if (_notificationTime.hour == _startTime.hour &&
                        _notificationTime.minute == _startTime.minute) {
                      _notificationTime = picked;
                    }
                    _startTime = picked;
                  });
                }
              },
            ),
            ListTile(
              title: const Text('End Time'),
              trailing: Text(_endTime.format(context)),
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: _endTime,
                );
                if (picked != null) setState(() => _endTime = picked);
              },
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Enable Notification'),
              subtitle: const Text('Send a reminder for this window'),
              value: _isNotificationEnabled,
              onChanged: (val) => setState(() => _isNotificationEnabled = val),
            ),
            if (_isNotificationEnabled)
              ListTile(
                title: const Text('Notification Time'),
                trailing: Text(_notificationTime.format(context)),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: context,
                    initialTime: _notificationTime,
                  );
                  if (picked != null) setState(() => _notificationTime = picked);
                },
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_labelController.text.isEmpty) return;

            if (widget.existing == null) {
              widget.service.addTrackingWindow(
                label: _labelController.text,
                startHour: _startTime.hour,
                startMinute: _startTime.minute,
                endHour: _endTime.hour,
                endMinute: _endTime.minute,
                isNotificationEnabled: _isNotificationEnabled,
                notificationHour: _notificationTime.hour,
                notificationMinute: _notificationTime.minute,
              );
            } else {
              widget.service.updateTrackingWindow(
                widget.existing!.id,
                label: _labelController.text,
                startHour: _startTime.hour,
                startMinute: _startTime.minute,
                endHour: _endTime.hour,
                endMinute: _endTime.minute,
                isNotificationEnabled: _isNotificationEnabled,
                notificationHour: _notificationTime.hour,
                notificationMinute: _notificationTime.minute,
              );
            }
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
