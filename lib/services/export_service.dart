import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database/app_database.dart' show EventsCompanion;
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/tracking_window_repository.dart';
import '../data/models/enums.dart';
import 'profile_service.dart';
import 'web_download_helper.dart';

/// Service responsible for packaging the local Drift database into a
/// structured JSON file and exposing it via the native share intent.
class ExportService {
  final EventRepository _eventRepo;
  final MetricRepository _metricRepo;
  final TrackingWindowRepository _trackingWindowRepo;
  final ProfileService profileService;

  ExportService({
    required EventRepository eventRepo,
    required MetricRepository metricRepo,
    required TrackingWindowRepository trackingWindowRepo,
    required this.profileService,
  })  : _eventRepo = eventRepo,
        _metricRepo = metricRepo,
        _trackingWindowRepo = trackingWindowRepo;

  /// Gathers all events and custom metrics, writes them to a temporary file,
  /// triggers the share sheet, and logs the export as a meta event.
  Future<bool> exportData() async {
    try {
      final events = await _eventRepo.getAllEvents();
      final customMetrics = await _metricRepo.getAllCustomMetrics();
      final trackingWindows = await _trackingWindowRepo.getAllTrackingWindows();

      final data = {
        'profile': {
          'uuid': profileService.uuid,
          'nickname': profileService.nickname,
          'exported_at': DateTime.now().toIso8601String(),
        },
        'settings': {
          'tracking_windows': trackingWindows.map((w) => w.toJson()).toList(),
        },
        'research_data': {
          'events': events.map((e) => e.toJson()).toList(),
          'custom_metrics': customMetrics.map((h) => h.toJson()).toList(),
        },
      };

      return _performExport(data, 'all');
    } catch (e) {
      debugPrint('[ExportService] Export failed: $e');
      return false;
    }
  }

  /// Exports all data and prepares it for submission to the researcher.
  Future<bool> submitToResearcher() async {
    try {
      final events = await _eventRepo.getAllEvents();
      final customMetrics = await _metricRepo.getAllCustomMetrics();
      final trackingWindows = await _trackingWindowRepo.getAllTrackingWindows();

      final data = {
        'profile': {
          'uuid': profileService.uuid,
          'nickname': profileService.nickname,
          'exported_at': DateTime.now().toIso8601String(),
        },
        'settings': {
          'tracking_windows': trackingWindows.map((w) => w.toJson()).toList(),
        },
        'research_data': {
          'events': events.map((e) => e.toJson()).toList(),
          'custom_metrics': customMetrics.map((h) => h.toJson()).toList(),
        },
      };

      return _performExport(
        data, 
        'submission', 
        shareText: 'Covary Research Submission from ${profileService.nickname}\n\n'
                  'To: felix.zoeggeler@edu.fh-joanneum.at\n'
                  'Attached: JSON export file.'
      );
    } catch (e) {
      debugPrint('[ExportService] Submission failed: $e');
      return false;
    }
  }

  Future<bool> exportWindows() async {
    try {
      final trackingWindows = await _trackingWindowRepo.getAllTrackingWindows();
      final data = {
        'settings': {
          'tracking_windows': trackingWindows.map((w) => w.toJson()).toList(),
        },
      };
      return _performExport(data, 'windows');
    } catch (e) {
      debugPrint('[ExportService] Export windows failed: $e');
      return false;
    }
  }

  Future<bool> exportMetrics() async {
    try {
      final customMetrics = await _metricRepo.getAllCustomMetrics();
      final data = {
        'research_data': {
          'custom_metrics': customMetrics.map((h) => h.toJson()).toList(),
        },
      };
      return _performExport(data, 'metrics');
    } catch (e) {
      debugPrint('[ExportService] Export metrics failed: $e');
      return false;
    }
  }

  Future<bool> _performExport(Map<String, dynamic> data, String type, {String? shareText}) async {
    try {
      final uuid = profileService.uuid;
      if (uuid.isEmpty) {
        debugPrint('[ExportService] Cannot export: empty UUID.');
        return false;
      }

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'covary_${type}_${uuid}_$timestamp.json';

      if (kIsWeb) {
        WebDownloadHelper.downloadFile(bytesOrText: jsonString, fileName: fileName);

        // Log the HCI meta event prior to download
        await _eventRepo.insertEvent(
          EventsCompanion.insert(
            category: EventCategory.meta,
            label: 'data_exported_$type',
            value: 'true',
            triggerSource: TriggerSource.manual,
            interactionType: InteractionType.click,
          ),
        );
        return true;
      }

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Log the HCI meta event prior to sharing
      await _eventRepo.insertEvent(
        EventsCompanion.insert(
          category: EventCategory.meta,
          label: 'data_exported_$type',
          value: 'true',
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      );

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)], 
          text: shareText ?? 'Covary Data Export ($type)',
        ),
      );

      return true;
    } catch (e) {
      debugPrint('[ExportService] Export failed: $e');
      return false;
    }
  }
}
