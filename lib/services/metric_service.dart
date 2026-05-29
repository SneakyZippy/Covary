import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart' show TrackingWindow, TrackingWindowsCompanion, CustomMetricsCompanion, EventsCompanion;
import '../data/models/enums.dart';
import '../data/models/metric_definition.dart';
import '../data/metric_presets.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/tracking_window_repository.dart';
import 'notification_service.dart';

/// Prefix for core-metric toggle keys in preferences.
const _kCoreMetricPrefix = 'core_metric_enabled_';

/// Prefix for core-metric window keys in preferences.
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
/// in SharedPreferences. Custom metrics live in the CustomMetrics Drift
/// table. This service merges both into a single list for the UI.
class MetricService extends ChangeNotifier {
  final MetricRepository _metricRepo;
  final TrackingWindowRepository _trackingWindowRepo;
  final EventRepository _eventRepo;
  final ProfileRepository _profileRepo;

  /// Merged list of all metrics (core + custom), cached in memory.
  List<MetricDefinition> _allMetrics = [];

  /// User-defined tracking windows.
  List<TrackingWindow> _allWindows = [];

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  MetricService({
    required MetricRepository metricRepo,
    required TrackingWindowRepository trackingWindowRepo,
    required EventRepository eventRepo,
    required ProfileRepository profileRepo,
  })  : _metricRepo = metricRepo,
        _trackingWindowRepo = trackingWindowRepo,
        _eventRepo = eventRepo,
        _profileRepo = profileRepo;

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

