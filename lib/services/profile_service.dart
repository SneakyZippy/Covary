import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';

/// Keys used in [SharedPreferences] for profile data.
const _kUserUuid = 'user_uuid';
const _kNickname = 'nickname';
const _kFirstLaunchAt = 'first_launch_at';
const _kHasSeenOnboarding = 'has_seen_onboarding';

/// Service responsible for user identity and profile management.
///
/// On first launch, generates a persistent UUID v4 that serves as the
/// user's identity across all exported data. The UUID is stored in
/// [SharedPreferences] and never changes.
///
/// Nicknames are cosmetic — they personalize the UI but all data is
/// always tied to [uuid]. Every nickname change is recorded as a
/// [EventCategory.meta] event for research traceability.
///
/// Usage:
/// ```dart
/// final profileService = ProfileService();
/// await profileService.init(database);
/// print(profileService.uuid);     // e.g. "f47ac10b-58cc-..."
/// print(profileService.nickname); // e.g. "Max"
/// ```
class ProfileService extends ChangeNotifier {
  /// The user's persistent identifier. Set once on first launch.
  String _uuid = '';

  /// The user's display name. Editable at any time.
  String _nickname = '';

  /// The timestamp of the first time the app was launched.
  DateTime? _firstLaunchAt;

  /// Whether [init] has completed successfully.
  bool _isInitialized = false;

  /// Whether the app detected a restored database without preferences.
  bool _hasRestoredData = false;

  /// Whether the user has completed the initial tutorial/onboarding.
  bool _hasSeenOnboarding = false;

  /// Reference to the database for logging meta events.
  late final AppDatabase _db;

  // ---------------------------------------------------------------------------
  // Getters
  // ---------------------------------------------------------------------------

  /// The persistent user UUID. Empty string until [init] completes.
  String get uuid => _uuid;

  /// The user's current nickname. Empty string if not set.
  String get nickname => _nickname;

  /// Whether the service has finished initialization.
  bool get isInitialized => _isInitialized;

  /// Whether this is the user's first time launching the app.
  /// Useful for routing to the profile setup screen.
  bool get isFirstLaunch => _nickname.isEmpty && !_hasRestoredData;

  /// Whether the app detected restored data from a cloud backup.
  bool get hasRestoredData => _hasRestoredData;

  /// Whether the user has seen the onboarding slider.
  bool get hasSeenOnboarding => _hasSeenOnboarding;

