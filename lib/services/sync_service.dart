import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import '../data/database/app_database.dart' show Event, CustomMetric, TrackingWindow;
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/tracking_window_repository.dart';
import '../data/repositories/profile_repository.dart';
import 'profile_service.dart';
import 'supabase_config.dart';

class SyncSummary {
  final int windowsAdded;
  final int windowsUpdated;
  final int metricsAdded;
  final int metricsUpdated;
  final int eventsAdded;
  final int eventsUpdated;

  const SyncSummary({
    this.windowsAdded = 0,
    this.windowsUpdated = 0,
    this.metricsAdded = 0,
    this.metricsUpdated = 0,
    this.eventsAdded = 0,
    this.eventsUpdated = 0,
  });

  bool get isEmpty =>
      windowsAdded == 0 &&
      windowsUpdated == 0 &&
      metricsAdded == 0 &&
      metricsUpdated == 0 &&
      eventsAdded == 0 &&
      eventsUpdated == 0;
}

const String _kSupabaseSyncEnabled = 'supabase_sync_enabled';

/// Service responsible for syncing local Drift database events, metrics,
/// and windows to a remote Supabase PostgreSQL instance.
class SyncService extends ChangeNotifier {
  final EventRepository _eventRepo;
  final MetricRepository _metricRepo;
  final TrackingWindowRepository _trackingWindowRepo;
  final ProfileRepository _profileRepo;
  final ProfileService profileService;

  bool _syncEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncErrorMessage;
  bool _isSupabaseInitialized = false;

  SyncService({
    required EventRepository eventRepo,
    required MetricRepository metricRepo,
    required TrackingWindowRepository trackingWindowRepo,
    required ProfileRepository profileRepo,
    required this.profileService,
  })  : _eventRepo = eventRepo,
        _metricRepo = metricRepo,
        _trackingWindowRepo = trackingWindowRepo,
        _profileRepo = profileRepo;

  /// Whether the user has opted into cloud backup.
  bool get syncEnabled => _syncEnabled;

  /// Whether a sync operation is currently active.
  bool get isSyncing => _isSyncing;

  /// The timestamp of the last successful sync.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// The last recorded sync error message, or null if successful.
  String? get syncErrorMessage => _syncErrorMessage;

  /// Whether the Supabase client was successfully initialized.
  bool get isSupabaseInitialized => _isSupabaseInitialized;