  /// Initializes the service by loading and seeding (if necessary) windows and 
  /// metrics from the repositories, then merges them.
  Future<void> init() async {
    // --- Seed Tracking Windows ---
    final existingWindows = await _trackingWindowRepo.getAllTrackingWindows();
    final windowsSeeded = _profileRepo.getBoolSetting('tracking_windows_seeded');
    
    // Seeding logic
    if (!windowsSeeded) {
      if (existingWindows.isEmpty) {
        for (final s in MetricPresets.windowPresets) {
          try {
            await _trackingWindowRepo.insertTrackingWindow(
              TrackingWindowsCompanion.insert(
                id: s.id != null ? Value(s.id!) : const Value.absent(),
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
      }
      await _profileRepo.setBoolSetting('tracking_windows_seeded', true);
      debugPrint('[MetricService] Seeded ${MetricPresets.windowPresets.length} sample tracking windows');
    }

    // --- SOFT MIGRATION: Sync Tracking Windows (v2) ---
    final windowSyncKey = 'tracking_windows_v2_sync';
    if (!_profileRepo.getBoolSetting(windowSyncKey)) {
      final currentWindows = await _trackingWindowRepo.getAllTrackingWindows();
      final currentWindowIds = currentWindows.map((w) => w.id).toSet();
      int addedCount = 0;
      int updatedCount = 0;

      for (final s in MetricPresets.windowPresets) {
        if (s.id != null && !currentWindowIds.contains(s.id)) {
          // Insert missing window
          try {
            await _trackingWindowRepo.insertTrackingWindow(
              TrackingWindowsCompanion.insert(
                id: Value(s.id!),
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
            addedCount++;
          } catch (e) {
            debugPrint('[MetricService] Error injecting missing window ${s.label}: $e');
          }
        } else if (s.id != null) {
          // Force enable research-critical windows if they were disabled by default before
          try {
            await _trackingWindowRepo.updateTrackingWindow(
              s.id!,
              TrackingWindowsCompanion(
                isEnabled: Value(s.isEnabled),
              ),
            );
            updatedCount++;
          } catch (e) {
            debugPrint('[MetricService] Error syncing window ${s.label}: $e');
          }
        }
      }

      if (addedCount > 0 || updatedCount > 0) {
        debugPrint('[MetricService] Window Soft Migration v2: +$addedCount new, $updatedCount synced');
      }
      await _profileRepo.setBoolSetting(windowSyncKey, true);
    }

    // --- MIGRATION: Sync existing windows notification time ---
    final migrationKey = 'notif_sync_v1';
    if (!_profileRepo.getBoolSetting(migrationKey)) {
      final windows = await _trackingWindowRepo.getAllTrackingWindows();
      for (var w in windows) {
        if (w.notificationHour != w.startHour || w.notificationMinute != w.startMinute) {
          await _trackingWindowRepo.updateTrackingWindow(
            w.id,
            TrackingWindowsCompanion(
              notificationHour: Value(w.startHour),
              notificationMinute: Value(w.startMinute),
            ),
          );
        }
      }
      await _profileRepo.setBoolSetting(migrationKey, true);
    }

    // --- SOFT MIGRATION: Sync Tracking Windows Label (v3) ---
    final windowSyncV3Key = 'tracking_windows_v3_sync';
    if (!_profileRepo.getBoolSetting(windowSyncV3Key)) {
      final currentWindows = await _trackingWindowRepo.getAllTrackingWindows();
      for (final w in currentWindows) {
        if (w.id == '4c62fdff-7942-4848-8140-3c483a54daba' && w.label == 'Afternoon Sync') {
          try {
            await _trackingWindowRepo.updateTrackingWindow(
              w.id,
              const TrackingWindowsCompanion(
                label: Value('Afternoon'),
              ),
            );
            debugPrint('[MetricService] Window Soft Migration v3: Renamed Afternoon Sync to Afternoon');
          } catch (e) {
            debugPrint('[MetricService] Error updating window label during v3 sync: $e');
          }
        }
      }
      await _profileRepo.setBoolSetting(windowSyncV3Key, true);
    }

    // --- Seed Metrics ---
    final existingMetrics = await _metricRepo.getAllCustomMetrics();
    final hasSeeded = _profileRepo.getBoolSetting('core_metrics_seeded');
    
    if (!hasSeeded && existingMetrics.isEmpty) {
      // Seed default metrics if first launch
      for (final m in templates) {
        try {
          final legacyPrefKey = 'core_habit_enabled_${m.id}';
          final prefKey = '$_kCoreMetricPrefix${m.id}';
          
          final enabled = _profileRepo.getBoolSetting(legacyPrefKey) || _profileRepo.getBoolSetting(prefKey) || m.isEnabled;
          
          final legacyWindowKey = 'core_habit_frequency_${m.id}';
          final windowKey = '$_kCoreMetricWindowPrefix${m.id}';
          final windowIdsString = _profileRepo.getStringSetting(legacyWindowKey) ?? _profileRepo.getStringSetting(windowKey);
          
          List<String> windowIds = m.windowIds;
          if (windowIdsString != null) {
            windowIds = windowIdsString.split(',').where((s) => s.isNotEmpty).toList();
          }

          await _metricRepo.insertCustomMetric(
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
      await _profileRepo.setBoolSetting('core_metrics_seeded', true);
    } else if (!hasSeeded) {
      await _profileRepo.setBoolSetting('core_metrics_seeded', true);
    }

    // --- SOFT MIGRATION v5: Inject missing metrics + sync inputType/isActivityIndicator ---
    final syncKey = 'core_metrics_v5_sync';
    if (!_profileRepo.getBoolSetting(syncKey)) {
      await _reload(); // Ensure _allMetrics is populated before we check IDs
      final currentMetricIds = _allMetrics.map((m) => m.id).toSet();
      int addedCount = 0;
      int updatedCount = 0;
      
      for (final template in templates) {
        if (!currentMetricIds.contains(template.id)) {
          try {
            await _metricRepo.insertCustomMetric(
              CustomMetricsCompanion.insert(
                id: Value(template.id),
                label: template.label,
                category: template.category,
                inputType: template.inputType,
                isEnabled: Value(template.isEnabled),
                windowIds: Value(template.windowIds.isEmpty ? '_none_' : template.windowIds.join(',')),
                emoji: Value(template.emoji),
                isActivityIndicator: Value(template.isActivityIndicator),
                isRetroReliable: Value(template.retroReliableOverride),
              ),
            );
            addedCount++;
          } catch (e) {
            debugPrint('[MetricService] Error injecting missing metric ${template.id}: $e');
          }
        } else {
          try {
            await _metricRepo.updateCustomMetric(
              template.id,
              CustomMetricsCompanion(
                inputType: Value(template.inputType),
                isActivityIndicator: Value(template.isActivityIndicator),
              ),
            );
            updatedCount++;
          } catch (e) {
            debugPrint('[MetricService] Error syncing metric ${template.id}: $e');
          }
        }
      }
      
      if (addedCount > 0 || updatedCount > 0) {
        debugPrint('[MetricService] Soft Migration v5: +$addedCount new, ~$updatedCount updated');
        await _reload();
      }
      await _profileRepo.setBoolSetting(syncKey, true);
    }

    // --- SOFT MIGRATION v6: Update core_screen_mindless label and inputType, migrate old event labels ---
    final syncKeyV6 = 'core_metrics_v6_sync';
    if (!_profileRepo.getBoolSetting(syncKeyV6)) {
      try {
        await _metricRepo.updateCustomMetric(
          'core_screen_mindless',
          const CustomMetricsCompanion(
            label: Value('Mindless Scrolling'),
            inputType: Value(MetricInputType.counter),
            windowIds: Value('homescreen'),
          ),
        );
        debugPrint('[MetricService] Soft Migration v6: Changed core_screen_mindless inputType to counter, label to Mindless Scrolling, and windowIds to homescreen');

        final oldEvents = await _eventRepo.getEventsByLabel('Mindless Scrolling?');
        int migratedCount = 0;
        for (final event in oldEvents) {
          await _eventRepo.updateEvent(
            event.id,
            const EventsCompanion(
              label: Value('Mindless Scrolling'),
            ),
          );
          migratedCount++;
        }
        if (migratedCount > 0) {
          debugPrint('[MetricService] Soft Migration v6: Migrated $migratedCount events to new label');
        }
        await _reload();
      } catch (e) {
        debugPrint('[MetricService] Error running soft migration v6: $e');
      }
      await _profileRepo.setBoolSetting(syncKeyV6, true);
    }

    await _reload();
    debugPrint(
      '[MetricService] Initialized with ${_allMetrics.length} metrics '
      '(${activeMetrics.length} active)',
    );
    _isInitialized = true;
    notifyListeners();
  }

  /// Reloads all metric data from persistence and rebuilds [_allMetrics].
  Future<void> _reload() async {
    // --- Windows from Drift ---
    _allWindows = await _trackingWindowRepo.getAllTrackingWindows();

    final windowOrder = _profileRepo.getStringListSetting('tracking_windows_sort_order');
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
    final customRows = await _metricRepo.getAllCustomMetrics();
    final customMetrics = customRows.map((row) {
      final rawWindows = row.windowIds;
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
        description: MetricPresets.getMetricDescription(row.id),
      );
    }).toList();

    _allMetrics = [...customMetrics];

    final savedOrder = _profileRepo.getStringListSetting('metric_sort_order');
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

  /// Updates the order of metrics and persists it to preferences.
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
      _allMetrics.remove(item);

      if (newIndex < listToReorder.length) {
        final targetItem = listToReorder[newIndex];
        final targetGlobalIdx = _allMetrics.indexOf(targetItem);
        
        if (oldIndex < newIndex) {
          _allMetrics.insert(targetGlobalIdx + 1, item);
        } else {
          _allMetrics.insert(targetGlobalIdx, item);
        }
      } else {
        final lastItem = listToReorder.last;
        final lastGlobalIdx = _allMetrics.indexOf(lastItem);
        _allMetrics.insert(lastGlobalIdx + 1, item);
      }
    }

    final newOrder = _allMetrics.map((m) => m.id).toList();
    await _profileRepo.setStringListSetting('metric_sort_order', newOrder);
    
    notifyListeners();
  }

  /// Updates the order of tracking windows and persists it to preferences.
  Future<void> reorderTrackingWindows(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = _allWindows.removeAt(oldIndex);
    _allWindows.insert(newIndex, item);

    final newOrder = _allWindows.map((w) => w.id).toList();
    await _profileRepo.setStringListSetting('tracking_windows_sort_order', newOrder);

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

    await _metricRepo.setCustomMetricEnabled(id, newEnabled);

    _allMetrics[index] = metric.copyWith(isEnabled: newEnabled);
    notifyListeners();
    debugPrint('[MetricService] Toggled "${metric.label}" → $newEnabled');
  }

  /// Sets whether a metric counts towards the activity streak.
  Future<void> setMetricActivityIndicator(String id, bool isActivityIndicator) async {
    final index = _allMetrics.indexWhere((m) => m.id == id);
    if (index == -1) return;

    final metric = _allMetrics[index];
    
    await _metricRepo.updateCustomMetric(
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
 
    await _trackingWindowRepo.updateTrackingWindow(
      id,
      TrackingWindowsCompanion(isEnabled: Value(newEnabled)),
    );
 
    await _reload(); // Reload to update memory and notify
    await NotificationService.scheduleDailyReminders();
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

    await _metricRepo.updateCustomMetricWindows(id, windowIdsString);

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

    await _metricRepo.insertCustomMetric(
      CustomMetricsCompanion.insert(
        id: Value(metricId),
        label: label,
        category: category,
        inputType: inputType,
        isEnabled: const Value(true),
        windowIds: Value(_serializeWindowIds(windowIds)),
        emoji: Value(emoji),
        isActivityIndicator: Value(isActivityIndicator),
        isRetroReliable: Value(retroReliableOverride),
      ),
    );

    try {
      await _eventRepo.insertEvent(
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
    await _metricRepo.updateCustomMetric(
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
    await _trackingWindowRepo.insertTrackingWindow(
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
    await _trackingWindowRepo.updateTrackingWindow(
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
        await _metricRepo.updateCustomMetric(
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
    await _trackingWindowRepo.deleteTrackingWindow(id);
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
    await _metricRepo.deleteCustomMetric(id);

    try {
      await _eventRepo.insertEvent(
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
    await _metricRepo.clearAllMetrics();
    await _trackingWindowRepo.clearAllTrackingWindows();

    await _profileRepo.removeSetting('tracking_windows_seeded');
    await _profileRepo.removeSetting('core_metrics_seeded');
    await _profileRepo.removeSetting('metric_sort_order');
    await _profileRepo.removeSetting('tracking_windows_sort_order');
    await _profileRepo.removeSetting('tracking_windows_v2_sync'); // Clear sync flag too
    
    await init();
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
    
    for (var m in _allMetrics) {
      if (m.isEnabled) {
        await _metricRepo.setCustomMetricEnabled(m.id, false);
      }
    }

    for (var id in targetIds) {
      await _metricRepo.setCustomMetricEnabled(id, true);
    }

    try {
      await _eventRepo.insertEvent(
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
