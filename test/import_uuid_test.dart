import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:file_picker/file_picker.dart';
import 'package:covary/services/import_service.dart';
import 'package:covary/services/profile_service.dart';
import 'package:covary/data/repositories/event_repository.dart';
import 'package:covary/data/repositories/metric_repository.dart';
import 'package:covary/data/repositories/tracking_window_repository.dart';
import 'package:covary/data/database/app_database.dart';

class MockFilePicker extends FilePicker {
  final FilePickerResult? result;
  MockFilePicker(this.result);

  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    return result;
  }
}

class TestProfileService extends Fake implements ProfileService {
  String _uuid;
  String _nickname;
  bool restoreProfileCalled = false;

  TestProfileService(this._uuid, this._nickname);

  @override
  String get uuid => _uuid;

  @override
  String get nickname => _nickname;

  @override
  Future<void> restoreProfile({required String uuid, required String nickname}) async {
    restoreProfileCalled = true;
    _uuid = uuid;
    _nickname = nickname;
  }
}

class FakeEventRepository extends Fake implements EventRepository {
  @override
  Future<int> insertEvent(EventsCompanion entry) async {
    return 1;
  }
}

class FakeMetricRepository extends Fake implements MetricRepository {}
class FakeTrackingWindowRepository extends Fake implements TrackingWindowRepository {}

void main() {
  group('ImportService UUID Preservation Tests', () {
    late FakeEventRepository eventRepo;
    late FakeMetricRepository metricRepo;
    late FakeTrackingWindowRepository trackingWindowRepo;

    setUp(() {
      eventRepo = FakeEventRepository();
      metricRepo = FakeMetricRepository();
      trackingWindowRepo = FakeTrackingWindowRepository();
    });

    test('Importing JSON from SAME user restores the profile', () async {
      final profileService = TestProfileService('user-123', 'User A');
      final importService = ImportService(
        eventRepo: eventRepo,
        metricRepo: metricRepo,
        trackingWindowRepo: trackingWindowRepo,
        profileService: profileService,
      );

      final payload = {
        'profile': {
          'uuid': 'user-123',
          'nickname': 'User A',
        },
      };

      final jsonStr = jsonEncode(payload);
      final tempFile = File('${Directory.systemTemp.path}/test_import_same.json');
      await tempFile.writeAsString(jsonStr);

      FilePicker.platform = MockFilePicker(FilePickerResult([
        PlatformFile(
          name: 'export.json',
          size: jsonStr.length,
          path: tempFile.path,
        ),
      ]));

      final result = await importService.importData();

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      expect(profileService.uuid, equals('user-123'));
      expect(profileService.restoreProfileCalled, isTrue);
      expect(result, contains('Profile identity restored'));
    });

    test('Importing JSON from OTHER user does NOT change current UUID', () async {
      final profileService = TestProfileService('user-123', 'User A');
      final importService = ImportService(
        eventRepo: eventRepo,
        metricRepo: metricRepo,
        trackingWindowRepo: trackingWindowRepo,
        profileService: profileService,
      );

      final payload = {
        'profile': {
          'uuid': 'other-user-456',
          'nickname': 'User B',
        },
      };

      final jsonStr = jsonEncode(payload);
      final tempFile = File('${Directory.systemTemp.path}/test_import_other.json');
      await tempFile.writeAsString(jsonStr);

      FilePicker.platform = MockFilePicker(FilePickerResult([
        PlatformFile(
          name: 'export.json',
          size: jsonStr.length,
          path: tempFile.path,
        ),
      ]));

      final result = await importService.importData();

      // Clean up temp file
      if (await tempFile.exists()) {
        await tempFile.delete();
      }

      // The profile service's UUID should remain unchanged (still 'user-123')
      expect(profileService.uuid, equals('user-123'));
      expect(profileService.restoreProfileCalled, isFalse);
      expect(result, isNot(contains('Profile identity restored')));
    });
  });
}
