import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import '../data/database/app_database.dart' show EventsCompanion, Event, CustomMetric, TrackingWindow;
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/tracking_window_repository.dart';
import 'profile_service.dart';
import '../data/database/tables/table_utils.dart';
import '../data/models/enums.dart';

/// Service responsible for importing data from JSON files.
/// Updated to support full migrations (Profile, Windows, Events).
class ImportService {
  final EventRepository _eventRepo;
  final MetricRepository _metricRepo;
  final TrackingWindowRepository _trackingWindowRepo;
  final ProfileService _profileService;

  ImportService({
    required EventRepository eventRepo,
    required MetricRepository metricRepo,
    required TrackingWindowRepository trackingWindowRepo,
    required ProfileService profileService,
  })  : _eventRepo = eventRepo,
        _metricRepo = metricRepo,
        _trackingWindowRepo = trackingWindowRepo,
        _profileService = profileService;

  /// Opens a file picker and imports data from the selected JSON file.
  /// Returns a summary message of the import results.
  Future<String> importData() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result == null || result.files.isEmpty) {
        return 'Import cancelled.';
      }

      final String content;
      if (kIsWeb) {
        final bytes = result.files.first.bytes;
        if (bytes == null) {
          return 'Import failed: file content not loaded.';
        }
        content = utf8.decode(bytes);
      } else {
        final path = result.files.first.path;
        if (path == null) {
          return 'Import failed: file path is not available.';
        }
        content = await File(path).readAsString();
      }
      final Map<String, dynamic> data = jsonDecode(content);

      // Handle both legacy (flat) and new (structured) formats
      final Map<String, dynamic> profile = data['profile'] ?? data['user'] ?? {};
      final Map<String, dynamic> settings = data['settings'] ?? {};
      final Map<String, dynamic> researchData = data['research_data'] ?? data;

      int eventCount = 0;
      int metricCount = 0;
      int windowCount = 0;
      bool profileRestored = false;

      // 1. Restore Profile (Identity) only if we don't have one yet,
      // or if the imported profile matches our current UUID (meaning it's our own backup).
      if (profile.containsKey('uuid') && profile.containsKey('nickname')) {
        final currentUuid = _profileService.uuid;
        if (currentUuid.isEmpty || currentUuid == profile['uuid']) {
          await _profileService.restoreProfile(
            uuid: profile['uuid'],
            nickname: profile['nickname'],
          );
          profileRestored = true;
        } else {
          debugPrint('[ImportService] Skipping profile restore: UUID in import (${profile['uuid']}) does not match current local UUID ($currentUuid).');
        }
      }

      // 2. Import Tracking Windows (Schedules)
      if (settings.containsKey('tracking_windows')) {
        final List<dynamic> windows = settings['tracking_windows'];
        for (final w in windows) {
          try {
            final rawMap = w as Map<String, dynamic>;
            final sanitized = _sanitizeWindowJson(rawMap);
            final window = TrackingWindow.fromJson(sanitized);

            await _trackingWindowRepo.insertTrackingWindow(window.toCompanion(true));
            windowCount++;
          } catch (e, stack) {
            debugPrint('[ImportService] Error importing window: $e');
            debugPrint(stack.toString());
          }
        }
      }

      // 3. Import Custom Metrics
      if (researchData.containsKey('custom_metrics')) {
        final List<dynamic> metrics = researchData['custom_metrics'];
        for (final m in metrics) {
          try {
            final rawMap = m as Map<String, dynamic>;
            final sanitized = _sanitizeMetricJson(rawMap);
            
            // Category normalization (Habit -> Behavior)
            if (sanitized['category'] == 'habit') {
              sanitized['category'] = 'behavior';
            }
            
            final metric = CustomMetric.fromJson(sanitized);

            await _metricRepo.insertCustomMetric(metric.toCompanion(true));
            metricCount++;
          } catch (e, stack) {
            debugPrint('[ImportService] Error importing metric: $e');
            debugPrint(stack.toString());
          }
        }
      }

      // 4. Import Events
      if (researchData.containsKey('events')) {
        final List<dynamic> events = researchData['events'];
        for (final e in events) {
          try {
            final rawMap = e as Map<String, dynamic>;
            final sanitized = _sanitizeEventJson(rawMap);
            
            // Category normalization (Habit -> Behavior)
            if (sanitized['category'] == 'habit') {
              sanitized['category'] = 'behavior';
            }

            final event = Event.fromJson(sanitized);

            await _eventRepo.insertEventOrReplace(event);
            eventCount++;
          } catch (err, stack) {
            debugPrint('[ImportService] Error importing event: $err');
            debugPrint(stack.toString());
          }
        }
      }

      // 5. Log Import Meta Event
      await _eventRepo.insertEvent(
        EventsCompanion.insert(
          category: EventCategory.meta,
          label: 'data_imported',
          value: 'true',
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      );

      String summary = 'Import successful!\n';
      summary += '$eventCount events, $metricCount metrics, $windowCount windows restored.';
      if (profileRestored) summary += '\nProfile identity restored.';
      
      return summary;
    } catch (e) {
      debugPrint('[ImportService] Import failed: $e');
      return 'Import failed: ${e.toString()}';
    }
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  bool? _toBool(dynamic value, bool? defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value == 'true' || value == 1) return true;
    if (value == 'false' || value == 0) return false;
    return defaultValue;
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

    // Ensure correct types
    map['startHour'] = _toInt(map['startHour'], 0);
    map['startMinute'] = _toInt(map['startMinute'], 0);
    map['endHour'] = _toInt(map['endHour'], 23);
    map['endMinute'] = _toInt(map['endMinute'], 59);
    map['notificationHour'] = _toInt(map['notificationHour'], map['startHour']);
    map['notificationMinute'] = _toInt(map['notificationMinute'], map['startMinute']);
    map['isNotificationEnabled'] = _toBool(map['isNotificationEnabled'], false);
    map['isEnabled'] = _toBool(map['isEnabled'], true);

    // Apply defaults for non-nullable fields
    map['id'] ??= uuid.v4();
    map['label'] ??= 'Unnamed Window';
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

    // Schema v6 rename: slot_ids -> window_ids / windowIds
    if (map.containsKey('slot_ids')) map['windowIds'] ??= map['slot_ids'];
    if (map.containsKey('slotIds')) map['windowIds'] ??= map['slotIds'];

    // Ensure correct types
    map['isEnabled'] = _toBool(map['isEnabled'], true);
    if (map.containsKey('isRetroReliable')) {
      map['isRetroReliable'] = _toBool(map['isRetroReliable'], null);
    }
    map['isActivityIndicator'] = _toBool(map['isActivityIndicator'], true);

    // Apply defaults for non-nullable fields
    map['id'] ??= uuid.v4();
    map['label'] ??= 'Unnamed Metric';
    map['category'] ??= 'behavior';
    map['inputType'] ??= 'scale1To5';
    map['windowIds'] ??= 'anytime';
    return map;
  }

  Map<String, dynamic> _sanitizeEventJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    
    // Normalize snake_case keys to camelCase if present
    if (map.containsKey('latency_ms')) map['latencyMs'] ??= map['latency_ms'];
    if (map.containsKey('notification_delay_ms')) map['notificationDelayMs'] ??= map['notification_delay_ms'];
    if (map.containsKey('trigger_source')) map['triggerSource'] ??= map['trigger_source'];
    if (map.containsKey('interaction_type')) map['interactionType'] ??= map['interaction_type'];
    if (map.containsKey('session_id')) map['sessionId'] ??= map['session_id'];
    if (map.containsKey('recorded_at')) map['recordedAt'] ??= map['recorded_at'];

    // Ensure correct types
    map['latencyMs'] = _toInt(map['latencyMs'], 0);
    if (map.containsKey('notificationDelayMs') && map['notificationDelayMs'] != null) {
      map['notificationDelayMs'] = _toInt(map['notificationDelayMs'], 0);
    }

    // Apply defaults for non-nullable fields
    map['id'] ??= uuid.v4();
    map['timestamp'] ??= DateTime.now().toIso8601String();
    map['category'] ??= 'behavior';
    map['label'] ??= 'unlabeled';
    map['value'] ??= '';
    map['triggerSource'] ??= 'manual';
    map['interactionType'] ??= 'click';
    return map;
  }
}
