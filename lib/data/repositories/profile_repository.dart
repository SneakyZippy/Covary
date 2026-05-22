import 'package:shared_preferences/shared_preferences.dart';

abstract class ProfileRepository {
  Future<void> init();
  
  String? getUuid();
  Future<void> setUuid(String uuid);
  
  String getNickname();
  Future<void> setNickname(String nickname);
  
  DateTime? getFirstLaunchAt();
  Future<void> setFirstLaunchAt(DateTime dateTime);
  
  bool getHasSeenOnboarding();
  Future<void> setHasSeenOnboarding(bool value);
  
  bool getIsDeveloperMode();
  Future<void> setIsDeveloperMode(bool value);
  
  Future<void> clear();

  bool getBoolSetting(String key, {bool defaultValue = false});
  Future<void> setBoolSetting(String key, bool value);
  String? getStringSetting(String key);
  Future<void> setStringSetting(String key, String value);
  List<String>? getStringListSetting(String key);
  Future<void> setStringListSetting(String key, List<String> value);
  Future<void> removeSetting(String key);
}

class SharedPrefsProfileRepository implements ProfileRepository {
  late final SharedPreferences _prefs;
  
  static const _kUserUuid = 'user_uuid';
  static const _kNickname = 'nickname';
  static const _kFirstLaunchAt = 'first_launch_at';
  static const _kHasSeenOnboarding = 'has_seen_onboarding';
  static const _kIsDeveloperMode = 'is_developer_mode';

  @override
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  @override
  String? getUuid() => _prefs.getString(_kUserUuid);

  @override
  Future<void> setUuid(String uuid) => _prefs.setString(_kUserUuid, uuid);

  @override
  String getNickname() => _prefs.getString(_kNickname) ?? '';

  @override
  Future<void> setNickname(String nickname) => _prefs.setString(_kNickname, nickname);

  @override
  DateTime? getFirstLaunchAt() {
    final str = _prefs.getString(_kFirstLaunchAt);
    return str != null ? DateTime.tryParse(str) : null;
  }

  @override
  Future<void> setFirstLaunchAt(DateTime dateTime) =>
      _prefs.setString(_kFirstLaunchAt, dateTime.toIso8601String());

  @override
  bool getHasSeenOnboarding() => _prefs.getBool(_kHasSeenOnboarding) ?? false;

  @override
  Future<void> setHasSeenOnboarding(bool value) =>
      _prefs.setBool(_kHasSeenOnboarding, value);

  @override
  bool getIsDeveloperMode() => _prefs.getBool(_kIsDeveloperMode) ?? false;

  @override
  Future<void> setIsDeveloperMode(bool value) =>
      _prefs.setBool(_kIsDeveloperMode, value);

  @override
  Future<void> clear() => _prefs.clear();

  @override
  bool getBoolSetting(String key, {bool defaultValue = false}) =>
      _prefs.getBool(key) ?? defaultValue;

  @override
  Future<void> setBoolSetting(String key, bool value) =>
      _prefs.setBool(key, value);

  @override
  String? getStringSetting(String key) => _prefs.getString(key);

  @override
  Future<void> setStringSetting(String key, String value) =>
      _prefs.setString(key, value);

  @override
  List<String>? getStringListSetting(String key) => _prefs.getStringList(key);

  @override
  Future<void> setStringListSetting(String key, List<String> value) =>
      _prefs.setStringList(key, value);

  @override
  Future<void> removeSetting(String key) => _prefs.remove(key);
}
