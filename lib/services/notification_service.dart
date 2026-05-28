import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../ui/screens/daily_checkin_screen.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/meal_reminder.dart';
import '../ui/theme/design_system.dart';

@pragma("vm:entry-point")
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
      await scheduleMealReminders();
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
      await scheduleMealReminders();
    }
  }

  // ===========================================================================
  // Top-Level / Static Listeners (Must be static for Background Execution)
  // ===========================================================================

  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final db = AppDatabase.getInstance();

    if (receivedAction.buttonKeyPressed.startsWith('snooze_')) {
      final minutesStr = receivedAction.buttonKeyPressed
          .replaceFirst('snooze_', '')
          .replaceFirst('m', '');
      final minutes = int.tryParse(minutesStr);
      if (minutes != null) {
        final snoozeVal = minutes >= 60 && minutes % 60 == 0 
            ? '${minutes ~/ 60}h' 
            : '${minutes}m';
        await _logInteraction(
          db, 
          InteractionType.snooze, 
          receivedAction.payload, 
          value: '+$snoozeVal'
        );
        await _snoozeNotification(Duration(minutes: minutes), receivedAction.payload);
      }
    } else if (receivedAction.buttonKeyPressed == 'remind_at') {
      await _logInteraction(db, InteractionType.snooze, receivedAction.payload);
      _showTimePickerDialog(receivedAction.payload);
    } else if (receivedAction.buttonKeyPressed == 'meal_snack' ||
        receivedAction.buttonKeyPressed == 'meal_meal' ||
        receivedAction.buttonKeyPressed == 'meal_feast') {
      
      String value = '1.0';
      if (receivedAction.buttonKeyPressed == 'meal_meal') value = '2.0';
      if (receivedAction.buttonKeyPressed == 'meal_feast') value = '3.0';

      await db.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.nutrition),
          label: const Value('core_meal_count'),
          value: Value(value),
          latencyMs: const Value(0),
          triggerSource: const Value(TriggerSource.notification),
          interactionType: const Value(InteractionType.click),
          timestamp: Value(DateTime.now()),
          recordedAt: Value(DateTime.now()),
        ),
      );

      await _logInteraction(
        db,
        InteractionType.click,
        receivedAction.payload,
        value: value,
      );
    } else {
      if (receivedAction.payload?['notification_type'] == 'meal_reminder') {
        await _logInteraction(
          db,
          InteractionType.click,
          receivedAction.payload,
        );
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

        await _navigateToGuidedCheckin(sessionId: sessionId, windowId: windowId);
      }
    }
  }

  static Future<BuildContext?> _waitForContext({int maxRetries = 30}) async {
    for (int i = 0; i < maxRetries; i++) {
      final context = navigatorKey.currentContext;
      if (context != null) return context;
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return null;
  }

  static Future<void> _navigateToGuidedCheckin({String? sessionId, String? windowId}) async {
    final context = await _waitForContext();
    if (context == null) {
      debugPrint(
        '[NotificationService] navigatorKey has no context. Navigation aborted.',
      );
      return;
    }

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
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();

    final db = AppDatabase.getInstance();
    await _logInteraction(
      db,
      InteractionType.swipeAway,
      receivedAction.payload,
    );
    if (receivedAction.payload?['notification_type'] != 'meal_reminder') {
      await _incrementAndCheckDismissCount();
    }
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
    String? value,
  }) async {
    final windowLabel = payload?['window_label'];
    final metricId = payload?['metric_id'];
    final notificationType = payload?['notification_type'];
    final reminderLabel = payload?['reminder_label'];
    
    String label;
    if (notificationType == 'meal_reminder') {
      label = 'Notification: Meal Reminder (${reminderLabel ?? 'Meal'})';
    } else {
      label = windowLabel != null 
          ? 'Notification: $windowLabel' 
          : 'Notification: ${metricId ?? 'EMA_Prompt'}';
    }

    await db.insertEvent(
      EventsCompanion(
        category: const Value(EventCategory.meta),
        label: Value(label),
        value: Value(value ?? ''),
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
    final context = await _waitForContext();
    if (context == null || !context.mounted) {
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
      
      final newContext = navigatorKey.currentContext;
      final timeString = (newContext != null && newContext.mounted) 
          ? time.format(newContext)
          : '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
          
      // Log the specific time chosen for "Remind at"
      await _logInteraction(
        AppDatabase.getInstance(), 
        InteractionType.snooze, 
        payload, 
        value: 'Until $timeString'
      );
      
      await _snoozeNotification(delay, payload);

      if (newContext != null && newContext.mounted) {
        ScaffoldMessenger.of(newContext).showSnackBar(
          SnackBar(
            content: Text('Reminder set for $timeString'),
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
    debugPrint('[NotificationService] scheduleDailyReminders: isAllowed=$isAllowed');
    if (!isAllowed) return;

    // 1. Clean up stale or disabled notifications.
    // We audit all currently scheduled notifications and cancel those that
    // belong to windows that were deleted or had notifications disabled.
    final scheduled = await AwesomeNotifications().listScheduledNotifications();
    final db = AppDatabase.getInstance();
    final windows = await db.getAllTrackingWindows();
    final snoozeDurations = await getSnoozeDurations();
    final String localTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();
    debugPrint('[NotificationService] Using local timeZone: $localTimeZone');

    for (var s in scheduled) {
      final payload = s.content?.payload;
      if (payload != null && payload.containsKey('window_id')) {
        final windowId = payload['window_id'];
        
        // Check if this window still exists and is enabled
        final exists = windows.any((w) => w.id == windowId);
        final window = exists ? windows.firstWhere((w) => w.id == windowId) : null;
        final shouldBeScheduled = exists && window != null && window.isNotificationEnabled && window.isEnabled;

        if (!exists || !shouldBeScheduled) {
          debugPrint('[NotificationService] Cancelling stale reminder for window: $windowId');
          await AwesomeNotifications().cancel(s.content!.id!);
        }
      }
    }

    // Legacy cleanup for hardcoded IDs 101-104 (if any exist)
    for (int i = 101; i <= 104; i++) {
      await AwesomeNotifications().cancel(i);
    }

    int scheduledCount = 0;
    for (var window in windows) {
      if (!window.isNotificationEnabled || !window.isEnabled) {
        debugPrint('[NotificationService] Skipping window ${window.label}: isNotificationEnabled=${window.isNotificationEnabled}, isEnabled=${window.isEnabled}');
        continue;
      }

      // Generate a stable integer ID from the UUID hash (modulo 1B to allow headroom for snooze ID)
      final notificationId = window.id.hashCode.abs() % 1000000000;
      debugPrint('[NotificationService] Scheduling window ${window.label} (ID: $notificationId) at ${window.notificationHour}:${window.notificationMinute}');
      
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
            timeZone: localTimeZone,
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
        scheduledCount++;
      } catch (e) {
        debugPrint(
          '[NotificationService] Exact alarm scheduling failed for ${window.label}, falling back to inexact alarm: $e',
        );
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
              preciseAlarm: false,
              repeats: true,
              timeZone: localTimeZone,
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
          scheduledCount++;
        } catch (e2) {
          debugPrint(
            '[NotificationService] Inexact alarm scheduling also failed for ${window.label}: $e2',
          );
        }
      }
    }
    debugPrint('[NotificationService] Scheduled notifications for $scheduledCount / ${windows.length} windows.');
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

  static Future<void> scheduleMealReminders() async {
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    debugPrint('[NotificationService] scheduleMealReminders: isAllowed=$isAllowed');
    if (!isAllowed) return;

    final prefs = await SharedPreferences.getInstance();
    final bool masterEnabled = prefs.getBool('meal_reminders_master_enabled') ?? true;
    final String? remindersJson = prefs.getString('meal_reminders');
    final String localTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();

    // 1. Cancel all existing meal reminders
    final scheduled = await AwesomeNotifications().listScheduledNotifications();
    for (var s in scheduled) {
      final payload = s.content?.payload;
      if (payload != null && payload['notification_type'] == 'meal_reminder') {
        await AwesomeNotifications().cancel(s.content!.id!);
      }
    }

    if (!masterEnabled) {
      debugPrint('[NotificationService] Meal reminders are globally disabled.');
      return;
    }

    List<MealReminder> reminders = [];
    if (remindersJson != null) {
      try {
        final List<dynamic> decoded = json.decode(remindersJson);
        reminders = decoded.map((item) => MealReminder.fromMap(item)).toList();
      } catch (e) {
        debugPrint('[NotificationService] Error parsing meal reminders: $e');
      }
    } else {
      // Seed default presets if none are stored yet!
      reminders = [
        MealReminder(id: 'preset_breakfast', label: 'Breakfast', hour: 8, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_lunch', label: 'Lunch', hour: 12, minute: 30, isEnabled: true),
        MealReminder(id: 'preset_dinner', label: 'Dinner', hour: 19, minute: 30, isEnabled: true),
      ];
      final encoded = json.encode(reminders.map((r) => r.toMap()).toList());
      await prefs.setString('meal_reminders', encoded);
    }

    int scheduledCount = 0;
    for (var reminder in reminders) {
      if (!reminder.isEnabled) continue;

      // Stable ID above 2B to prevent collisions
      final notificationId = (reminder.id.hashCode.abs() % 1000000000) + 2000000000;
      debugPrint('[NotificationService] Scheduling meal reminder ${reminder.label} (ID: $notificationId) at ${reminder.hour}:${reminder.minute}');

      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'ema_reminders',
            title: '${reminder.label} Reminder',
            body: 'Time to track your meal. What did you have?',
            payload: {
              'notification_type': 'meal_reminder',
              'reminder_id': reminder.id,
              'reminder_label': reminder.label,
            },
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
          ),
          schedule: NotificationCalendar(
            hour: reminder.hour,
            minute: reminder.minute,
            second: 0,
            allowWhileIdle: true,
            preciseAlarm: true,
            repeats: true,
            timeZone: localTimeZone,
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'meal_snack',
              label: '🍪 Snack',
              actionType: ActionType.SilentBackgroundAction,
            ),
            NotificationActionButton(
              key: 'meal_meal',
              label: '🍲 Meal',
              actionType: ActionType.SilentBackgroundAction,
            ),
            NotificationActionButton(
              key: 'meal_feast',
              label: '🍖 Feast',
              actionType: ActionType.SilentBackgroundAction,
            ),
          ],
        );
        scheduledCount++;
      } catch (e) {
        debugPrint('[NotificationService] Exact alarm failed for meal reminder ${reminder.label}, using inexact: $e');
        try {
          await AwesomeNotifications().createNotification(
            content: NotificationContent(
              id: notificationId,
              channelKey: 'ema_reminders',
              title: '${reminder.label} Reminder',
              body: 'Time to track your meal. What did you have?',
              payload: {
                'notification_type': 'meal_reminder',
                'reminder_id': reminder.id,
                'reminder_label': reminder.label,
              },
              notificationLayout: NotificationLayout.Default,
              category: NotificationCategory.Reminder,
              wakeUpScreen: true,
            ),
            schedule: NotificationCalendar(
              hour: reminder.hour,
              minute: reminder.minute,
              second: 0,
              allowWhileIdle: true,
              preciseAlarm: false,
              repeats: true,
              timeZone: localTimeZone,
            ),
            actionButtons: [
              NotificationActionButton(
                key: 'meal_snack',
                label: '🍪 Snack',
                actionType: ActionType.SilentBackgroundAction,
              ),
              NotificationActionButton(
                key: 'meal_meal',
                label: '🍲 Meal',
                actionType: ActionType.SilentBackgroundAction,
              ),
              NotificationActionButton(
                key: 'meal_feast',
                label: '🍖 Feast',
                actionType: ActionType.SilentBackgroundAction,
              ),
            ],
          );
          scheduledCount++;
        } catch (e2) {
          debugPrint('[NotificationService] Inexact alarm also failed for meal reminder ${reminder.label}: $e2');
        }
      }
    }
    debugPrint('[NotificationService] Scheduled $scheduledCount meal reminders.');
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

    // Use a distinct ID range for snooze to prevent overwriting tomorrow's daily scheduled reminders
    final windowId = payload?['window_id'];
    final notificationType = payload?['notification_type'];
    final reminderId = payload?['reminder_id'];
    final reminderLabel = payload?['reminder_label'];

    final notificationId = windowId != null 
        ? ((windowId.hashCode.abs() % 1000000000) + 1000000000) 
        : (notificationType == 'meal_reminder' && reminderId != null
            ? ((reminderId.hashCode.abs() % 1000000000) + 3000000000)
            : 100);

    final bool isMeal = notificationType == 'meal_reminder';

    final String title = isMeal
        ? '${reminderLabel ?? 'Meal'} Reminder (Snoozed)'
        : (payload?['window_label'] != null
            ? '${payload!['window_label']} Check-in (Snoozed)'
            : 'Time for a quick update!');

    final String body = isMeal
        ? 'Time to track your meal. What did you have?'
        : 'Please take a moment to record your current status.';

    final actionButtons = isMeal
        ? [
            NotificationActionButton(
              key: 'meal_snack',
              label: '🍪 Snack',
              actionType: ActionType.SilentBackgroundAction,
            ),
            NotificationActionButton(
              key: 'meal_meal',
              label: '🍲 Meal',
              actionType: ActionType.SilentBackgroundAction,
            ),
            NotificationActionButton(
              key: 'meal_feast',
              label: '🍖 Feast',
              actionType: ActionType.SilentBackgroundAction,
            ),
          ]
        : [
            NotificationActionButton(
              key: 'remind_at',
              label: 'At time...',
              actionType: ActionType.Default,
            ),
            ..._buildSnoozeButtons(snoozeDurations),
          ];

    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: notificationId,
          channelKey: 'ema_reminders',
          title: title,
          body: body,
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
        actionButtons: actionButtons,
      );
    } catch (e) {
      debugPrint('[NotificationService] Exact alarm scheduling failed, falling back to inexact alarm: $e');
      try {
        await AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: notificationId,
            channelKey: 'ema_reminders',
            title: title,
            body: body,
            payload: payload ?? {'metric_id': 'default'},
            notificationLayout: NotificationLayout.Default,
            category: NotificationCategory.Reminder,
            wakeUpScreen: true,
          ),
          schedule: NotificationCalendar.fromDate(
            date: DateTime.now().add(delay ?? const Duration(seconds: 10)),
            allowWhileIdle: true,
            preciseAlarm: false,
          ),
          actionButtons: actionButtons,
        );
      } catch (e2) {
        debugPrint('[NotificationService] Inexact alarm scheduling also failed: $e2');
      }
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
        actionType: ActionType.SilentBackgroundAction,
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
