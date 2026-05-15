import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/models/metric_definition.dart';
import '../data/metric_presets.dart';
import 'notification_service.dart';

/// Prefix for core-metric toggle keys in [SharedPreferences].
const _kCoreMetricPrefix = 'core_metric_enabled_';

/// Prefix for core-metric window keys in [SharedPreferences].
const _kCoreMetricWindowPrefix = 'core_metric_window_';

/// Sentinel used in [MetricService.updateMetric] to distinguish
/// "retroReliableOverride not passed" from explicitly setting it to null.
const _kUnset = Object();

/// Serializes a list of window IDs for DB storage.
/// An empty list becomes '_none_' (Quick Log Only sentinel).
String _serializeWindowIds(List<String> ids) =>
    ids.isEmpty ? '_none_' : ids.join(',');

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
  static List<MetricDefinition> get templates => MetricPresets.metricTemplates;

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

  /// Calculates the exact target time (midpoint) for a window, adjusting for overnight
  /// and previous-day misses.
  DateTime getWindowTargetTime(DateTime now, TrackingWindow window) {
    int startMinutes = window.startHour * 60 + window.startMinute;
    int endMinutes = window.endHour * 60 + window.endMinute;
    
    if (startMinutes <= endMinutes) {
      // Normal window
      final midHour = (window.startHour + window.endHour) ~/ 2;
      final midMinute = (window.startMinute + window.endMinute) ~/ 2;
      var target = now.copyWith(hour: midHour, minute: midMinute, second: 0, millisecond: 0, microsecond: 0);
      
      // If the target is in the future, it means the window we are referring to was yesterday.
      if (target.isAfter(now)) {
        target = target.subtract(const Duration(days: 1));
      }
      return target;
    } else {
      // Overnight window (e.g. 22:00 to 05:00)
      // Duration = (24*60 - startMinutes) + endMinutes
      int duration = (1440 - startMinutes) + endMinutes;
      int midPointMinutes = startMinutes + (duration ~/ 2);
      
      int targetHour = (midPointMinutes ~/ 60) % 24;
      int targetMinute = midPointMinutes % 60;
      
      var target = now.copyWith(hour: targetHour, minute: targetMinute, second: 0, millisecond: 0, microsecond: 0);
      
      if (target.isAfter(now)) {
        target = target.subtract(const Duration(days: 1));
      }
      return target;
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
      for (final s in MetricPresets.windowPresets) {
        try {
          await _db.insertTrackingWindow(
            TrackingWindowsCompanion.insert(
              label: s.label,
              startHour: s.startHour,
              startMinute: s.startMinute,
              endHour: s.endHour,
              endMinute: s.endMinute,
              isNotificationEnabled: const Value(true),
              notificationHour: s.notificationHour ?? s.startHour,
              notificationMinute: s.notificationMinute ?? s.startMinute,
              isEnabled: Value(s.isEnabled),
            ),
          );
        } catch (e) {
          debugPrint('[MetricService] Error seeding window ${s.label}: $e');
        }
      }
      await prefs.setBool('tracking_windows_seeded', true);
      debugPrint('[MetricService] Seeded ${MetricPresets.windowPresets.length} sample tracking windows');
    } else if (!windowsSeeded) {
      // Handle restore scenario: Data exists but pref is false
      await prefs.setBool('tracking_windows_seeded', true);
    }

    // --- MIGRATION: Sync existing windows notification time ---
    final migrationKey = 'notif_sync_v1';
    if (!(prefs.getBool(migrationKey) ?? false)) {
      final windows = await _db.getAllTrackingWindows();
      for (var w in windows) {
        if (w.notificationHour != w.startHour || w.notificationMinute != w.startMinute) {
          await _db.updateTrackingWindow(
            w.id,
            TrackingWindowsCompanion(
              notificationHour: Value(w.startHour),
              notificationMinute: Value(w.startMinute),
            ),
          );
        }
      }
      await prefs.setBool(migrationKey, true);
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
              isActivityIndicator: Value(m.isActivityIndicator),
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

    // --- SOFT MIGRATION: Inject missing core metrics for existing users ---
    final syncKey = 'core_metrics_v4_sync';
    if (!(prefs.getBool(syncKey) ?? false)) {
      final currentMetricIds = _allMetrics.map((m) => m.id).toSet();
      int addedCount = 0;
      
      for (final template in templates) {
        if (!currentMetricIds.contains(template.id)) {
          try {
            await _db.insertCustomMetric(
              CustomMetricsCompanion.insert(
                id: Value(template.id),
                label: template.label,
                category: template.category,
                inputType: template.inputType,
                isEnabled: Value(template.isEnabled),
                windowIds: Value(template.windowIds.join(',')),
                emoji: Value(template.emoji),
                isActivityIndicator: Value(template.isActivityIndicator),
              ),
            );
            addedCount++;
          } catch (e) {
            debugPrint('[MetricService] Error injecting missing metric ${template.id}: $e');
          }
        }
      }
      
      if (addedCount > 0) {
        debugPrint('[MetricService] Soft Migration: Injected $addedCount new research metrics');
        await _reload(); // Refresh to include new metrics
      }
      await prefs.setBool(syncKey, true);
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
      // '_none_' is a sentinel stored in the DB to mean "Quick Log Only" — 
      // the metric has no window assignments and only appears in manual Quick Log.
      // An empty string is legacy data and defaults to 'anytime' for backward compat.
      final List<String> windowIds;
      if (rawWindows == '_none_') {
        windowIds = [];
      } else if (rawWindows.isEmpty) {
        windowIds = ['anytime'];
      } else {
        windowIds = rawWindows.split(',').where((s) => s.isNotEmpty).toList();
      }

      return MetricDefinition(
        id: row.id,
        label: row.label,
        category: row.category,
        inputType: row.inputType,
        isEnabled: row.isEnabled,
        windowIds: windowIds,
        emoji: row.emoji,
        isActivityIndicator: row.isActivityIndicator,
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

  /// Sets whether a metric counts towards the activity streak.
  Future<void> setMetricActivityIndicator(String id, bool isActivityIndicator) async {
    final index = _allMetrics.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final metric = _allMetrics[index];
    
    await _db.updateCustomMetric(
      id,
      CustomMetricsCompanion(isActivityIndicator: Value(isActivityIndicator)),
    );

    _allMetrics[index] = metric.copyWith(isActivityIndicator: isActivityIndicator);
    notifyListeners();
    debugPrint('[MetricService] Set activity indicator for "${metric.label}" → $isActivityIndicator');
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
    final windowIdsString = _serializeWindowIds(windowIds);

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
    bool isActivityIndicator = true,
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
        windowIds: Value(_serializeWindowIds(windowIds)),
        emoji: Value(emoji),
        isActivityIndicator: Value(isActivityIndicator),
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
    bool? isActivityIndicator,
    Object? retroReliableOverride = _kUnset,
  }) async {
    await _db.updateCustomMetric(
      id,
      CustomMetricsCompanion(
        label: Value(label),
        category: Value(category),
        inputType: Value(inputType),
        windowIds: Value(_serializeWindowIds(windowIds)),
        emoji: Value(emoji),
        isActivityIndicator: isActivityIndicator == null 
            ? const Value.absent()
            : Value(isActivityIndicator),
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
        notificationHour: Value(notificationHour ?? startHour),
        notificationMinute: Value(notificationMinute ?? startMinute),
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
            windowIds: Value(_serializeWindowIds(newWindowIds)),
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

  /// Bulk-enables/disables metrics based on a research preset.
  Future<void> applyPreset(ResearchPreset preset) async {
    final Map<ResearchPreset, List<String>> presetMap = {
      ResearchPreset.essential: [
        'core_mood', 'core_energy', 'core_sleep_quality', 'core_wellbeing'
      ],
      ResearchPreset.fullCircadian: [
        'core_mood', 'core_energy', 'core_stress', 'core_wellbeing',
        'core_sleep_quality', 'core_nap_duration', 'core_light_exposure', 'core_meal_count',
        'core_weather_rain', 'core_weather_sun', 'core_weather_wind', 'core_outside',
        'core_prompt_burden'
      ],
      ResearchPreset.productivity: [
        'core_focus', 'e4a45a3d-a994-4ec8-be8c-fdf0ad511910', 'core_screen_mindless', 'core_journaling'
      ],
      ResearchPreset.healthHabits: [
        'core_sleep_quality', 'core_nap_duration', '3a4d43d5-7459-481e-bf3c-97e725fa3105',
        'core_headache', 'core_toilet_urge', 'core_coffee_intake', 'core_water_intake',
        'core_alcohol_intake', 'core_sport', 'core_meditation'
      ],
    };

    final List<String> targetIds;
    if (preset == ResearchPreset.allInclusive) {
      targetIds = _allMetrics.map((m) => m.id).toList();
    } else {
      targetIds = presetMap[preset] ?? [];
    }
    
    // 1. Disable all currently active metrics (to start from a clean slate)
    for (var m in _allMetrics) {
      if (m.isEnabled) {
        await _db.setCustomMetricEnabled(m.id, false);
      }
    }

    // 2. Enable target metrics
    for (var id in targetIds) {
      await _db.setCustomMetricEnabled(id, true);
    }

    // 3. Log the change as a meta event
    try {
      await _db.insertEvent(
        EventsCompanion(
          category: const Value(EventCategory.meta),
          label: const Value('research_preset_applied'),
          value: Value(preset.name),
          triggerSource: const Value(TriggerSource.manual),
          interactionType: const Value(InteractionType.click),
          sessionId: Value(const Uuid().v4()),
        ),
      );
    } catch (e) {
      debugPrint('[MetricService] Error logging research_preset_applied: $e');
    }

    await _reload();
    debugPrint('[MetricService] Applied research preset: ${preset.name}');
  }
}