  /// Reads user preference and initializes the Supabase client if keys are available.
  Future<void> init() async {
    _syncEnabled = _profileRepo.getBoolSetting(_kSupabaseSyncEnabled, defaultValue: false);

    final url = SupabaseConfig.supabaseUrl.trim();
    final anonKey = SupabaseConfig.supabaseAnonKey.trim();

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: url,
          publishableKey: anonKey,
        );
        _isSupabaseInitialized = true;
        debugPrint('[SyncService] Supabase client initialized successfully.');
      } catch (e) {
        try {
          final _ = Supabase.instance;
          _isSupabaseInitialized = true;
          debugPrint('[SyncService] Supabase client already initialized.');
        } catch (_) {
          debugPrint('[SyncService] Failed to initialize Supabase: $e');
          _syncErrorMessage = 'Supabase init failed: $e';
        }
      }
    } else {
      debugPrint('[SyncService] Supabase URL or Anon Key is empty. Sync is disabled.');
    }

    notifyListeners();
  }

  /// Sets whether cloud backup sync is enabled and triggers an immediate sync if toggled ON.
  Future<void> setSyncEnabled(bool enabled) async {
    if (_syncEnabled == enabled) return;
    _syncEnabled = enabled;

    await _profileRepo.setBoolSetting(_kSupabaseSyncEnabled, enabled);
    notifyListeners();

    if (enabled) {
      unawaited(syncNow(force: true));
    }
  }

  /// Gathers all local database records and uploads them to Supabase by the user's UUID.
  Future<void> uploadBackup() async {
    if (!_isSupabaseInitialized) return;
    final uuid = profileService.uuid;
    if (uuid.isEmpty) return;

    try {
      final events = await _eventRepo.getAllEvents();
      final customMetrics = await _metricRepo.getAllCustomMetrics();
      final trackingWindows = await _trackingWindowRepo.getAllTrackingWindows();

      final payload = {
        'tracking_windows': trackingWindows.map((w) => w.toJson()).toList(),
        'events': events.map((e) => e.toJson()).toList(),
        'custom_metrics': customMetrics.map((h) => h.toJson()).toList(),
      };

      await Supabase.instance.client.from('user_syncs').upsert({
        'uuid': uuid,
        'nickname': profileService.nickname,
        'synced_at': DateTime.now().toUtc().toIso8601String(),
        'payload': payload,
      });

      _lastSyncTime = DateTime.now();
      _syncErrorMessage = null;
      debugPrint('[SyncService] Backup uploaded successfully for user: $uuid');
    } catch (e) {
      debugPrint('[SyncService] Backup upload failed: $e');
      _syncErrorMessage = e.toString();
      rethrow;
    }
  }

  /// Downloads a cloud backup and merges it into the local SQLite database.
  /// Returns a [SyncSummary] of added/updated count details.
  Future<SyncSummary> downloadAndMergeBackup() async {
    if (!_isSupabaseInitialized) {
      throw Exception('Supabase client not initialized.');
    }
    final uuid = profileService.uuid;
    if (uuid.isEmpty) {
      throw Exception('User UUID is empty.');
    }

    int windowsAdded = 0;
    int windowsUpdated = 0;
    int metricsAdded = 0;
    int metricsUpdated = 0;
    int eventsAdded = 0;
    int eventsUpdated = 0;

    try {
      debugPrint('[SyncService] Fetching remote backup payload for UUID: $uuid...');
      final response = await Supabase.instance.client
          .from('user_syncs')
          .select('payload')
          .eq('uuid', uuid)
          .maybeSingle();

      if (response != null && response['payload'] != null) {
        final payload = response['payload'] as Map<String, dynamic>;

        // Fetch local records for comparison
        final localWindows = await _trackingWindowRepo.getAllTrackingWindows();
        final localMetrics = await _metricRepo.getAllCustomMetrics();
        final localEvents = await _eventRepo.getAllEvents();

        final localWindowsMap = {for (final w in localWindows) w.id: w};
        final localMetricsMap = {for (final m in localMetrics) m.id: m};
        final localEventsMap = {for (final e in localEvents) e.id: e};

        // 1. Merge tracking windows
        if (payload.containsKey('tracking_windows')) {
          final List<dynamic> windows = payload['tracking_windows'];
          for (final w in windows) {
            try {
              final map = w as Map<String, dynamic>;
              final sanitized = _sanitizeWindowJson(map);
              final window = TrackingWindow.fromJson(sanitized);
              
              final localWindow = localWindowsMap[window.id];
              if (localWindow == null) {
                windowsAdded++;
                await _trackingWindowRepo.insertTrackingWindow(window.toCompanion(true));
              } else if (localWindow != window) {
                windowsUpdated++;
                await _trackingWindowRepo.insertTrackingWindow(window.toCompanion(true));
              }
            } catch (e) {
              debugPrint('[SyncService] Failed to merge window: $e');
            }
          }
        }

        // 2. Merge custom metrics
        if (payload.containsKey('custom_metrics')) {
          final List<dynamic> metrics = payload['custom_metrics'];
          for (final m in metrics) {
            try {
              final map = m as Map<String, dynamic>;
              final sanitized = _sanitizeMetricJson(map);
              final metric = CustomMetric.fromJson(sanitized);

              final localMetric = localMetricsMap[metric.id];
              if (localMetric == null) {
                metricsAdded++;
                await _metricRepo.insertCustomMetric(metric.toCompanion(true));
              } else if (localMetric != metric) {
                metricsUpdated++;
                await _metricRepo.insertCustomMetric(metric.toCompanion(true));
              }
            } catch (e) {
              debugPrint('[SyncService] Failed to merge metric: $e');
            }
          }
        }

        // 3. Merge events
        if (payload.containsKey('events')) {
          final List<dynamic> eventsList = payload['events'];
          for (final e in eventsList) {
            try {
              final map = e as Map<String, dynamic>;
              final sanitized = _sanitizeEventJson(map);
              final event = Event.fromJson(sanitized);

              final localEvent = localEventsMap[event.id];
              if (localEvent == null) {
                eventsAdded++;
                await _eventRepo.insertEventOrReplace(event);
              } else if (localEvent != event) {
                eventsUpdated++;
                await _eventRepo.insertEventOrReplace(event);
              }
            } catch (err) {
              debugPrint('[SyncService] Failed to merge event: $err');
            }
          }
        }
      }
      
      _syncErrorMessage = null;
      return SyncSummary(
        windowsAdded: windowsAdded,
        windowsUpdated: windowsUpdated,
        metricsAdded: metricsAdded,
        metricsUpdated: metricsUpdated,
        eventsAdded: eventsAdded,
        eventsUpdated: eventsUpdated,
      );
    } catch (e) {
      debugPrint('[SyncService] Download/merge failed: $e');
      _syncErrorMessage = e.toString();
      rethrow;
    }
  }

  /// Runs a sync operation. If [force] is true (e.g. initial toggle-on), it first downloads
  /// and merges the remote backup, then uploads the current state.
  /// If [force] is false (routine sync), it only uploads the local state.
  Future<void> syncNow({bool force = false}) async {
    if (!_syncEnabled && !force) {
      debugPrint('[SyncService] Sync skipped: Sync is disabled in settings.');
      return;
    }

    if (!_isSupabaseInitialized) {
      debugPrint('[SyncService] Sync skipped: Supabase client not initialized.');
      return;
    }

    if (_isSyncing) {
      debugPrint('[SyncService] Sync skipped: Another sync is in progress.');
      return;
    }

    final uuid = profileService.uuid;
    if (uuid.isEmpty) {
      debugPrint('[SyncService] Sync skipped: UUID is empty.');
      return;
    }

    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      if (force) {
        await downloadAndMergeBackup();
      }
      await uploadBackup();
      _syncErrorMessage = null;
    } catch (e) {
      _syncErrorMessage = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /// Downloads a cloud backup for the given [targetUuid], merges it into the local database,
  /// sets it as the active user identity, and enables cloud backup.
  /// Returns a [SyncSummary] if successful, `null` if no backup found or failed.
  Future<SyncSummary?> restoreWithUuid(String targetUuid) async {
    final cleanedUuid = targetUuid.trim();
    if (cleanedUuid.isEmpty) return null;
    if (!_isSupabaseInitialized) return null;

    _isSyncing = true;
    _syncErrorMessage = null;
    notifyListeners();

    try {
      debugPrint('[SyncService] Attempting to restore backup for UUID: $cleanedUuid');
      final response = await Supabase.instance.client
          .from('user_syncs')
          .select('nickname, payload')
          .eq('uuid', cleanedUuid)
          .maybeSingle();

      if (response == null || response['payload'] == null || response['payload'] is! Map) {
        debugPrint('[SyncService] No remote backup found or invalid payload for UUID: $cleanedUuid');
        _isSyncing = false;
        notifyListeners();
        return null;
      }

      final payload = response['payload'] as Map<String, dynamic>;
      final nickname = response['nickname'] as String? ?? 'Restored User';

      int windowsAdded = 0;
      int windowsUpdated = 0;
      int metricsAdded = 0;
      int metricsUpdated = 0;
      int eventsAdded = 0;
      int eventsUpdated = 0;

      // Fetch local records for comparison
      final localWindows = await _trackingWindowRepo.getAllTrackingWindows();
      final localMetrics = await _metricRepo.getAllCustomMetrics();
      final localEvents = await _eventRepo.getAllEvents();

      final localWindowsMap = {for (final w in localWindows) w.id: w};
      final localMetricsMap = {for (final m in localMetrics) m.id: m};
      final localEventsMap = {for (final e in localEvents) e.id: e};

      // 1. Merge tracking windows
      if (payload.containsKey('tracking_windows')) {
        final List<dynamic> windows = payload['tracking_windows'];
        for (final w in windows) {
          try {
            final map = w as Map<String, dynamic>;
            final sanitized = _sanitizeWindowJson(map);
            final window = TrackingWindow.fromJson(sanitized);
            
            final localWindow = localWindowsMap[window.id];
            if (localWindow == null) {
              windowsAdded++;
              await _trackingWindowRepo.insertTrackingWindow(window.toCompanion(true));
            } else if (localWindow != window) {
              windowsUpdated++;
              await _trackingWindowRepo.insertTrackingWindow(window.toCompanion(true));
            }
          } catch (e) {
            debugPrint('[SyncService] Failed to merge window: $e');
          }
        }
      }

      // 2. Merge custom metrics
      if (payload.containsKey('custom_metrics')) {
        final List<dynamic> metrics = payload['custom_metrics'];
        for (final m in metrics) {
          try {
            final map = m as Map<String, dynamic>;
            final sanitized = _sanitizeMetricJson(map);
            final metric = CustomMetric.fromJson(sanitized);

            final localMetric = localMetricsMap[metric.id];
            if (localMetric == null) {
              metricsAdded++;
              await _metricRepo.insertCustomMetric(metric.toCompanion(true));
            } else if (localMetric != metric) {
              metricsUpdated++;
              await _metricRepo.insertCustomMetric(metric.toCompanion(true));
            }
          } catch (e) {
            debugPrint('[SyncService] Failed to merge metric: $e');
          }
        }
      }

      // 3. Merge events
      if (payload.containsKey('events')) {
        final List<dynamic> eventsList = payload['events'];
        for (final e in eventsList) {
          try {
            final map = e as Map<String, dynamic>;
            final sanitized = _sanitizeEventJson(map);
            final event = Event.fromJson(sanitized);

            final localEvent = localEventsMap[event.id];
            if (localEvent == null) {
              eventsAdded++;
              await _eventRepo.insertEventOrReplace(event);
            } else if (localEvent != event) {
              eventsUpdated++;
              await _eventRepo.insertEventOrReplace(event);
            }
          } catch (err) {
            debugPrint('[SyncService] Failed to merge event: $err');
          }
        }
      }

      // 4. Update local user identity in ProfileService
      await profileService.restoreProfile(uuid: cleanedUuid, nickname: nickname);
      await profileService.completeOnboarding();

      // 5. Enable sync in preferences
      _syncEnabled = true;
      await _profileRepo.setBoolSetting(_kSupabaseSyncEnabled, true);

      _lastSyncTime = DateTime.now();
      _syncErrorMessage = null;

      debugPrint('[SyncService] Cloud restore completed for UUID: $cleanedUuid');
      return SyncSummary(
        windowsAdded: windowsAdded,
        windowsUpdated: windowsUpdated,
        metricsAdded: metricsAdded,
        metricsUpdated: metricsUpdated,
        eventsAdded: eventsAdded,
        eventsUpdated: eventsUpdated,
      );
    } catch (e) {
      debugPrint('[SyncService] Restore failed: $e');
      _syncErrorMessage = e.toString();
      return null;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Map<String, dynamic> _sanitizeWindowJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    
    // Normalize snake_case keys to camelCase if present
    if (map.containsKey('start_hour')) map['startHour'] ??= map['start_hour'];
    if (map.containsKey('start_minute')) map['startMinute'] ??= map['start_minute'];
    if (map.containsKey('end_hour')) map['endHour'] ??= map['end_hour'];
    if (map.containsKey('end_minute')) map['endMinute'] ??= map['end_minute'];
    if (map.containsKey('is_notification_enabled')) map['isNotificationEnabled'] ??= map['is_notification_enabled'];
    if (map.containsKey('notification_hour')) map['notificationHour'] ??= map['notification_hour'];
    if (map.containsKey('notification_minute')) map['notificationMinute'] ??= map['notification_minute'];
    if (map.containsKey('is_enabled')) map['isEnabled'] ??= map['is_enabled'];

    // Apply defaults for non-nullable fields
    map['id'] ??= const Uuid().v4();
    map['label'] ??= 'Unnamed Window';
    map['startHour'] ??= 0;
    map['startMinute'] ??= 0;
    map['endHour'] ??= 0;
    map['endMinute'] ??= 0;
    map['isNotificationEnabled'] ??= false;
    map['notificationHour'] ??= 0;
    map['notificationMinute'] ??= 0;
    map['isEnabled'] ??= true;
    return map;
  }

  Map<String, dynamic> _sanitizeMetricJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    
    // Normalize snake_case keys to camelCase if present
    if (map.containsKey('input_type')) map['inputType'] ??= map['input_type'];
    if (map.containsKey('window_ids')) map['windowIds'] ??= map['window_ids'];
    if (map.containsKey('is_enabled')) map['isEnabled'] ??= map['is_enabled'];
    if (map.containsKey('is_retro_reliable')) map['isRetroReliable'] ??= map['is_retro_reliable'];
    if (map.containsKey('is_activity_indicator')) map['isActivityIndicator'] ??= map['is_activity_indicator'];

    // Apply defaults for non-nullable fields
    map['id'] ??= const Uuid().v4();
    map['label'] ??= 'Unnamed Metric';
    map['category'] ??= 'behavior';
    map['inputType'] ??= 'scale1To5';
    map['windowIds'] ??= 'anytime';
    map['isEnabled'] ??= true;
    map['isActivityIndicator'] ??= true;
    return map;
  }

  Map<String, dynamic> _sanitizeEventJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    
    // Normalize snake_case keys to camelCase if present
    if (map.containsKey('latency_ms')) map['latencyMs'] ??= map['latency_ms'];
    if (map.containsKey('trigger_source')) map['triggerSource'] ??= map['trigger_source'];
    if (map.containsKey('interaction_type')) map['interactionType'] ??= map['interaction_type'];
    if (map.containsKey('session_id')) map['sessionId'] ??= map['session_id'];
    if (map.containsKey('recorded_at')) map['recordedAt'] ??= map['recorded_at'];

    // Apply defaults for non-nullable fields
    map['id'] ??= const Uuid().v4();
    map['timestamp'] ??= DateTime.now().toIso8601String();
    map['category'] ??= 'behavior';
    map['label'] ??= 'unlabeled';
    map['value'] ??= '';
    map['latencyMs'] ??= 0;
    map['triggerSource'] ??= 'manual';
    map['interactionType'] ??= 'click';
    return map;
  }
}
