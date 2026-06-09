import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../data/models/meal_reminder.dart';
import '../../services/notification_service.dart';
import '../widgets/help_button.dart';


class MealRemindersScreen extends StatefulWidget {
  const MealRemindersScreen({super.key});

  @override
  State<MealRemindersScreen> createState() => _MealRemindersScreenState();
}

class _MealRemindersScreenState extends State<MealRemindersScreen> {
  bool _masterEnabled = true;
  List<MealReminder> _reminders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final master = prefs.getBool('meal_reminders_master_enabled') ?? true;
    final jsonStr = prefs.getString('meal_reminders');

    List<MealReminder> loaded = [];
    if (jsonStr != null) {
      try {
        final List<dynamic> decoded = json.decode(jsonStr);
        loaded = decoded.map((item) => MealReminder.fromMap(item)).toList();
      } catch (e) {
        debugPrint('[MealRemindersScreen] Error loading reminders: $e');
      }
    } else {
      // Load default presets
      loaded = [
        MealReminder(id: 'preset_breakfast', label: 'Breakfast', hour: 8, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_lunch', label: 'Lunch', hour: 12, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_dinner', label: 'Dinner', hour: 19, minute: 30, isEnabled: true),
      ];
      await prefs.setString('meal_reminders', json.encode(loaded.map((r) => r.toMap()).toList()));
    }

