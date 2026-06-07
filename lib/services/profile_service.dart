import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/database/app_database.dart';
import '../data/models/enums.dart';
import '../data/repositories/profile_repository.dart';
import '../data/repositories/event_repository.dart';
import '../data/repositories/metric_repository.dart';
import '../data/repositories/tracking_window_repository.dart';

/// Service responsible for user identity and profile management.
///
/// On first launch, generates a persistent UUID v4 that serves as the
/// user's identity across all exported data. The UUID is stored in
/// ProfileRepository and never changes.
///
/// Nicknames are cosmetic — they personalize the UI but all data is
/// always tied to [uuid]. Every nickname change is recorded as a
/// [EventCategory.meta] event for research traceability.
class ProfileService extends ChangeNotifier {
  final ProfileRepository _profileRepo;
  final EventRepository _eventRepo;
  final MetricRepository _metricRepo;
  final TrackingWindowRepository _trackingWindowRepo;

  ProfileService({
    required ProfileRepository profileRepo,
    required EventRepository eventRepo,
    required MetricRepository metricRepo,
    required TrackingWindowRepository trackingWindowRepo,
  })  : _profileRepo = profileRepo,
        _eventRepo = eventRepo,
        _metricRepo = metricRepo,
        _trackingWindowRepo = trackingWindowRepo;

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

  /// Whether the user has enabled developer mode.
  bool _isDeveloperMode = false;

  /// Whether tactile haptic feedback is enabled.
  bool _hapticsEnabled = true;

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

  /// Whether developer mode is enabled.
  bool get isDeveloperMode => _isDeveloperMode;

  /// Whether haptic feedback is enabled.
  bool get hapticsEnabled => _hapticsEnabled;

  /// The timestamp of the user's first app launch. Used to suppress
  /// "missed window" cards for windows that ended before setup.
  DateTime? get firstLaunchAt => _firstLaunchAt;

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

  /// Fast initialization — reads ONLY repositories (no DB queries).
  ///
  /// This is enough to determine the routing decision (onboarding vs app shell)
  /// and should be called before [runApp] to minimize startup delay.
  /// Call [initDeferred] after the first frame for the heavy DB work.
  Future<void> initFast() async {
    // --- UUID ---
    final storedUuid = _profileRepo.getUuid();
    if (storedUuid != null) {
      _uuid = storedUuid;
      debugPrint('[ProfileService] Existing user: $_uuid');
    }

    // --- Nickname ---
    _nickname = _profileRepo.getNickname();

    // --- Onboarding ---
    _hasSeenOnboarding = _profileRepo.getHasSeenOnboarding();

    // --- Developer Mode ---
    _isDeveloperMode = _profileRepo.getIsDeveloperMode();

    // --- Haptic Feedback ---
    _hapticsEnabled = _profileRepo.getBoolSetting('haptics_enabled', defaultValue: true);

    // --- First Launch Timestamp ---
    final storedLaunch = _profileRepo.getFirstLaunchAt();
    if (storedLaunch != null) {
      _firstLaunchAt = storedLaunch;
    } else {
      _firstLaunchAt = DateTime.now();
      await _profileRepo.setFirstLaunchAt(_firstLaunchAt!);
    }

    _isInitialized = true;
    notifyListeners();
  }

  /// Deferred initialization — runs the heavy DB queries after the UI is showing.
  ///
  /// Handles restored-data detection, first-launch timestamp backfill, and
  /// UUID generation for true first launches.
  Future<void> initDeferred() async {
    final allEvents = await _eventRepo.getAllEvents();

    // --- Detect restored data (DB has events but no UUID in prefs) ---
    if (_uuid.isEmpty) {
      if (allEvents.isNotEmpty) {
        _hasRestoredData = true;
        debugPrint('[ProfileService] Restored database detected!');
        notifyListeners(); // Triggers re-route to RestoreSelectionScreen
        return;
      } else {
        await _generateNewIdentity();
      }
    }

    // --- Backfill first launch timestamp from earliest event if needed ---
    final storedLaunch = _profileRepo.getFirstLaunchAt();
    if (storedLaunch == null && allEvents.isNotEmpty) {
      final earliest = allEvents.reduce(
        (a, b) => a.timestamp.isBefore(b.timestamp) ? a : b,
      );
      _firstLaunchAt = earliest.timestamp;
      await _profileRepo.setFirstLaunchAt(_firstLaunchAt!);
    }

    notifyListeners();
  }

