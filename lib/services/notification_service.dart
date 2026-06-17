import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart' hide Column;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../ui/screens/daily_checkin_screen.dart';
import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/meal_reminder.dart';
import '../ui/theme/design_system.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pwa_push_interop.dart';
import 'supabase_config.dart';

@pragma("vm:entry-point")
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  static StreamSubscription<int>? _mealSubscription;

  static const String _kSnoozeDurationsKey = 'notification_snooze_durations';
  static const List<int> _defaultSnoozeDurations = [15, 60]; // 15m, 1h

  /// Global navigator key accessed when notifications launch the app
  static GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  Future<void> init() async {
    if (kIsWeb) {
      debugPrint('[NotificationService] PWA platform detected. Initializing Web Push permissions...');
      try {
        final permission = PwaPushInterop.getPermissionStatus();
        debugPrint('[NotificationService] Initial Web Push permission status: $permission');
        if (permission == 'granted') {
          await scheduleDailyReminders();
          await scheduleMealReminders();
          _subscribeToMealChanges();
        }
        await processWebPushQueue();
      } catch (e) {
        debugPrint('[NotificationService] Web Push initialization failed: $e');
      }
      return;
    }
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
      _subscribeToMealChanges();
    }
  }

  /// Request permissions to send notifications
  Future<void> requestPermissions() async {
    if (kIsWeb) {
      try {
        debugPrint('[NotificationService] Requesting Web Push permissions...');
        final permission = await PwaPushInterop.requestPermission();
        debugPrint('[NotificationService] Web Push permission request result: $permission');
        if (permission == 'granted') {
          await scheduleDailyReminders();
          await scheduleMealReminders();
          _subscribeToMealChanges();
        }
      } catch (e) {
        debugPrint('[NotificationService] Web Push request permission error: $e');
      }
      return;
    }
    bool isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (!isAllowed) {
      await AwesomeNotifications().requestPermissionToSendNotifications();
    }
    isAllowed = await AwesomeNotifications().isNotificationAllowed();
    if (isAllowed) {
      await scheduleDailyReminders();
      await scheduleMealReminders();
      _subscribeToMealChanges();
    }
  }

  static void _subscribeToMealChanges() {
    if (_mealSubscription != null) return;
    final db = AppDatabase.getInstance();
    _mealSubscription = db.watchTodayCountForLabel('core_meal_count').listen((_) {
      debugPrint('[NotificationService] Meal logged/deleted, rescheduling meal reminders.');
      scheduleMealReminders();
    });
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

      await scheduleMealReminders();
    } else {
      if (receivedAction.payload?['notification_type'] == 'meal_reminder') {
        await _logInteraction(
          db,
          InteractionType.click,
          receivedAction.payload,
        );
      } else {
        await resetDismissCount();

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

        await _navigateToGuidedCheckin(
          sessionId: sessionId,
          windowId: windowId,
          notificationDisplayedAt: receivedAction.displayedDate ?? receivedAction.actionDate,
        );
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

  static Future<void> _navigateToGuidedCheckin({
    String? sessionId,
    String? windowId,
    DateTime? notificationDisplayedAt,
  }) async {
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
            triggerSource: TriggerSource.notification,
            notificationDisplayedAt: notificationDisplayedAt,
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

  static Future<void> resetDismissCount() async {
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
    if (kIsWeb) return;
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userUuid = prefs.getString('user_uuid') ?? 'unknown_user';
      
      // Clear existing unsent pushes to prevent duplicates
      await _clearWebPushes(userUuid);
      
      final db = AppDatabase.getInstance();
      final windows = await db.getAllTrackingWindows();
      final snoozeDurations = await getSnoozeDurations();
      final webActions = snoozeDurations.map((mins) => {
        'action': 'snooze_${mins}m',
        'title': '+ ${_formatDurationLabel(mins)}',
      }).toList();
      
      for (var window in windows) {
        if (!window.isNotificationEnabled || !window.isEnabled) continue;
        
        // Compute next occurrence
        final now = DateTime.now();
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          window.notificationHour,
          window.notificationMinute,
        );
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }
        
        await _scheduleWebPush(
          userUuid: userUuid,
          scheduledFor: scheduledTime,
          payload: {
            'title': '${window.label} Check-in',
            'body': 'Time for your ${window.label.toLowerCase()} update! Please take a moment to record your status.',
            'data': {
              'notification_type': 'daily_reminder',
              'window_id': window.id,
              'window_label': window.label,
            },
            'actions': webActions,
          },
        );
      }
      return;
    }
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

      // Generate a stable integer ID from the UUID hash (modulo 500M to allow headroom for snooze ID)
      final notificationId = window.id.hashCode.abs() % 500000000;
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userUuid = prefs.getString('user_uuid') ?? 'unknown_user';
      final bool masterEnabled = prefs.getBool('meal_reminders_master_enabled') ?? true;
      final String? remindersJson = prefs.getString('meal_reminders');

      // Clear existing meal pushes from Supabase
      try {
        await Supabase.instance.client
            .from('pwa_push_reminders')
            .delete()
            .eq('user_uuid', userUuid)
            .eq('sent', false)
            .filter('payload->data->>notification_type', 'eq', 'meal_reminder');
      } catch (e) {
        debugPrint('[NotificationService] Error clearing web meal reminders: $e');
      }

      if (!masterEnabled) {
        debugPrint('[NotificationService] Meal reminders are globally disabled on Web.');
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
        reminders = [
          MealReminder(id: 'preset_breakfast', label: 'Breakfast', hour: 8, minute: 30, isEnabled: true),
          MealReminder(id: 'preset_lunch', label: 'Lunch', hour: 12, minute: 30, isEnabled: true),
          MealReminder(id: 'preset_dinner', label: 'Dinner', hour: 19, minute: 30, isEnabled: true),
        ];
      }

      for (var reminder in reminders) {
        if (!reminder.isEnabled) continue;

        // Compute next occurrence
        final now = DateTime.now();
        var scheduledTime = DateTime(
          now.year,
          now.month,
          now.day,
          reminder.hour,
          reminder.minute,
        );
        if (scheduledTime.isBefore(now)) {
          scheduledTime = scheduledTime.add(const Duration(days: 1));
        }

        await _scheduleWebPush(
          userUuid: userUuid,
          scheduledFor: scheduledTime,
          payload: {
            'title': '${reminder.label} Reminder',
            'body': 'Time to track your meal. What did you have?',
            'data': {
              'notification_type': 'meal_reminder',
              'reminder_id': reminder.id,
              'reminder_label': reminder.label,
            },
            'actions': [
              {'action': 'meal_snack', 'title': '🍪 Snack'},
              {'action': 'meal_meal', 'title': '🍲 Meal'},
              {'action': 'meal_feast', 'title': '🍖 Feast'},
            ],
          },
        );
      }
      return;
    }
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

    final activeReminders = reminders.where((r) => r.isEnabled).toList();
    activeReminders.sort((a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute));

    int scheduledCount = 0;
    for (var reminder in reminders) {
      if (!reminder.isEnabled) continue;

      final now = DateTime.now();
      final reminderTimeToday = DateTime(now.year, now.month, now.day, reminder.hour, reminder.minute);

      int startYear = now.year;
      int startMonth = now.month;
      int startDay = now.day;

      if (now.isAfter(reminderTimeToday)) {
        final tomorrow = now.add(const Duration(days: 1));
        startYear = tomorrow.year;
        startMonth = tomorrow.month;
        startDay = tomorrow.day;
      } else {
        final int index = activeReminders.indexOf(reminder);
        DateTime intervalStart;
        if (activeReminders.length > 1) {
          if (index > 0) {
            final prev = activeReminders[index - 1];
            intervalStart = DateTime(now.year, now.month, now.day, prev.hour, prev.minute);
          } else {
            final prev = activeReminders.last;
            final yesterday = now.subtract(const Duration(days: 1));
            intervalStart = DateTime(yesterday.year, yesterday.month, yesterday.day, prev.hour, prev.minute);
          }
        } else {
          final yesterday = now.subtract(const Duration(days: 1));
          intervalStart = DateTime(yesterday.year, yesterday.month, yesterday.day, reminder.hour, reminder.minute);
        }

        bool hasMealInInterval = false;
        if (intervalStart.isBefore(now)) {
          final db = AppDatabase.getInstance();
          final events = await db.getEventsInDateRange(intervalStart, now);
          hasMealInInterval = events.any((e) =>
              e.category == EventCategory.nutrition && e.label == 'core_meal_count');
        }

        if (hasMealInInterval) {
          debugPrint('[NotificationService] Meal already logged in interval for ${reminder.label}. Rescheduling to tomorrow.');
          final tomorrow = now.add(const Duration(days: 1));
          startYear = tomorrow.year;
          startMonth = tomorrow.month;
          startDay = tomorrow.day;
        }
      }

      // Stable ID in the 1.0B - 1.5B range to prevent collisions and signed 32-bit overflow
      final notificationId = (reminder.id.hashCode.abs() % 500000000) + 1000000000;
      debugPrint('[NotificationService] Scheduling meal reminder ${reminder.label} (ID: $notificationId) at ${reminder.hour}:${reminder.minute} starting on $startYear-$startMonth-$startDay');

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
            year: startYear,
            month: startMonth,
            day: startDay,
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
              year: startYear,
              month: startMonth,
              day: startDay,
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
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userUuid = prefs.getString('user_uuid') ?? 'unknown_user';
      
      final notificationType = payload?['notification_type'];
      final reminderLabel = payload?['reminder_label'];

      final bool isMeal = notificationType == 'meal_reminder';

      final String title = isMeal
          ? '${reminderLabel ?? 'Meal'} Reminder (Snoozed)'
          : (payload?['window_label'] != null
              ? '${payload!['window_label']} Check-in (Snoozed)'
              : 'Time for a quick update!');

      final String body = isMeal
          ? 'Time to track your meal. What did you have?'
          : 'Please take a moment to record your current status.';

      final scheduledTime = DateTime.now().add(delay ?? const Duration(seconds: 10));

      final snoozeDurations = await getSnoozeDurations();
      final webActions = isMeal
          ? [
              {'action': 'meal_snack', 'title': '🍪 Snack'},
              {'action': 'meal_meal', 'title': '🍲 Meal'},
              {'action': 'meal_feast', 'title': '🍖 Feast'},
            ]
          : snoozeDurations.map((mins) => {
              'action': 'snooze_${mins}m',
              'title': '+ ${_formatDurationLabel(mins)}',
            }).toList();

      await _scheduleWebPush(
        userUuid: userUuid,
        scheduledFor: scheduledTime,
        payload: {
          'title': title,
          'body': body,
          'data': payload ?? {'metric_id': 'default'},
          'actions': webActions,
        },
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
        ? ((windowId.hashCode.abs() % 500000000) + 500000000) 
        : (notificationType == 'meal_reminder' && reminderId != null
            ? ((reminderId.hashCode.abs() % 500000000) + 1500000000)
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

    final String localTimeZone = await AwesomeNotifications().getLocalTimeZoneIdentifier();
    final targetDate = DateTime.now().add(delay ?? const Duration(seconds: 10));

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
        schedule: NotificationCalendar(
          year: targetDate.year,
          month: targetDate.month,
          day: targetDate.day,
          hour: targetDate.hour,
          minute: targetDate.minute,
          second: targetDate.second,
          timeZone: localTimeZone,
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
          schedule: NotificationCalendar(
            year: targetDate.year,
            month: targetDate.month,
            day: targetDate.day,
            hour: targetDate.hour,
            minute: targetDate.minute,
            second: targetDate.second,
            timeZone: localTimeZone,
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

  // ===========================================================================
  // PWA Web Push Helper Methods
  // ===========================================================================

  static Future<void> _scheduleWebPush({
    required String userUuid,
    required DateTime scheduledFor,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final data = Map<String, dynamic>.from(payload['data'] ?? {});
      data['user_uuid'] = userUuid;
      data['supabase_url'] = SupabaseConfig.supabaseUrl;
      data['supabase_anon_key'] = SupabaseConfig.supabaseAnonKey;
      if (payload.containsKey('actions')) {
        data['actions'] = payload['actions'];
      }
      payload['data'] = data;

      final String? subscriptionJson = await PwaPushInterop.subscribe(SupabaseConfig.vapidPublicKey);
      if (subscriptionJson == null) {
        debugPrint('[NotificationService] Failed to schedule Web Push: Not subscribed or permission denied.');
        return;
      }
      final subscription = jsonDecode(subscriptionJson);

      // Insert the notification task into public.pwa_push_reminders
      await Supabase.instance.client.from('pwa_push_reminders').insert({
        'user_uuid': userUuid,
        'subscription': subscription,
        'scheduled_for': scheduledFor.toUtc().toIso8601String(),
        'payload': payload,
        'sent': false,
      });
      debugPrint('[NotificationService] Scheduled Web Push for $scheduledFor');
    } catch (e) {
      debugPrint('[NotificationService] Error scheduling Web Push: $e');
    }
  }

  static Future<void> _clearWebPushes(String userUuid) async {
    try {
      await Supabase.instance.client
          .from('pwa_push_reminders')
          .delete()
          .eq('user_uuid', userUuid)
          .eq('sent', false);
      debugPrint('[NotificationService] Cleared future Web Pushes for $userUuid');
    } catch (e) {
      debugPrint('[NotificationService] Error clearing Web Pushes: $e');
    }
  }

  static Future<void> processWebPushQueue() async {
    if (!kIsWeb) return;
    try {
      final eventsJson = await PwaPushInterop.getQueuedEvents();
      if (eventsJson == null || eventsJson == '[]' || eventsJson.isEmpty) {
        return;
      }
      debugPrint('[NotificationService] Processing PWA queued events: $eventsJson');
      final List<dynamic> list = jsonDecode(eventsJson);
      final db = AppDatabase.getInstance();
      
      for (final event in list) {
        final type = event['type'];
        final timestampStr = event['timestamp'];
        final timestamp = timestampStr != null ? DateTime.parse(timestampStr) : DateTime.now();

        if (type == 'interaction') {
          final interactionTypeStr = event['interactionType'];
          final interactionType = InteractionType.values.firstWhere(
            (e) => e.name == interactionTypeStr,
            orElse: () => InteractionType.click,
          );
          final payload = event['payload'] != null ? Map<String, String?>.from(event['payload']) : null;
          final value = event['value']?.toString();
          
          await _logInteraction(
            db,
            interactionType,
            payload,
            value: value,
          );

          if (interactionType == InteractionType.swipeAway) {
            if (payload?['notification_type'] != 'meal_reminder') {
              await _incrementAndCheckDismissCount();
            }
          }
        } else if (type == 'meal') {
          final value = event['value'] ?? '1.0';
          await db.insertEvent(
            EventsCompanion(
              category: const Value(EventCategory.nutrition),
              label: const Value('core_meal_count'),
              value: Value(value),
              latencyMs: const Value(0),
              triggerSource: const Value(TriggerSource.notification),
              interactionType: const Value(InteractionType.click),
              timestamp: Value(timestamp),
              recordedAt: Value(timestamp),
            ),
          );
          await scheduleMealReminders();
        }
      }
      
      await PwaPushInterop.clearQueuedEvents();
      debugPrint('[NotificationService] PWA queued events cleared.');
    } catch (e) {
      debugPrint('[NotificationService] Error processing Web Push Queue: $e');
    }
  }
}
