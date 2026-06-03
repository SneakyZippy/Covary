// Javascript Web Push Interoperability Helpers for Flutter Dart Client
window.pwaPush = {
  requestPermission: async function() {
    if (!('Notification' in window)) return 'unsupported';
    const permission = await Notification.requestPermission();
    return permission;
  },

  getPermissionStatus: function() {
    if (!('Notification' in window)) return 'unsupported';
    return Notification.permission;
  },

  subscribeToPush: async function(vapidPublicKey) {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) {
      throw new Error('Push notifications are not supported in this browser.');
    }

    const registration = await navigator.serviceWorker.ready;
    let subscription = await registration.pushManager.getSubscription();

    // If not subscribed, request a subscription with the public VAPID key
    if (!subscription) {
      const convertedVapidKey = urlBase64ToUint8Array(vapidPublicKey);
      subscription = await registration.pushManager.subscribe({
        userVisibleOnly: true,
        applicationServerKey: convertedVapidKey
      });
    }

    return JSON.stringify(subscription);
  },

  unsubscribeFromPush: async function() {
    if (!('serviceWorker' in navigator)) return false;
    const registration = await navigator.serviceWorker.ready;
    const subscription = await registration.pushManager.getSubscription();
    if (subscription) {
      return await subscription.unsubscribe();
    }
    return false;
  },

  getQueuedEvents: async function() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('covary_pwa_events', 1);
      request.onupgradeneeded = function(e) {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('queued_events')) {
          db.createObjectStore('queued_events', { keyPath: 'id', autoIncrement: true });
        }
      };
      request.onsuccess = function(e) {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('queued_events')) {
          resolve("[]");
          return;
        }
        const transaction = db.transaction(['queued_events'], 'readonly');
        const store = transaction.objectStore('queued_events');
        const getRequest = store.getAll();
        getRequest.onsuccess = function() {
          resolve(JSON.stringify(getRequest.result));
        };
        getRequest.onerror = function() {
          reject(getRequest.error);
        };
      };
      request.onerror = function(e) {
        reject(e.target.error);
      };
    });
  },

  clearQueuedEvents: async function() {
    return new Promise((resolve, reject) => {
      const request = indexedDB.open('covary_pwa_events', 1);
      request.onsuccess = function(e) {
        const db = e.target.result;
        if (!db.objectStoreNames.contains('queued_events')) {
          resolve(true);
          return;
        }
        const transaction = db.transaction(['queued_events'], 'readwrite');
        const store = transaction.objectStore('queued_events');
        const clearRequest = store.clear();
        clearRequest.onsuccess = function() {
          resolve(true);
        };
        clearRequest.onerror = function() {
          reject(clearRequest.error);
        };
      };
      request.onerror = function(e) {
        reject(e.target.error);
      };
    });
  }
};

// VAPID keys are base64url encoded and must be converted to a Uint8Array for the browser Push API
function urlBase64ToUint8Array(base64String) {
  const padding = '='.repeat((4 - base64String.length % 4) % 4);
  const base64 = (base64String + padding)
    .replace(/\-/g, '+')
    .replace(/_/g, '/');

  const rawData = window.atob(base64);
  const outputArray = new Uint8Array(rawData.length);

  for (let i = 0; i < rawData.length; ++i) {
    outputArray[i] = rawData.charCodeAt(i);
  }
  return outputArray;
}