  /// Legacy / full initialization — calls both fast and deferred in sequence.
  /// Kept for compatibility with import service and restore flows.
  Future<void> init() async {
    await initFast();
    await initDeferred();
  }

  Future<void> _generateNewIdentity() async {
    _uuid = const Uuid().v4();
    await _profileRepo.setUuid(_uuid);
    debugPrint('[ProfileService] Generated UUID: $_uuid');

    try {
      await _eventRepo.insertEvent(EventsCompanion(
        category: const Value(EventCategory.meta),
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
    await _eventRepo.clearAllEvents();
    await _metricRepo.clearAllMetrics();
    await _trackingWindowRepo.clearAllTrackingWindows();

    // 2. Clear prefs and generate new identity
    await _profileRepo.clear();
    await _generateNewIdentity();
    
    _hasRestoredData = false;
    _firstLaunchAt = DateTime.now();
    await _profileRepo.setFirstLaunchAt(_firstLaunchAt!);
    
    notifyListeners();
  }

  /// Attempts to recover the UUID and nickname from the historical database events.
  Future<void> recoverFromDatabase() async {
    final allEvents = await _eventRepo.getAllEvents();
    
    // Find the original UUID from the first_launch event
    try {
      final firstLaunchEvent = allEvents.firstWhere(
        (e) => e.category == EventCategory.meta && e.label == 'first_launch'
      );
      _uuid = firstLaunchEvent.value;
    } catch (e) {
      // Fallback: If no first_launch event, generate a new UUID for the old data
      _uuid = const Uuid().v4();
      await _eventRepo.insertEvent(EventsCompanion(
        category: const Value(EventCategory.meta),
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

    await _profileRepo.setUuid(_uuid);
    await _profileRepo.setNickname(_nickname);
    
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

    // Persist to ProfileRepository.
    await _profileRepo.setNickname(_nickname);

    // Log the change as a meta event.
    try {
      await _eventRepo.insertEvent(EventsCompanion(
        category: const Value(EventCategory.meta),
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
    
    await _profileRepo.setUuid(_uuid);
    await _profileRepo.setNickname(_nickname);
    
    debugPrint('[ProfileService] Profile restored: $_nickname ($_uuid)');
    notifyListeners();
  }

  /// Marks the onboarding as complete and logs the time spent.
  Future<void> completeOnboarding({
    int latencyMs = 0,
    Map<String, int>? slideLatencies,
  }) async {
    _hasSeenOnboarding = true;
    await _profileRepo.setHasSeenOnboarding(true);

    try {
      await _eventRepo.insertEvent(EventsCompanion(
        category: const Value(EventCategory.meta),
        label: const Value('onboarding_completed'),
        value: const Value('true'),
        latencyMs: Value(latencyMs),
        triggerSource: const Value(TriggerSource.manual),
        interactionType: const Value(InteractionType.click),
      ));

      if (slideLatencies != null) {
        for (var entry in slideLatencies.entries) {
          await _eventRepo.insertEvent(EventsCompanion(
            category: const Value(EventCategory.meta),
            label: Value(entry.key),
            value: Value(entry.value.toString()),
            latencyMs: Value(entry.value),
            triggerSource: const Value(TriggerSource.manual),
            interactionType: const Value(InteractionType.click),
          ));
        }
      }
    } catch (e) {
      debugPrint('[ProfileService] Error logging onboarding completion: $e');
    }

    notifyListeners();
  }

  /// Resets the onboarding state so the user can see the tutorial again.
  Future<void> resetOnboarding() async {
    _hasSeenOnboarding = false;
    await _profileRepo.setHasSeenOnboarding(false);
    notifyListeners();
  }

  /// Toggles developer mode and persists it.
  Future<void> setDeveloperMode(bool value) async {
    if (_isDeveloperMode == value) return;
    _isDeveloperMode = value;
    await _profileRepo.setIsDeveloperMode(value);
    notifyListeners();
  }

  /// Toggles tactile haptic feedback and persists it.
  Future<void> setHapticsEnabled(bool value) async {
    if (_hapticsEnabled == value) return;
    _hapticsEnabled = value;
    await _profileRepo.setBoolSetting('haptics_enabled', value);
    notifyListeners();
  }
}
