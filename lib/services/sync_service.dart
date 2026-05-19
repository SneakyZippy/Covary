import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/database/app_database.dart';
import 'profile_service.dart';
import 'supabase_config.dart';

const String _kSupabaseSyncEnabled = 'supabase_sync_enabled';

/// Service responsible for syncing local Drift database events, metrics,
/// and windows to a remote Supabase PostgreSQL instance.
class SyncService extends ChangeNotifier {
  final AppDatabase db;
  final ProfileService profileService;

  bool _syncEnabled = false;
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  String? _syncErrorMessage;
  bool _isSupabaseInitialized = false;

  SyncService({required this.db, required this.profileService});

  /// Whether the user has opted into cloud backup.
  bool get syncEnabled => _syncEnabled;

  /// Whether a sync operation is currently active.
  bool get isSyncing => _isSyncing;

  /// The timestamp of the last successful sync.
  DateTime? get lastSyncTime => _lastSyncTime;

  /// The last recorded sync error message, or null if successful.
  String? get syncErrorMessage => _syncErrorMessage;

  /// Reads user preference and initializes the Supabase client if keys are available.
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _syncEnabled = prefs.getBool(_kSupabaseSyncEnabled) ?? false;

    final url = SupabaseConfig.supabaseUrl.trim();
    final anonKey = SupabaseConfig.supabaseAnonKey.trim();

    if (url.isNotEmpty && anonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: url,
          anonKey: anonKey,
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

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSupabaseSyncEnabled, enabled);
    notifyListeners();

    if (enabled) {
      unawaited(syncNow(force: true));
    }
  }

  /// Gathers all local database records and upserts them to Supabase by the user's UUID.
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
      final events = await db.getAllEvents();
      final customMetrics = await db.getAllCustomMetrics();
      final trackingWindows = await db.getAllTrackingWindows();

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
      debugPrint('[SyncService] Sync succeeded for user: $uuid');
    } catch (e) {
      debugPrint('[SyncService] Sync failed: $e');
      _syncErrorMessage = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
}
