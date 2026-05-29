// ignore_for_file: avoid_web_libraries_in_flutter, uri_does_not_exist
import 'dart:async';
import 'dart:js_util' as js_util;
import 'package:flutter/foundation.dart';
import 'package:js/js.dart';

@JS('pwaPush.requestPermission')
external Object _jsRequestPermission();

@JS('pwaPush.getPermissionStatus')
external String _jsGetPermissionStatus();

@JS('pwaPush.subscribeToPush')
external Object _jsSubscribeToPush(String vapidPublicKey);

@JS('pwaPush.unsubscribeFromPush')
external Object _jsUnsubscribeFromPush();

class PwaPushInterop {
  static bool get isSupported => true;

  static Future<String> requestPermission() async {
    try {
      final promise = _jsRequestPermission();
      final result = await js_util.promiseToFuture(promise);
      return result.toString();
    } catch (e) {
      debugPrint('[PwaPushInterop] requestPermission failed: $e');
      return 'unsupported';
    }
  }

  static String getPermissionStatus() {
    try {
      return _jsGetPermissionStatus();
    } catch (e) {
      debugPrint('[PwaPushInterop] getPermissionStatus failed: $e');
      return 'unsupported';
    }
  }

  static Future<String?> subscribe(String vapidPublicKey) async {
    try {
      final promise = _jsSubscribeToPush(vapidPublicKey);
      final result = await js_util.promiseToFuture(promise);
      return result.toString();
    } catch (e) {
      debugPrint('[PwaPushInterop] subscribe failed: $e');
      return null;
    }
  }

  static Future<bool> unsubscribe() async {
    try {
      final promise = _jsUnsubscribeFromPush();
      final result = await js_util.promiseToFuture(promise);
      return result as bool;
    } catch (e) {
      debugPrint('[PwaPushInterop] unsubscribe failed: $e');
      return false;
    }
  }
}
