import 'dart:async';

class PwaPushInterop {
  static bool get isSupported => false;

  static Future<String> requestPermission() async {
    return 'unsupported';
  }

  static String getPermissionStatus() {
    return 'unsupported';
  }

  static Future<String?> getSubscription() async {
    return null;
  }

  static Future<String?> subscribe(String vapidPublicKey) async {
    return null;
  }

  static Future<bool> unsubscribe() async {
    return false;
  }

  static Future<String?> getQueuedEvents() async {
    return null;
  }

  static Future<bool> clearQueuedEvents() async {
    return false;
  }

  static Future<void> hardRefresh() async {}
}
