import 'dart:async';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../ui/screens/daily_checkin_screen.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../ui/theme/design_system.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static const String _kSnoozeDurationsKey = 'notification_snooze_durations';
  static const List<int> _defaultSnoozeDurations = [15, 60]; // 15m, 1h

  /// Global navigator key accessed when notifications launch the app
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    await AwesomeNotifications().initialize(
      null,
      [
        NotificationChannel(
          channelKey: 'ema_reminders',
          channelName: 'EMA Reminders',
          channelDescription:
              'Notifications for Ecological Momentary Assessment prompts',
          defaultColor: CovaryDesignSystem.primary,
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
        ),
      ],
    );

    // Register top-level listeners
    await AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) {
      await scheduleDailyReminders();
    }
  }

  /// Request permissions to send notifications
  Future<void> requestPermissions() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) {
      await scheduleDailyReminders();
    }
  }

  // ===========================================================================
  // Top-Level / Static Listeners (Must be static for Background Execution)
  // ===========================================================================

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final db = AppDatabase.getInstance();

    if (receivedAction.buttonKeyPressed.startsWith('snooze_')) {
      final minutesStr = receivedAction.buttonKeyPressed
          .replaceFirst('snooze_', '')
          .replaceFirst('m', '');
      final minutes = int.tryParse(minutesStr);
      if (minutes != null) {
        await _logInteraction(db, InteractionType.snooze, receivedAction.payload);
        await _snoozeNotification(Duration(minutes: minutes), receivedAction.payload);
      }
    } else if (receivedAction.buttonKeyPressed == 'remind_at') {
      await _logInteraction(db, InteractionType.snooze, receivedAction.payload);
      Future.delayed(const Duration(milliseconds: 500), () {
        _showTimePickerDialog(receivedAction.payload);
      });
    } else {
      await _resetDismissCount();

      final sessionId = const Uuid().v4();
      final windowId = receivedAction.payload?['window_id'];

      await _logInteraction(
        db,
        InteractionType.click,
        receivedAction.payload,
        sessionId: sessionId,
      );

      if (receivedAction.payload?['metric_id'] != null) {
        debugPrint(
          '[NotificationService] Deep link to metric: ${receivedAction.payload?['metric_id']}',
        );
      }

      _navigateToGuidedCheckin(sessionId: sessionId, windowId: windowId);
    }
  }

  static void _navigateToGuidedCheckin({String? sessionId, String? windowId}) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => DailyCheckinScreen(
            mode: CheckinMode.guided,
            sessionId: sessionId,
            fulfilledSlotId: windowId,
            // Bug 3 fix: mark the session as notification-triggered so all
            // metric events inside it carry the correct triggerSource.
            triggerSource: TriggerSource.notification,
          ),
        ),
      );
    });
  }

  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    final db = AppDatabase.getInstance();
    await _logInteraction(
      db,
      InteractionType.swipeAway,
      receivedAction.payload,
    );
    await _incrementAndCheckDismissCount();
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('[NotificationService] Notification Scheduled');
  }

  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('[NotificationService] Notification Displayed');
  }

  // ===========================================================================
  // Smart Snooze logic & Event Logging
  // ===========================================================================

  static Future<void> _logInteraction(
    AppDatabase db,
    InteractionType type,
    Map<String, String?>? payload, {
    String? sessionId,
  }) async {
    final windowLabel = payload?['window_label'];
    final metricId = payload?['metric_id'];
    
    final label = windowLabel != null 
        ? 'Notification: $windowLabel' 
        : 'Notification: ${metricId ?? 'EMA_Prompt'}';

    await db.insertEvent(
      EventsCompanion(
        category: const Value(EventCategory.meta),
        label: Value(label),
        value: const Value(''),
        triggerSource: const Value(TriggerSource.notification),
        interactionType: Value(type),
        sessionId: Value(sessionId),
      ),
    );
  }

  static Future<void> _incrementAndCheckDismissCount() async {
    final prefs = await SharedPreferences.getInstance();
    int count = (prefs.getInt('dismiss_count') ?? 0) + 1;
    await prefs.setInt('dismiss_count', count);

    if (count >= 3) {
      await prefs.setInt('dismiss_count', 0);
      _triggerFatigueLogic();
    }
  }

  static Future<void> _resetDismissCount() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dismiss_count', 0);
  }

  static Future<void> _snoozeNotification(
    Duration offset,
    Map<String, String?>? payload,
  ) async {
    await schedulePrompt(delay: offset, payload: payload);
  }

  // ===========================================================================
  // UI Dialogs via GlobalKey
  // ===========================================================================

  static Future<void> _showTimePickerDialog(
    Map<String, String?>? payload,
  ) async {
    final context = navigatorKey.currentContext;
    if (context == null) {
      debugPrint(
        '[NotificationService] navigatorKey has no context. App is dead?',
      );
      return;
    }

    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (time != null) {
      final now = DateTime.now();
      var scheduledTime = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(const Duration(days: 1));
      }

      final delay = scheduledTime.difference(now);
      await _snoozeNotification(delay, payload);

      final newContext = navigatorKey.currentContext;
      if (newContext != null && newContext.mounted) {
        ScaffoldMessenger.of(newContext).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${time.format(newContext)}'),
          ),
        );
      }
    }
  }

  static void _triggerFatigueLogic() {
    Future.delayed(const Duration(milliseconds: 500), () {
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showFatigueDialog(context);
      } else {
        SharedPreferences.getInstance().then((prefs) {
          prefs.setBool('show_fatigue_dialog', true);
        });
      }
    });
  }

  Future<void> checkPendingFatigueDialog() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('show_fatigue_dialog') == true) {
      await prefs.setBool('show_fatigue_dialog', false);
      final context = navigatorKey.currentContext;
      if (context != null && context.mounted) {
        _showFatigueDialog(context);
      }
    }
  }

  static void _showFatigueDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Too Many Reminders?'),
        content: const Text(
          'You\'ve dismissed the last 3 reminders. Would you like to adjust your reminder schedule or pause them?',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logFatigueResponse('keep_as_is');
            },
            child: const Text('Keep as is'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              _logFatigueResponse('adjusted_schedule');
            },
            child: const Text('Adjust Schedule'),
          ),
        ],
      ),
    );
  }

  static Future<void> _logFatigueResponse(String response) async {
    final db = AppDatabase.getInstance();
    await db.insertEvent(
      EventsCompanion(
        category: const Value(EventCategory.meta),
        label: const Value('FatigueAlert'),
        value: Value(response),
        triggerSource: const Value(TriggerSource.system),
        interactionType: const Value(InteractionType.click),
      ),
    );
  }

  // ===========================================================================
  // Public Notification Creation
  // ===========================================================================

  static Future<void> scheduleDailyReminders() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) return;

    // 1. Clean up stale or disabled notifications.
    // We audit all currently scheduled notifications and cancel those that
    // belong to windows that were deleted or had notifications disabled.
    final scheduled = await AwesomeNotifications().listScheduledNotifications();
    final db = AppDatabase.getInstance();
    final windows = await db.getAllTrackingWindows();
    final snoozeDurations = await getSnoozeDurations();

    for (var s in scheduled) {
      final payload = s.content?.payload;
      if (payload != null && payload.containsKey('window_id')) {
        final windowId = payload['window_id'];
        
        // Check if this window still exists and is enabled
        final exists = windows.any((w) => w.id == windowId);
        final isEnabled = exists && windows.firstWhere((w) => w.id == windowId).isNotificationEnabled;

        if (!exists || !isEnabled) {
          debugPrint('[NotificationService] Cancelling stale reminder for window: $windowId');
          await AwesomeNotifications().cancel(s.content!.id!);
        }
      }
    }

    // Legacy cleanup for hardcoded IDs 101-104 (if any exist)
    for (int i = 101; i <= 104; i++) {
      await AwesomeNotifications().cancel(i);
    }


    for (var window in windows) {
      if (!window.isNotificationEnabled) continue;

      // Generate a stable integer ID from the UUID hash
      final notificationId = window.id.hashCode.abs() % 100000;
      
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'ema_reminders',
            title: '${window.label} Check-in',
            body: 'Time for your ${window.label.toLowerCase()} update! Please take a moment to record your status.',
            payload: {
              'metric_id': 'default',
              'window_id': window.id,
              'window_label': window.label,
            },
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
          ),
          schedule: NotificationCalendar(
            hour: window.notificationHour,
            minute: window.notificationMinute,
            second: 0,
            allowWhileIdle: true,
            preciseAlarm: true,
            repeats: true,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'remind_at',
              label: 'At time...',
              actionType: ActionType.Default,
            ),
            ..._buildSnoozeButtons(snoozeDurations),
          ],
        );
      } catch (e) {
        debugPrint(
          '[NotificationService] Exception scheduling ${window.label} notification: $e',
        );
      }
    }
    debugPrint('[NotificationService] Scheduled notifications for ${windows.length} windows.');
  }

  static Future<TimeOfDay> getReminderTime(
    String name,
    TimeOfDay defaultTime,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final hour = prefs.getInt('reminder_${name}_hour') ?? defaultTime.hour;
    final minute =
        prefs.getInt('reminder_${name}_minute') ?? defaultTime.minute;
    return TimeOfDay(hour: hour, minute: minute);
  }

  static Future<void> setReminderTime(String name, TimeOfDay time) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('reminder_${name}_hour', time.hour);
    await prefs.setInt('reminder_${name}_minute', time.minute);
    await scheduleDailyReminders();
  }

  static Future<void> schedulePrompt({
    Duration? delay,
    Map<String, String?>? payload,
  }) async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      debugPrint(
        '[NotificationService] Missing notification permissions.',
      );
      return;
    }

    final snoozeDurations = await getSnoozeDurations();

    // Use the same ID logic as scheduleDailyReminders to ensure consistent window handling
    // or fallback to 100 if no window_id is present.
    final windowId = payload?['window_id'];
    final notificationId = windowId != null 
        ? (windowId.hashCode.abs() % 100000) 
        : 100;

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'ema_reminders',
          title: 'Time for a quick update!',
          body: 'Please take a moment to record your current status.',
          payload: payload ?? {'metric_id': 'default'},
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          wakeUpScreen: true,
        ),
        schedule: NotificationCalendar.fromDate(
          date: DateTime.now().add(delay ?? const Duration(seconds: 10)),
          allowWhileIdle: true,
          preciseAlarm: true,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'remind_at',
            label: 'At time...',
            actionType: ActionType.Default,
          ),
          ..._buildSnoozeButtons(snoozeDurations),
        ],
      );
    } catch (e) {
      debugPrint('[NotificationService] Exception scheduling notification: $e');
    }
  }

  // ===========================================================================
  // Settings & Helpers
  // ===========================================================================

  static Future<List<int>> getSnoozeDurations() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSnoozeDurationsKey);
    if (list == null) return _defaultSnoozeDurations;
    return list.map((e) => int.parse(e)).toList();
  }

  static Future<void> setSnoozeDurations(List<int> durations) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _kSnoozeDurationsKey,
      durations.map((e) => e.toString()).toList(),
    );
    await scheduleDailyReminders();
  }

  static List<NotificationActionButton> _buildSnoozeButtons(List<int> durations) {
    return durations.map((mins) {
      return NotificationActionButton(
        key: 'snooze_${mins}m',
        label: '+ ${_formatDurationLabel(mins)}',
        actionType: ActionType.SilentAction,
      );
    }).toList();
  }

  static String _formatDurationLabel(int minutes) {
    if (minutes >= 60 && minutes % 60 == 0) {
      return '${minutes ~/ 60}h';
    }
    return '${minutes}m';
  }
}
