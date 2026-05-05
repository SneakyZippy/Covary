import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/metric_definition.dart';
import 'notification_service.dart';

/// Prefix for core-metric toggle keys in [SharedPreferences].
const _kCoreMetricPrefix = 'core_metric_enabled_';

/// Prefix for core-metric window keys in [SharedPreferences].
const _kCoreMetricWindowPrefix = 'core_metric_window_';

/// Sentinel used in [MetricService.updateMetric] to distinguish
/// "retroReliableOverride not passed" from explicitly setting it to null.
const _kUnset = Object();

/// Service that manages all metric definitions (core + custom).
///
/// Core metrics are hard-coded with their enabled/disabled state persisted
/// in [SharedPreferences]. Custom metrics live in the [CustomMetrics] Drift
/// table. This service merges both into a single list for the UI.
///
/// The Home screen reads [activeMetrics] (only enabled ones).
/// The Settings screen reads [allMetrics] (everything).
class MetricService extends ChangeNotifier {
  late AppDatabase _db;

  /// Merged list of all metrics (core + custom), cached in memory.
  List<MetricDefinition> _allMetrics = [];

  /// User-defined tracking windows.
  List<TrackingWindow> _allWindows = [];

  // ---------------------------------------------------------------------------
  // Core metric templates (from the research methodology)
  // ---------------------------------------------------------------------------

  /// The core metrics as specified in the thesis research plan.
  ///
  /// These can be toggled on/off. Custom metrics can also be added.
  static const List<MetricDefinition> templates = [
    // --- Mood & State (Frequency: All windows) ---
    MetricDefinition(
      id: 'core_mood',
      label: 'Current Mood',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'sentiment_satisfied',
    ),
    MetricDefinition(
      id: 'core_energy',
      label: 'Energy Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'bolt',
    ),
    MetricDefinition(
      id: 'core_stress',
      label: 'Stress Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'psychology',
    ),
    
    // --- Health (Frequency: Morning) ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'bedtime',
    ),

    // --- Behavior & Wellbeing (Frequency: Evening Review) ---
    MetricDefinition(
      id: 'core_wellbeing',
      label: 'General Wellbeing',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: true,
      emoji: 'star',
    ),
    MetricDefinition(
      id: 'core_sport',
      label: 'Physical Activity',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'run',
    ),
    MetricDefinition(
      id: 'core_meditation',
      label: 'Mindfulness / Meditation',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'meditation',
    ),
    MetricDefinition(
      id: 'core_journaling',
      label: 'Journaling',
      category: EventCategory.behavior,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'edit',
    ),
    MetricDefinition(
      id: 'core_good_deed',
      label: 'Good Deed',
      category: EventCategory.social,
      inputType: MetricInputType.yesNo,
      isEnabled: true,
      emoji: 'favorite',
    ),

