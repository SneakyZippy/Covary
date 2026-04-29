import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:drift/drift.dart';
import '../data/database/app_database.dart';
import 'profile_service.dart';

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
            await _db.insertTrackingWindow(
              _db.trackingWindows.map(w as Map<String, dynamic>).toCompanion(true),
            );
            windowCount++;
          } catch (e) {
            debugPrint('[ImportService] Error importing window: $e');
          }
        }
      }

      // 3. Import Custom Metrics
      if (researchData.containsKey('custom_metrics')) {
        final List<dynamic> metrics = researchData['custom_metrics'];
        for (final m in metrics) {
          try {
            await _db.insertCustomMetric(
              _db.customMetrics.map(m as Map<String, dynamic>).toCompanion(true),
            );
            metricCount++;
          } catch (e) {
            debugPrint('[ImportService] Error importing metric: $e');
          }
        }
      }

      // 4. Import Events
      if (researchData.containsKey('events')) {
        final List<dynamic> events = researchData['events'];
        for (final e in events) {
          try {
            await _db.into(_db.events).insert(
              _db.events.map(e as Map<String, dynamic>),
              mode: InsertMode.insertOrReplace,
            );
            eventCount++;
          } catch (err) {
            debugPrint('[ImportService] Error importing event: $err');
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
  }
}