    if (mounted) {
      setState(() {
        _masterEnabled = master;
        _reminders = loaded;
        _isLoading = false;
      });
    }
  }

  Future<void> _saveAndSync() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('meal_reminders_master_enabled', _masterEnabled);
    await prefs.setString(
      'meal_reminders',
      json.encode(_reminders.map((r) => r.toMap()).toList()),
    );
    await NotificationService.scheduleMealReminders();
  }

  Future<void> _toggleMaster(bool value) async {
    setState(() {
      _masterEnabled = value;
    });
    await _saveAndSync();
  }

  Future<void> _toggleReminder(int index, bool value) async {
    setState(() {
      _reminders[index] = _reminders[index].copyWith(isEnabled: value);
    });
    await _saveAndSync();
  }

  Future<void> _deleteReminder(int index) async {
    final reminder = _reminders[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Reminder?'),
        content: Text('Are you sure you want to delete the reminder for "${reminder.label}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        _reminders.removeAt(index);
      });
      await _saveAndSync();
    }
  }

  Future<void> _editTime(int index) async {
    final reminder = _reminders[index];
    final initialTime = TimeOfDay(hour: reminder.hour, minute: reminder.minute);
    final selectedTime = await showTimePicker(
      context: context,
      initialTime: initialTime,
    );

    if (selectedTime != null) {
      setState(() {
        _reminders[index] = _reminders[index].copyWith(
          hour: selectedTime.hour,
          minute: selectedTime.minute,
        );
      });
      await _saveAndSync();
    }
  }

  Future<void> _editLabel(int index) async {
    final reminder = _reminders[index];
    final controller = TextEditingController(text: reminder.label);

    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Lunch, Afternoon Snack',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel != null && newLabel.isNotEmpty) {
      setState(() {
        _reminders[index] = _reminders[index].copyWith(label: newLabel);
      });
      await _saveAndSync();
    }
  }

  Future<void> _addReminder() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Meal Reminder'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. Breakfast, Dinner, Snack',
          ),
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Next'),
          ),
        ],
      ),
    );

    if (label != null && label.isNotEmpty) {
      if (!mounted) return;
      final selectedTime = await showTimePicker(
        context: context,
        initialTime: const TimeOfDay(hour: 12, minute: 0),
      );

      if (selectedTime != null) {
        final newReminder = MealReminder(
          id: const Uuid().v4(),
          label: label,
          hour: selectedTime.hour,
          minute: selectedTime.minute,
          isEnabled: true,
        );

        setState(() {
          _reminders.add(newReminder);
        });
        await _saveAndSync();
      }
    }
  }

  Future<void> _resetToPresets() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to Presets?'),
        content: const Text('This will replace all current meal reminders with the default presets (Breakfast, Lunch, Dinner).'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final presets = [
        MealReminder(id: 'preset_breakfast', label: 'Breakfast', hour: 8, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_lunch', label: 'Lunch', hour: 12, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_dinner', label: 'Dinner', hour: 19, minute: 30, isEnabled: true),
      ];

      setState(() {
        _reminders = presets;
      });
      await _saveAndSync();
    }
  }

  String _formatTime(int hour, int minute) {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Meal Reminders'),
        centerTitle: true,
        actions: const [
          AppBarHelpButton(screenKey: 'meal_reminders'),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // --- Header Description ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Customize your meal logging schedule. Notifications will show up at these times with quick-log buttons for Snack, Meal, and Feast.',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // --- Master switch card ---
                          Card(
                            child: SwitchListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                              secondary: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: _masterEnabled
                                      ? colorScheme.primaryContainer
                                      : colorScheme.surface,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  Icons.restaurant_rounded,
                                  color: _masterEnabled
                                      ? colorScheme.onPrimaryContainer
                                      : colorScheme.outline,
                                  size: 20,
                                ),
                              ),
                              title: const Text(
                                'Enable Meal Reminders',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                _masterEnabled
                                    ? 'Notifications are active'
                                    : 'All meal reminders disabled',
                              ),
                              value: _masterEnabled,
                              onChanged: _toggleMaster,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // --- Reminders List ---
                  if (_reminders.isEmpty)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 48),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.notifications_off_outlined,
                                size: 48,
                                color: colorScheme.outline,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'No meal reminders set up.',
                                style: TextStyle(color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final reminder = _reminders[index];
                            final isCardEnabled = _masterEnabled && reminder.isEnabled;

                             return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                gradient: LinearGradient(
                                  colors: isCardEnabled
                                      ? [
                                          colorScheme.surfaceContainerHighest.withAlpha(70),
                                          colorScheme.surfaceContainer.withAlpha(40),
                                        ]
                                      : [
                                          colorScheme.surfaceContainerHighest.withAlpha(30),
                                          colorScheme.surfaceContainer.withAlpha(15),
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                border: Border.all(
                                  color: isCardEnabled
                                      ? colorScheme.outlineVariant.withAlpha(80)
                                      : colorScheme.outlineVariant.withAlpha(40),
                                  width: 1.0,
                                ),
                                boxShadow: isCardEnabled
                                    ? [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(15),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                leading: Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: isCardEnabled
                                        ? colorScheme.primary.withAlpha(30)
                                        : colorScheme.surfaceContainerHighest,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.alarm_rounded,
                                    color: isCardEnabled
                                        ? colorScheme.primary
                                        : colorScheme.outline,
                                  ),
                                ),
                                title: InkWell(
                                  onTap: _masterEnabled ? () => _editLabel(index) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      children: [
                                        Text(
                                          reminder.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCardEnabled
                                                ? colorScheme.onSurface
                                                : colorScheme.outline,
                                          ),
                                        ),
                                        if (_masterEnabled) ...[
                                          const SizedBox(width: 6),
                                          Icon(
                                            Icons.edit_rounded,
                                            size: 12,
                                            color: colorScheme.outline,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                                subtitle: InkWell(
                                  onTap: _masterEnabled ? () => _editTime(index) : null,
                                  borderRadius: BorderRadius.circular(8),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: isCardEnabled
                                              ? colorScheme.primary
                                              : colorScheme.outline,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          _formatTime(reminder.hour, reminder.minute),
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: isCardEnabled
                                                ? colorScheme.primary
                                                : colorScheme.outline,
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(
                                      value: reminder.isEnabled,
                                      onChanged: _masterEnabled
                                          ? (val) => _toggleReminder(index, val)
                                          : null,
                                    ),
                                    IconButton(
                                      icon: Icon(
                                        Icons.delete_outline_rounded,
                                        color: _masterEnabled
                                            ? colorScheme.error
                                            : colorScheme.outline,
                                      ),
                                      onPressed: _masterEnabled
                                          ? () => _deleteReminder(index)
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                          childCount: _reminders.length,
                        ),
                      ),
                    ),

                  // --- Presets reset option ---
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: TextButton.icon(
                          onPressed: _masterEnabled ? _resetToPresets : null,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset to Presets'),
                          style: TextButton.styleFrom(
                            foregroundColor: colorScheme.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: _masterEnabled
          ? FloatingActionButton.extended(
              onPressed: _addReminder,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add Reminder'),
            )
          : null,
    );
  }
}