    // --- Optional/Secondary (Disabled by default to reduce clutter) ---
    MetricDefinition(
      id: 'core_focus',
      label: 'Focus',
      category: EventCategory.productivity,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'lightbulb',
    ),
    MetricDefinition(
      id: 'core_anxiety',
      label: 'Anxiety',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to10,
      isEnabled: false,
      emoji: 'psychology',
    ),
    MetricDefinition(
      id: 'core_coffee_intake',
      label: 'Coffee Intake',
      category: EventCategory.nutrition,
      inputType: MetricInputType.counter,
      isEnabled: true,
      emoji: 'coffee',
      windowIds: ['homescreen'],
    ),
  ];

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// All metrics (core + custom), in display order.
  List<MetricDefinition> get allMetrics => List.unmodifiable(_allMetrics);

  /// All tracking windows.
  List<TrackingWindow> get allWindows => List.unmodifiable(_allWindows);

  /// Returns the first tracking window that is currently active (if any).
  TrackingWindow? get activeWindow {
    final now = DateTime.now();
    try {
      return _allWindows.firstWhere((w) => w.isEnabled && isTimeInWindow(now, w));
    } catch (_) {
      return null;
    }
  }

  /// Only metrics that are currently enabled AND applicable at the given [time].
  List<MetricDefinition> activeMetricsAt(DateTime time) {
    return _allMetrics.where((m) {
      if (!m.isEnabled) return false;
      if (m.windowIds.contains('anytime')) return true;
      if (m.windowIds.isEmpty) return false; // Not assigned to any window

      // Check if current time falls within any of the assigned windows
      return _allWindows.any((window) {
        if (!window.isEnabled) return false; // Skip disabled windows
        if (!m.windowIds.contains(window.id)) return false;
        return isTimeInWindow(time, window);
      });
    }).toList();
  }

  /// Default active metrics (at current time).
  List<MetricDefinition> get activeMetrics => activeMetricsAt(DateTime.now());

  bool isTimeInWindow(DateTime time, TrackingWindow window) {
    final nowMinutes = time.hour * 60 + time.minute;
    final startMinutes = window.startHour * 60 + window.startMinute;
    final endMinutes = window.endHour * 60 + window.endMinute;

    if (startMinutes < endMinutes) {
      // Normal range: 08:00 - 10:00
      return nowMinutes >= startMinutes && nowMinutes < endMinutes;
    } else if (startMinutes > endMinutes) {
      // Overnight range: 22:00 - 05:00
      return nowMinutes >= startMinutes || nowMinutes < endMinutes;
    } else {
      // Start == End: Treated as a 24h window
      return true;
    }
  }

  /// Returns true if the window has already passed for the given [time].
  /// Handles overnight windows correctly.
  bool hasWindowPassed(DateTime time, TrackingWindow window) {
    final nowMinutes = time.hour * 60 + time.minute;
    final startMinutes = window.startHour * 60 + window.startMinute;
    final endMinutes = window.endHour * 60 + window.endMinute;

    if (startMinutes <= endMinutes) {
      // Normal range (or 24h window which never passes)
      if (startMinutes == endMinutes) return false; 
      return nowMinutes >= endMinutes;
    } else {
      // Overnight range: 22:00 - 05:00
      // It has "passed" if it's after end AND before start
      return nowMinutes >= endMinutes && nowMinutes < startMinutes;
    }
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Loads core metric toggle states from SharedPreferences and
  /// Initializes the service by loading and seeding (if necessary) windows and 
  /// metrics from the Drift database, then merges them.
  Future<void> init(AppDatabase db) async {
    _db = db;
    final prefs = await SharedPreferences.getInstance();
    
    // --- Seed Tracking Windows ---
    final existingWindows = await _db.getAllTrackingWindows();
    final windowsSeeded = prefs.getBool('tracking_windows_seeded') ?? false;
    
    if (!windowsSeeded && existingWindows.isEmpty) {
      final samples = [
        ('Early Morning', 7, 0, 9, 0, 7, 30, true),
        ('Late Morning', 10, 0, 12, 0, 10, 30, false),
        ('Afternoon Sync', 14, 0, 16, 0, 14, 30, true),
        ('Evening Review', 19, 0, 21, 0, 19, 30, false),
        ('Night/Bedtime', 22, 0, 0, 0, 22, 30, true),
      ];

      for (final s in samples) {
        try {
          await _db.insertTrackingWindow(
            TrackingWindowsCompanion.insert(
              label: s.$1,
              startHour: s.$2,
              startMinute: s.$3,
              endHour: s.$4,
              endMinute: s.$5,
              isNotificationEnabled: const Value(true),
              notificationHour: s.$6,
              notificationMinute: s.$7,
              isEnabled: Value(s.$8),
            ),
          );
        } catch (e) {
          debugPrint('[MetricService] Error seeding window ${s.$1}: $e');
        }
      }
      await prefs.setBool('tracking_windows_seeded', true);
      debugPrint('[MetricService] Seeded 5 sample tracking windows');
    } else if (!windowsSeeded) {
      // Handle restore scenario: Data exists but pref is false
      await prefs.setBool('tracking_windows_seeded', true);
    }

    // --- Seed Metrics ---
    final existingMetrics = await _db.getAllCustomMetrics();
    final hasSeeded = prefs.getBool('core_metrics_seeded') ?? false;
    
    if (!hasSeeded && existingMetrics.isEmpty) {
      // Seed default metrics if first launch
      for (final m in templates) {
        try {
          // Support legacy prefix for migration if needed, but here we just seed new ones
          final legacyPrefKey = 'core_habit_enabled_${m.id}';
          final prefKey = '$_kCoreMetricPrefix${m.id}';
          
          final enabled = prefs.getBool(legacyPrefKey) ?? prefs.getBool(prefKey) ?? m.isEnabled;
          
          final legacyWindowKey = 'core_habit_frequency_${m.id}';
          final windowKey = '$_kCoreMetricWindowPrefix${m.id}';
          final windowIdsString = prefs.getString(legacyWindowKey) ?? prefs.getString(windowKey);
          
          List<String> windowIds = m.windowIds;
          if (windowIdsString != null) {
            windowIds = windowIdsString.split(',').where((s) => s.isNotEmpty).toList();
          }

          await _db.insertCustomMetric(
            CustomMetricsCompanion.insert(
              id: Value(m.id),
              label: m.label,
              category: m.category,
              inputType: m.inputType,
              isEnabled: Value(enabled),
              windowIds: Value(windowIds.join(',')),
              emoji: Value(m.emoji),
            ),
          );
        } catch (e) {
          debugPrint('[MetricService] Error seeding metric ${m.id}: $e');
        }
      }
      await prefs.setBool('core_metrics_seeded', true);
    } else if (!hasSeeded) {
      // Handle restore scenario
      await prefs.setBool('core_metrics_seeded', true);
    }

    // Note: We no longer auto-re-insert missing core metrics here.
    // This allows the user to delete any metric permanently, treating
    // "core" and "custom" metrics as equal entities.
    // Syncing of categories/reliability is also removed to respect user edits.
    
    // --- Final Polish: Distribute metrics if this was a fresh seed ---
    if (!hasSeeded && !windowsSeeded) {
      try {
        final windows = await _db.getAllTrackingWindows();
        final morningId = windows.firstWhere((w) => w.label.contains('Early Morning')).id;
        final eveningId = windows.firstWhere((w) => w.label.contains('Evening Review')).id;
        final nightId = windows.firstWhere((w) => w.label.contains('Night/Bedtime')).id;

        // Assign Sleep to Morning
        await _db.updateCustomMetric('core_sleep_quality', CustomMetricsCompanion(windowIds: Value(morningId)));
        
        // Assign Reflection/Habits to Evening & Night
        final reflectionMetrics = ['core_wellbeing', 'core_sport', 'core_meditation', 'core_journaling', 'core_good_deed'];
        for (final mId in reflectionMetrics) {
          await _db.updateCustomMetric(mId, CustomMetricsCompanion(windowIds: Value('$eveningId,$nightId')));
        }
        debugPrint('[MetricService] Research-Ready distribution applied to metrics');
      } catch (e) {
        debugPrint('[MetricService] Could not auto-distribute metrics: $e');
      }
    }

    await _reload();
    debugPrint(
      '[MetricService] Initialized with ${_allMetrics.length} metrics '
      '(${activeMetrics.length} active)',
    );
    notifyListeners();
  }

  /// Reloads all metric data from persistence and rebuilds [_allMetrics].
  Future<void> _reload() async {
    final prefs = await SharedPreferences.getInstance();

    // --- Windows from Drift ---
    _allWindows = await _db.getAllTrackingWindows();

    final windowOrder = prefs.getStringList('tracking_windows_sort_order');
    if (windowOrder != null) {
      _allWindows.sort((a, b) {
        int indexA = windowOrder.indexOf(a.id);
        int indexB = windowOrder.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }

    // --- All metrics from Drift ---
    final customRows = await _db.getAllCustomMetrics();
    final customMetrics = customRows.map((row) {
      final rawWindows = row.windowIds;
      final windowIds = (rawWindows.isEmpty) 
          ? ['anytime'] 
          : rawWindows.split(',').where((s) => s.isNotEmpty).toList();

      return MetricDefinition(
        id: row.id,
        label: row.label,
        category: row.category,
        inputType: row.inputType,
        isEnabled: row.isEnabled,
        windowIds: windowIds,
        emoji: row.emoji,
        retroReliableOverride: row.isRetroReliable,
      );
    }).toList();

    _allMetrics = [...customMetrics];

    final savedOrder = prefs.getStringList('metric_sort_order');
    if (savedOrder != null) {
      _allMetrics.sort((a, b) {
        int indexA = savedOrder.indexOf(a.id);
        int indexB = savedOrder.indexOf(b.id);
        if (indexA == -1 && indexB == -1) return 0;
        if (indexA == -1) return 1;
        if (indexB == -1) return -1;
        return indexA.compareTo(indexB);
      });
    }

    notifyListeners();
  }


  // ---------------------------------------------------------------------------
  // Sorting
  // ---------------------------------------------------------------------------

  /// Updates the order of metrics and persists it to SharedPreferences.
  Future<void> reorderMetrics(int oldIndex, int newIndex, {List<MetricDefinition>? currentList}) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    if (oldIndex == newIndex) return;

    final listToReorder = currentList ?? _allMetrics;
    final item = listToReorder[oldIndex];

    if (currentList == null || identical(currentList, _allMetrics)) {
      _allMetrics.removeAt(oldIndex);
      _allMetrics.insert(newIndex, item);
    } else {
      // Filtered reorder: Move item in global list relative to its neighbors in the filtered list
      _allMetrics.remove(item);

      if (newIndex < listToReorder.length) {
        final targetItem = listToReorder[newIndex];
        final targetGlobalIdx = _allMetrics.indexOf(targetItem);
        
        // If moving down (oldIndex < original newIndex), place it AFTER the target
        // If moving up (oldIndex > original newIndex), place it BEFORE the target
        // Note: targetGlobalIdx is already shifted because we removed 'item'
        if (oldIndex < newIndex) {
          _allMetrics.insert(targetGlobalIdx + 1, item);
        } else {
          _allMetrics.insert(targetGlobalIdx, item);
        }
      } else {
        // Fallback for end of list
        final lastItem = listToReorder.last;
        final lastGlobalIdx = _allMetrics.indexOf(lastItem);
        _allMetrics.insert(lastGlobalIdx + 1, item);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final newOrder = _allMetrics.map((m) => m.id).toList();
    await prefs.setStringList('metric_sort_order', newOrder);
    
    notifyListeners();
  }

  /// Updates the order of tracking windows and persists it to SharedPreferences.
  Future<void> reorderTrackingWindows(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _allWindows.removeAt(oldIndex);
    _allWindows.insert(newIndex, item);

    final prefs = await SharedPreferences.getInstance();
    final newOrder = _allWindows.map((w) => w.id).toList();
    await prefs.setStringList('tracking_windows_sort_order', newOrder);

    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Toggle
  // ---------------------------------------------------------------------------

  /// Enables or disables a metric by [id].
  Future<void> toggleMetric(String id) async {
    final index = _allMetrics.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final metric = _allMetrics[index];
    final newEnabled = !metric.isEnabled;

    await _db.setCustomMetricEnabled(id, newEnabled);

    _allMetrics[index] = metric.copyWith(isEnabled: newEnabled);
    notifyListeners();
    debugPrint('[MetricService] Toggled "${metric.label}" → $newEnabled');
  }
 
  /// Enables or disables a tracking window by [id].
  Future<void> toggleTrackingWindow(String id) async {
    final index = _allWindows.indexWhere((w) => w.id == id);
    if (index == -1) return;
 
    final window = _allWindows[index];
    final newEnabled = !window.isEnabled;
 
    await _db.updateTrackingWindow(
      id,
      TrackingWindowsCompanion(isEnabled: Value(newEnabled)),
    );
 
    await _reload(); // Reload to update memory and notify
    debugPrint('[MetricService] Toggled window "${window.label}" → $newEnabled');
  }

  /// Changes the assigned tracking windows for a metric.
  Future<void> changeMetricWindows(
    String id,
    List<String> windowIds,
  ) async {
    final index = _allMetrics.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final metric = _allMetrics[index];
    final windowIdsString = windowIds.join(',');

    await _db.updateCustomMetricWindows(id, windowIdsString);

    _allMetrics[index] = metric.copyWith(windowIds: windowIds);
    notifyListeners();
    debugPrint(
      '[MetricService] Changed windows for "${metric.label}" → $windowIdsString',
    );
  }

  // ---------------------------------------------------------------------------
  // Metric Management
  // ---------------------------------------------------------------------------

  /// Adds a new metric.
  Future<void> addMetric({
    String? id,
    required String label,
    required EventCategory category,
    required MetricInputType inputType,
    List<String> windowIds = const ['anytime'],
    String? emoji,
    bool? retroReliableOverride,
    int latencyMs = 0,
  }) async {
    final metricId = id ?? const Uuid().v4();

    await _db.insertCustomMetric(
      CustomMetricsCompanion(
        id: Value(metricId),
        label: Value(label),
        category: Value(category),
        inputType: Value(inputType),
        isEnabled: const Value(true),
        windowIds: Value(windowIds.join(',')),
        emoji: Value(emoji),
        isRetroReliable: Value(retroReliableOverride),
      ),
    );

    // Log the creation as a meta event for HCI research.
    try {
      await _db.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.meta),
          label: const Value('custom_metric_added'),
          value: Value(label),
          latencyMs: Value(latencyMs),
          triggerSource: const Value(TriggerSource.manual),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(const Uuid().v4()),
        ),
      );
    } catch (e) {
      debugPrint('[MetricService] Error logging custom_metric_added: $e');
    }

    await _reload();
    debugPrint('[MetricService] Added custom metric: "$label" ($inputType)');
  }

  /// Updates an existing metric.
  Future<void> updateMetric({
    required String id,
    required String label,
    required EventCategory category,
    required MetricInputType inputType,
    required List<String> windowIds,
    String? emoji,
    Object? retroReliableOverride = _kUnset,
  }) async {
    await _db.updateCustomMetric(
      id,
      CustomMetricsCompanion(
        label: Value(label),
        category: Value(category),
        inputType: Value(inputType),
        windowIds: Value(windowIds.join(',')),
        emoji: Value(emoji),
        isRetroReliable: retroReliableOverride == _kUnset
            ? const Value.absent()
            : Value(retroReliableOverride as bool?),
      ),
    );
    await _reload();
    debugPrint('[MetricService] Updated custom metric: "$label"');
  }

  // ---------------------------------------------------------------------------
  // Tracking Window Management
  // ---------------------------------------------------------------------------

  /// Adds a new tracking window.
  Future<void> addTrackingWindow({
    required String label,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    bool isNotificationEnabled = false,
    int? notificationHour,
    int? notificationMinute,
  }) async {
    await _db.insertTrackingWindow(
      TrackingWindowsCompanion.insert(
        label: label,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        isNotificationEnabled: Value(isNotificationEnabled),
        notificationHour: notificationHour ?? startHour,
        notificationMinute: notificationMinute ?? startMinute,
      ),
    );
    await _reload();
    await NotificationService.scheduleDailyReminders();
  }

  /// Updates a tracking window.
  Future<void> updateTrackingWindow(
    String id, {
    required String label,
    required int startHour,
    required int startMinute,
    required int endHour,
    required int endMinute,
    bool? isNotificationEnabled,
    int? notificationHour,
    int? notificationMinute,
  }) async {
    await _db.updateTrackingWindow(
      id,
      TrackingWindowsCompanion(
        label: Value(label),
        startHour: Value(startHour),
        startMinute: Value(startMinute),
        endHour: Value(endHour),
        endMinute: Value(endMinute),
        isNotificationEnabled: isNotificationEnabled != null
            ? Value(isNotificationEnabled)
            : const Value.absent(),
        notificationHour: notificationHour != null
            ? Value(notificationHour)
            : const Value.absent(),
        notificationMinute: notificationMinute != null
            ? Value(notificationMinute)
            : const Value.absent(),
      ),
    );
    await _reload();
    await NotificationService.scheduleDailyReminders();
  }

  /// Sets exactly which metrics should be tracked in a given window.
  Future<void> setMetricsForWindow(String windowId, List<String> metricIds) async {
    for (var m in _allMetrics) {
      final newWindowIds = List<String>.from(m.windowIds);
      final shouldBeInWindow = metricIds.contains(m.id);
      final currentlyInWindow = newWindowIds.contains(windowId);

      bool changed = false;
      if (shouldBeInWindow && !currentlyInWindow) {
        newWindowIds.add(windowId);
        changed = true;
      } else if (!shouldBeInWindow && currentlyInWindow) {
        newWindowIds.remove(windowId);
        changed = true;
      }

      if (changed) {
        await _db.updateCustomMetric(
          m.id,
          CustomMetricsCompanion(
            windowIds: Value(newWindowIds.join(',')),
          ),
        );
      }
    }
    await _reload();
  }

  /// Deletes a tracking window.
  Future<void> deleteTrackingWindow(String id) async {
    await _db.deleteTrackingWindow(id);
    await _reload();
    await NotificationService.scheduleDailyReminders();
  }

  /// Deletes a metric by [id].
  Future<void> deleteMetric(String id) async {
    final metric = _allMetrics.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError('Metric "$id" not found'),
    );

    debugPrint('[MetricService] Deleting metric: "${metric.label}" (ID: $id)');
    await _db.deleteCustomMetric(id);

    // Log the deletion as a meta event.
    try {
      await _db.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.meta),
          label: const Value('custom_metric_deleted'),
          value: Value(metric.label),
          triggerSource: const Value(TriggerSource.manual),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(const Uuid().v4()),
        ),
      );
    } catch (e) {
      debugPrint('[MetricService] Error logging custom_metric_deleted: $e');
    }

    await _reload();
    debugPrint('[MetricService] Successfully deleted metric: "${metric.label}"');
  }

  /// DEBUG ONLY: Deletes all metrics and tracking windows, 
  /// clears seeding flags, and re-initializes with defaults.
  Future<void> debugResetMetrics() async {
    debugPrint('[MetricService] DANGER: debugResetMetrics() called. Wiping ALL definitions.');
    // 1. Clear database tables
    await _db.clearAllMetrics();
    await _db.clearAllTrackingWindows();

    // 2. Clear SharedPreferences flags and sort orders
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('tracking_windows_seeded');
    await prefs.remove('core_metrics_seeded');
    await prefs.remove('metric_sort_order');
    await prefs.remove('tracking_windows_sort_order');
    
    // 3. Re-initialize
    await init(_db);

    // 4. Reschedule notifications
    await NotificationService.scheduleDailyReminders();
    
    debugPrint('[MetricService] Debug Reset: All metrics and windows cleared and re-seeded');
  }
}
