import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import 'profile_service.dart';

/// Service responsible for packaging the local Drift database into a
/// structured JSON file and exposing it via the native share intent.
class ExportService {
  final AppDatabase db;
  final ProfileService profileService;

  ExportService({required this.db, required this.profileService});

  /// Gathers all events and custom metrics, writes them to a temporary file,
  /// triggers the share sheet, and logs the export as a meta event.
  Future<bool> exportData() async {
    try {
      final uuid = profileService.uuid;
      final nickname = profileService.nickname;

      // Ensure we have a valid UUID to export
      if (uuid.isEmpty) {
        debugPrint('[ExportService] Cannot export: empty UUID.');
        return false;
      }

      final events = await db.getAllEvents();
      final customMetrics = await db.getAllCustomMetrics();
      final trackingWindows = await db.getAllTrackingWindows();

      // Structure the final JSON for a complete backup/migration
      final data = {
        'profile': {
          'uuid': uuid,
          'nickname': nickname,
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

      // Use indented format for human readability (thesis requirement)
      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final fileName = 'covary_data_${uuid}_$timestamp.json';

      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(jsonString);

      // Log the HCI meta event prior to sharing
      await db.insertEvent(
        EventsCompanion.insert(
          category: EventCategory.meta,
          label: 'data_exported',
          value: 'true',
          triggerSource: TriggerSource.manual,
          interactionType: InteractionType.click,
        ),
      );

      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], text: 'Covary Data Export'),
      );

      return true;
    } catch (e) {
      debugPrint('[ExportService] Export failed: $e');
      return false;
    }
  }
}
