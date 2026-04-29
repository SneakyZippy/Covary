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

/// Sentinel used in [MetricService.updateCustomMetric] to distinguish
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
  late final AppDatabase _db;

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
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      emoji: 'sentiment_satisfied',
    ),
    MetricDefinition(
      id: 'core_energy',
      label: 'Energy Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      emoji: 'bolt',
    ),
    MetricDefinition(
      id: 'core_stress',
      label: 'Stress Level',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to5,
      isEnabled: true,
      emoji: 'psychology',
    ),
    
    // --- Health (Frequency: Morning) ---
    MetricDefinition(
      id: 'core_sleep_quality',
      label: 'Sleep Quality',
      category: EventCategory.health,
      inputType: MetricInputType.scale1to5,
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
      inputType: MetricInputType.scale1to5,
      isEnabled: false,
      emoji: 'lightbulb',
    ),
    MetricDefinition(
      id: 'core_anxiety',
      label: 'Anxiety',
      category: EventCategory.mood,
      inputType: MetricInputType.scale1to5,
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

  /// All core template IDs — derived from [templates] so it never goes stale.
  static final Set<String> coreTemplateIds =
      Set<String>.unmodifiable(templates.map((t) => t.id));

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
      return _allWindows.firstWhere((w) => isTimeInWindow(now, w));
    } catch (_) {
      return null;
    }
  }

  /// Only metrics that are currently enabled AND applicable at the given [time].
  List<MetricDefinition> activeMetricsAt(DateTime time) {
    return _allMetrics.where((m) {
      if (!m.isEnabled) return false;
      if (m.windowIds.contains('anytime')) return true;
      if (m.windowIds.isEmpty) return true;

      // Check if current time falls within any of the assigned windows
      return _allWindows.any((window) {
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
  /// custom metrics from the Drift database, then merges them.
  Future<void> init(AppDatabase db) async {
    _db = db;
    
    final prefs = await SharedPreferences.getInstance();
    
    // --- Seed Tracking Windows ---
    final windowsSeeded = prefs.getBool('tracking_windows_seeded') ?? false;
    if (!windowsSeeded) {
      final samples = [
        ('Morning Reflection', 8, 0, 10, 0, 8, 30),
        ('Afternoon Sync', 13, 0, 15, 0, 13, 30),
        ('Evening Review', 20, 0, 22, 0, 20, 30),
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
            ),
          );
        } catch (e) {
          debugPrint('[MetricService] Error seeding window ${s.$1}: $e');
        }
      }
      await prefs.setBool('tracking_windows_seeded', true);
      debugPrint('[MetricService] Seeded 3 sample tracking windows');
    }

    // --- Seed Core Metrics ---
    final hasSeeded = prefs.getBool('core_metrics_seeded') ?? false;
    
    if (!hasSeeded) {
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
    }

    // --- Ensure Consistency & Reliability ---
    // We re-sync core metrics to ensure window assignments and categories are correct,
    // especially for behavioral metrics that should only appear in the evening.
    final currentWindows = await _db.getAllTrackingWindows();
    final morningId = currentWindows.cast<TrackingWindow?>().firstWhere((w) => w?.label == 'Morning Reflection', orElse: () => null)?.id;
    final eveningId = currentWindows.cast<TrackingWindow?>().firstWhere((w) => w?.label == 'Evening Review', orElse: () => null)?.id;

    final existingMetrics = await _db.getAllCustomMetrics();
    final existingIds = existingMetrics.map((m) => m.id).toSet();

    for (final template in templates) {
      if (!existingIds.contains(template.id)) {
        // Metric is in templates but not in DB (newly added core metric)
        List<String> windowIds = template.windowIds;
        if (template.id == 'core_sleep_quality' && morningId != null) {
          windowIds = [morningId];
        } else if (eveningId != null && 
            (template.category == EventCategory.behavior || 
             template.category == EventCategory.social || 
             template.id == 'core_wellbeing')) {
          windowIds = [eveningId];
        }

        await _db.insertCustomMetric(
          CustomMetricsCompanion.insert(
            id: Value(template.id),
            label: template.label,
            category: template.category,
            inputType: template.inputType,
            isEnabled: Value(template.isEnabled),
            windowIds: Value(windowIds.join(',')),
            emoji: Value(template.emoji),
          ),
        );
        debugPrint('[MetricService] Added missing core metric: ${template.id}');
      } else {
        // Metric already exists, ensure it's consistent with template metadata
        final row = existingMetrics.firstWhere((m) => m.id == template.id);
        
        bool needsUpdate = false;
        CustomMetricsCompanion updates = const CustomMetricsCompanion();

        // Sync category
        if (row.category != template.category) {
          updates = updates.copyWith(category: Value(template.category));
          needsUpdate = true;
        }

        // Sync reliability for behavioral metrics
        final shouldBeReliable = template.category == EventCategory.behavior || template.category == EventCategory.social;
        if (shouldBeReliable && row.isRetroReliable != true) {
          updates = updates.copyWith(isRetroReliable: const Value(true));
          needsUpdate = true;
        }

        // Sync windows for behavioral metrics if they are still "anytime"
        if (eveningId != null && (row.windowIds == 'anytime' || row.windowIds.isEmpty)) {
          if (template.category == EventCategory.behavior || 
              template.category == EventCategory.social || 
              template.id == 'core_wellbeing') {
            updates = updates.copyWith(windowIds: Value(eveningId));
            needsUpdate = true;
          }
        }
        
        // Sync window for sleep quality if it's still "anytime"
        if (morningId != null && (row.windowIds == 'anytime' || row.windowIds.isEmpty)) {
          if (template.id == 'core_sleep_quality') {
            updates = updates.copyWith(windowIds: Value(morningId));
            needsUpdate = true;
          }
        }

        if (needsUpdate) {
          await _db.updateCustomMetric(row.id, updates);
          debugPrint('[MetricService] Synchronized core metric: ${row.id}');
        }
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
  // Custom Metric Management
  // ---------------------------------------------------------------------------

  /// Adds a new user-defined custom metric.
  Future<void> addCustomMetric({
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

  /// Updates an existing custom metric.
  Future<void> updateCustomMetric({
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

  /// Deletes a tracking window.
  Future<void> deleteTrackingWindow(String id) async {
    await _db.deleteTrackingWindow(id);
    await _reload();
    await NotificationService.scheduleDailyReminders();
  }

  /// Deletes a custom metric by [id].
  Future<void> deleteCustomMetric(String id) async {
    final metric = _allMetrics.firstWhere(
      (m) => m.id == id,
      orElse: () => throw ArgumentError('Metric "$id" not found'),
    );

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
    debugPrint('[MetricService] Deleted custom metric: "${metric.label}"');
  }
}