  /// Returns the current day of the study (Day 1, Day 2, etc.)
  int get studyDay {
    if (_firstLaunchAt == null) return 1;
    final now = DateTime.now();
    // Use the start of each day for calculation
    final startOfFirstDay = DateTime(_firstLaunchAt!.year, _firstLaunchAt!.month, _firstLaunchAt!.day);
    final startOfToday = DateTime(now.year, now.month, now.day);
    return startOfToday.difference(startOfFirstDay).inDays + 1;
  }

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initializes the profile service.
  ///
  /// 1. Reads or generates the [uuid] from [SharedPreferences].
  /// 2. Reads the stored [nickname].
  /// 3. If this is a first launch, logs a `first_launch` meta event.
  ///
  /// Must be called once at app startup before accessing any properties.
  Future<void> init(AppDatabase db) async {
    _db = db;
    final prefs = await SharedPreferences.getInstance();
    
    // Check database to see if we have restored data
    final allEvents = await _db.getAllEvents();

    // --- UUID ---
    final storedUuid = prefs.getString(_kUserUuid);
    if (storedUuid != null) {
      _uuid = storedUuid;
      debugPrint('[ProfileService] Existing user: $_uuid');
    } else {
      if (allEvents.isNotEmpty) {
        _hasRestoredData = true;
        debugPrint('[ProfileService] Restored database detected!');
      } else {
        await _generateNewIdentity(prefs);
      }
    }

    // --- Nickname ---
    _nickname = prefs.getString(_kNickname) ?? '';

    // --- Onboarding ---
    _hasSeenOnboarding = prefs.getBool(_kHasSeenOnboarding) ?? false;

    // --- First Launch Timestamp ---
    final storedLaunch = prefs.getString(_kFirstLaunchAt);
    if (storedLaunch != null) {
      _firstLaunchAt = DateTime.tryParse(storedLaunch);
    } else {
      // If not in prefs, try to find the earliest event in DB to backfill
      final allEvents = await _db.getAllEvents();
      if (allEvents.isNotEmpty) {
        final earliest = allEvents.reduce((a, b) => a.timestamp.isBefore(b.timestamp) ? a : b);
        _firstLaunchAt = earliest.timestamp;
      } else {
        _firstLaunchAt = DateTime.now();
      }
      if (!_hasRestoredData) {
        await prefs.setString(_kFirstLaunchAt, _firstLaunchAt!.toIso8601String());
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _generateNewIdentity(SharedPreferences prefs) async {
    _uuid = const Uuid().v4();
    await prefs.setString(_kUserUuid, _uuid);
    debugPrint('[ProfileService] Generated UUID: $_uuid');

    try {
      await _db.insertEvent(EventsCompanion(
        category: Value(EventCategory.meta),
        label: const Value('first_launch'),
        value: Value(_uuid),
        triggerSource: const Value(TriggerSource.system),
        interactionType: const Value(InteractionType.click),
      ));
      debugPrint('[ProfileService] Logged first_launch event');
    } catch (e) {
      debugPrint('[ProfileService] Error logging first_launch: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Restore Logic
  // ---------------------------------------------------------------------------

  /// Starts a completely fresh session by wiping the database and generating a new ID.
  Future<void> startFresh() async {
    // 1. Wipe the database
    await _db.delete(_db.events).go();
    await _db.delete(_db.customMetrics).go();
    await _db.delete(_db.trackingWindows).go();

    // 2. Clear prefs and generate new identity
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _generateNewIdentity(prefs);
    
    _hasRestoredData = false;
    _firstLaunchAt = DateTime.now();
    await prefs.setString(_kFirstLaunchAt, _firstLaunchAt!.toIso8601String());
    
    notifyListeners();
  }

  /// Attempts to recover the UUID and nickname from the historical database events.
  Future<void> recoverFromDatabase() async {
    final allEvents = await _db.getAllEvents();
    
    // Find the original UUID from the first_launch event
    try {
      final firstLaunchEvent = allEvents.firstWhere(
        (e) => e.category == EventCategory.meta && e.label == 'first_launch'
      );
      _uuid = firstLaunchEvent.value;
    } catch (e) {
      // Fallback: If no first_launch event, generate a new UUID for the old data
      _uuid = const Uuid().v4();
      await _db.insertEvent(EventsCompanion(
        category: Value(EventCategory.meta),
        label: const Value('first_launch'),
        value: Value(_uuid),
        triggerSource: const Value(TriggerSource.system),
        interactionType: const Value(InteractionType.click),
      ));
    }

    // Find the most recent nickname
    try {
      final nicknameEvents = allEvents
          .where((e) => e.category == EventCategory.meta && e.label == 'nickname_changed')
          .toList()
        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
        
      if (nicknameEvents.isNotEmpty) {
        _nickname = nicknameEvents.first.value;
      } else {
        _nickname = 'Recovered User'; // Fallback
      }
    } catch (e) {
      _nickname = 'Recovered User';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserUuid, _uuid);
    await prefs.setString(_kNickname, _nickname);
    
    _hasRestoredData = false;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // Nickname Management
  // ---------------------------------------------------------------------------

  /// Updates the user's nickname and persists it.
  ///
  /// Every change is also recorded as a [EventCategory.meta] event with
  /// `label: 'nickname_changed'` so we have a complete audit trail in the
  /// research dataset.
  ///
  /// [latencyMs] is the time the user spent on the profile screen before
  /// pressing save — an HCI metric required by the thesis.
  Future<void> setNickname(String newNickname, {int latencyMs = 0}) async {
    if (newNickname == _nickname) return; // No-op if unchanged.

    final oldNickname = _nickname;
    _nickname = newNickname.trim();

    // Persist to SharedPreferences.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNickname, _nickname);

    // Log the change as a meta event.
    try {
      await _db.insertEvent(EventsCompanion(
        category: Value(EventCategory.meta),
        label: const Value('nickname_changed'),
        value: Value(_nickname),
        latencyMs: Value(latencyMs),
        triggerSource: const Value(TriggerSource.manual),
        interactionType: const Value(InteractionType.click),
      ));
      debugPrint(
        '[ProfileService] Nickname changed: "$oldNickname" → "$_nickname"',
      );
    } catch (e) {
      debugPrint('[ProfileService] Error logging nickname change: $e');
    }

    notifyListeners();
  }

  /// Restores profile data from an external source (e.g. import).
  Future<void> restoreProfile({required String uuid, required String nickname}) async {
    _uuid = uuid;
    _nickname = nickname;
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserUuid, _uuid);
    await prefs.setString(_kNickname, _nickname);
    
    debugPrint('[ProfileService] Profile restored: $_nickname ($_uuid)');
    notifyListeners();
  }

  /// Marks the onboarding as complete and logs the time spent.
  Future<void> completeOnboarding({int latencyMs = 0}) async {
    _hasSeenOnboarding = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasSeenOnboarding, true);

    try {
      await _db.insertEvent(EventsCompanion(
        category: const Value(EventCategory.meta),
        label: const Value('onboarding_completed'),
        value: const Value('true'),
        latencyMs: Value(latencyMs),
        triggerSource: const Value(TriggerSource.manual),
        interactionType: const Value(InteractionType.click),
      ));
    } catch (e) {
      debugPrint('[ProfileService] Error logging onboarding completion: $e');
    }

    notifyListeners();
  }
}
