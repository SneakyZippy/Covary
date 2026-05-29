// Conditional export to handle PWA push notifications cross-platform (Web vs Mobile/Desktop)
export 'pwa_push_stub.dart'
    if (dart.library.html) 'pwa_push_web.dart';
