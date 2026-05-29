// Custom Master Service Worker for Covary PWA
// Imports Flutter's default caching service worker dynamically
importScripts('flutter_service_worker.js?v=' + (self.serviceWorkerVersion || '1'));

// Listen for Web Push notification payloads dispatched from Supabase Edge Functions
self.addEventListener('push', function(event) {
  if (!event.data) return;
  try {
    const payload = event.data.json();
    const title = payload.title || 'Covary';
    const options = {
      body: payload.body || 'Time for your check-in!',
      icon: 'icons/Icon-192.png',
      badge: 'icons/Icon-192.png',
      data: payload.data || {},
      actions: payload.actions || [] // supports quick button actions on web if specified
    };

    event.waitUntil(
      self.registration.showNotification(title, options)
    );
  } catch (e) {
    console.error('Error handling push event in Service Worker:', e);
  }
});

// Focus or open the PWA window when the user taps/clicks the notification banner
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const targetUrl = self.location.origin + '/';

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
      // 1. If a window is already open, focus it
      for (let i = 0; i < clientList.length; i++) {
        let client = clientList[i];
        if (client.url === targetUrl && 'focus' in client) {
          return client.focus();
        }
      }
      // 2. Otherwise open a new tab/window
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
    })
  );
});
