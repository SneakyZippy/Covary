import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'profile_service.dart';
import '../data/database/tables/table_utils.dart';

/// Service responsible for importing data from JSON files.
/// Updated to support full migrations (Profile, Windows, Events).
class ImportService {
  final AppDatabase _db;
  final ProfileService _profileService;

  ImportService(this._db, this._profileService);

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

      final file = File(result.files.first.path!);
      final content = await file.readAsString();
      final Map<String, dynamic> data = jsonDecode(content);

      // Handle both legacy (flat) and new (structured) formats
      final Map<String, dynamic> profile = data['profile'] ?? data['user'] ?? {};
      final Map<String, dynamic> settings = data['settings'] ?? {};
      final Map<String, dynamic> researchData = data['research_data'] ?? data;

      int eventCount = 0;
      int metricCount = 0;
      int windowCount = 0;
      bool profileRestored = false;

      // 1. Restore Profile (Identity)
      if (profile.containsKey('uuid') && profile.containsKey('nickname')) {
        await _profileService.restoreProfile(
          uuid: profile['uuid'],
          nickname: profile['nickname'],
        );
        profileRestored = true;
      }

      // 2. Import Tracking Windows (Schedules)
      if (settings.containsKey('tracking_windows')) {
        final List<dynamic> windows = settings['tracking_windows'];
        for (final w in windows) {
          try {
            final rawMap = w as Map<String, dynamic>;
            final map = _normalize(rawMap);
            
            // Schema v10: Ensure notification fields exist with correct types
            final int startH = _toInt(map['start_hour'], 0);
            final int startM = _toInt(map['start_minute'], 0);
            
            map['is_notification_enabled'] = _toBool(map['is_notification_enabled'], false);
            map['start_hour'] = startH;
            map['start_minute'] = startM;
            map['end_hour'] = _toInt(map['end_hour'], 23);
            map['end_minute'] = _toInt(map['end_minute'], 59);
            map['notification_hour'] = _toInt(map['notification_hour'], startH);
            map['notification_minute'] = _toInt(map['notification_minute'], startM);
            map['label'] ??= 'Imported Window';
            map['id'] ??= uuid.v4();

            await _db.insertTrackingWindow(
              _db.trackingWindows.map(map).toCompanion(true),
            );
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
            final map = _normalize(rawMap);

            // Schema v6 rename: slot_ids -> window_ids
            if (map.containsKey('slot_ids')) {
              map['window_ids'] ??= map['slot_ids'];
            }
            map['id'] ??= uuid.v4();
            map['label'] ??= 'Imported Metric';
            map['category'] ??= 'behavior';
            map['input_type'] ??= 'yesNo';
            map['window_ids'] ??= 'anytime';
            map['is_enabled'] = _toBool(map['is_enabled'], true);
            
            // Category normalization (Habit -> Behavior)
            if (map['category'] == 'habit') {
              map['category'] = 'behavior';
            }

            await _db.insertCustomMetric(
              _db.customMetrics.map(map).toCompanion(true),
            );
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
            final map = _normalize(rawMap);

            // Ensure HCI metrics exist (latencies, trigger, interaction)
            map['trigger_source'] ??= 'manual';
            map['interaction_type'] ??= 'click';
            map['id'] ??= uuid.v4();
            map['timestamp'] ??= DateTime.now().toIso8601String();
            map['category'] ??= 'behavior';
            map['label'] ??= 'Imported Event';
            map['value'] ??= '0';
            map['latency_ms'] = _toInt(map['latency_ms'], 0);

            // Category normalization (Habit -> Behavior)
            if (map['category'] == 'habit') {
              map['category'] = 'behavior';
            }

            await _db.into(_db.events).insert(
              _db.events.map(map),
              mode: InsertMode.insertOrReplace,
            );
            eventCount++;
          } catch (err, stack) {
            debugPrint('[ImportService] Error importing event: $err');
            debugPrint(stack.toString());
          }
        }
      }

      String summary = 'Import successful!\n';
      summary += '$eventCount events, $metricCount metrics, $windowCount windows restored.';
      if (profileRestored) summary += '\nProfile identity restored.';
      
      return summary;
    } catch (e) {
      debugPrint('[ImportService] Import failed: $e');
      return 'Import failed: ${e.toString()}';
    }
  /// Normalizes a map to snake_case to match Drift's expected JSON format.
  Map<String, dynamic> _normalize(Map<String, dynamic> input) {
    final result = <String, dynamic>{};
    input.forEach((key, value) {
      final normalizedKey = key
          .replaceAllMapped(RegExp(r'([A-Z])'), (match) {
            return '_${match.group(0)!.toLowerCase()}';
          })
          .replaceAll('__', '_')
          .toLowerCase();
      
      final cleanKey = normalizedKey.startsWith('_') 
          ? normalizedKey.substring(1) 
          : normalizedKey;
          
      result[cleanKey] = value;
    });
    return result;
  }

  int _toInt(dynamic value, int defaultValue) {
    if (value == null) return defaultValue;
    if (value is int) return value;
    if (value is double) return value.toInt();
    return int.tryParse(value.toString()) ?? defaultValue;
  }

  bool _toBool(dynamic value, bool defaultValue) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value == 'true' || value == 1) return true;
    if (value == 'false' || value == 0) return false;
    return defaultValue;
  }
}
