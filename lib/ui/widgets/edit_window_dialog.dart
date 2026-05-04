import 'package:flutter/material.dart';
import '../../services/metric_service.dart';
import '../../data/database/app_database.dart';

class EditWindowDialog extends StatefulWidget {
  final MetricService service;
  final TrackingWindow? existing;

  const EditWindowDialog({super.key, required this.service, this.existing});

  @override
  State<EditWindowDialog> createState() => _EditWindowDialogState();
}

class _EditWindowDialogState extends State<EditWindowDialog> {
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
  void dispose() {
    _labelController.dispose();
    super.dispose();
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
