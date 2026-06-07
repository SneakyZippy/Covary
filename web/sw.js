// Custom Master Service Worker for Covary PWA

// Install event - skip waiting to activate immediately
self.addEventListener('install', function(event) {
  self.skipWaiting();
});

// Activate event - claim clients to start controlling them immediately
self.addEventListener('activate', function(event) {
  event.waitUntil(self.clients.claim());
});

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

// Open IndexedDB database for event queueing
function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open('covary_pwa_events', 1);
    request.onupgradeneeded = function(e) {
      const db = e.target.result;
      if (!db.objectStoreNames.contains('queued_events')) {
        db.createObjectStore('queued_events', { keyPath: 'id', autoIncrement: true });
      }
    };
    request.onsuccess = function(e) {
      resolve(e.target.result);
    };
    request.onerror = function(e) {
      reject(e.target.error);
    };
  });
}

// Queue an event locally in IndexedDB to be picked up by Flutter later
function queueEvent(eventObj) {
  return openDatabase().then(db => {
    return new Promise((resolve, reject) => {
      const transaction = db.transaction(['queued_events'], 'readwrite');
      const store = transaction.objectStore('queued_events');
      const request = store.add(eventObj);
      request.onsuccess = () => resolve();
      request.onerror = (e) => reject(e.target.error);
    });
  });
}

// Reschedule snooze notification on Supabase
async function scheduleSnoozeInSupabase(data, delayMinutes) {
  const userUuid = data.user_uuid;
  const supabaseUrl = data.supabase_url;
  const supabaseAnonKey = data.supabase_anon_key;

  if (!userUuid || !supabaseUrl || !supabaseAnonKey) {
    console.error('Missing user_uuid, supabase_url, or supabase_anon_key in notification data.');
    return;
  }

  const registration = await self.registration;
  const subscription = await registration.pushManager.getSubscription();
  if (!subscription) {
    console.error('No active push subscription found.');
    return;
  }

  const now = new Date();
  const scheduledTime = new Date(now.getTime() + delayMinutes * 60000);

  const notificationType = data.notification_type;
  const reminderLabel = data.reminder_label;

  const isMeal = notificationType === 'meal_reminder';
  const title = isMeal
      ? `${reminderLabel || 'Meal'} Reminder (Snoozed)`
      : (data.window_label
          ? `${data.window_label} Check-in (Snoozed)`
          : 'Time for a quick update!');

  const body = isMeal
      ? 'Time to track your meal. What did you have?'
      : 'Please take a moment to record your current status.';

  const newPayload = {
    title: title,
    body: body,
    data: data
  };

  const response = await fetch(`${supabaseUrl}/rest/v1/pwa_push_reminders`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'apikey': supabaseAnonKey,
      'Authorization': `Bearer ${supabaseAnonKey}`
    },
    body: JSON.stringify({
      user_uuid: userUuid,
      subscription: subscription,
      scheduled_for: scheduledTime.toISOString(),
      payload: newPayload,
      sent: false
    })
  });

  if (!response.ok) {
    const errText = await response.text();
    throw new Error(`Failed to schedule snooze in Supabase: ${response.status} ${errText}`);
  }
}

// Focus or open the PWA window when the user taps/clicks the notification banner
self.addEventListener('notificationclick', function(event) {
  event.notification.close();
  const data = event.notification.data || {};
  const action = event.action;

  if (action && action.startsWith('snooze_')) {
    // 1. Snooze Button Clicked
    const minsStr = action.replace('snooze_', '').replace('m', '');
    const minutes = parseInt(minsStr, 10);
    if (!isNaN(minutes)) {
      const interactionEvent = {
        type: 'interaction',
        interactionType: 'snooze',
        value: `+${minutes}m`,
        payload: {
          notification_type: data.notification_type,
          window_id: data.window_id,
          window_label: data.window_label,
          reminder_id: data.reminder_id,
          reminder_label: data.reminder_label
        },
        timestamp: new Date().toISOString()
      };
      
      event.waitUntil(
        Promise.all([
          queueEvent(interactionEvent),
          scheduleSnoozeInSupabase(data, minutes)
        ]).catch(err => console.error('Error handling PWA snooze action:', err))
      );
    }
  } else if (action && action.startsWith('meal_')) {
    // 2. Meal Option Button Clicked (Snack, Meal, Feast)
    let value = '1.0'; // Snack
    if (action === 'meal_meal') value = '2.0';
    if (action === 'meal_feast') value = '3.0';

    const timestamp = new Date().toISOString();
    const interactionEvent = {
      type: 'interaction',
      interactionType: 'click',
      value: value,
      payload: {
        notification_type: data.notification_type,
        reminder_id: data.reminder_id,
        reminder_label: data.reminder_label
      },
      timestamp: timestamp
    };

    const mealEvent = {
      type: 'meal',
      value: value,
      timestamp: timestamp
    };

    event.waitUntil(
      Promise.all([
        queueEvent(interactionEvent),
        queueEvent(mealEvent)
      ]).catch(err => console.error('Error queueing PWA meal action:', err))
    );
  } else {
    // 3. Standard Click (body/banner tap)
    const targetUrl = self.registration.scope;
    const interactionEvent = {
      type: 'interaction',
      interactionType: 'click',
      payload: {
        notification_type: data.notification_type,
        window_id: data.window_id,
        window_label: data.window_label,
        reminder_id: data.reminder_id,
        reminder_label: data.reminder_label
      },
      timestamp: new Date().toISOString()
    };

    event.waitUntil(
      Promise.all([
        queueEvent(interactionEvent),
        clients.matchAll({ type: 'window', includeUncontrolled: true }).then(function(clientList) {
          // Focus existing window if open
          for (let i = 0; i < clientList.length; i++) {
            let client = clientList[i];
            if (client.url.startsWith(targetUrl) && 'focus' in client) {
              return client.focus();
            }
          }
          // Otherwise open a new tab/window
          if (clients.openWindow) {
            return clients.openWindow(targetUrl);
          }
        })
      ]).catch(err => console.error('Error handling PWA click action:', err))
    );
  }
});

// Listen for Swipe Away / Dismiss event
self.addEventListener('notificationclose', function(event) {
  const data = event.notification.data || {};
  if (data.notification_type) {
    const eventObj = {
      type: 'interaction',
      interactionType: 'swipeAway',
      payload: {
        notification_type: data.notification_type,
        window_id: data.window_id,
        window_label: data.window_label,
        reminder_id: data.reminder_id,
        reminder_label: data.reminder_label
      },
      timestamp: new Date().toISOString()
    };
    event.waitUntil(
      queueEvent(eventObj).catch(err => console.error('Error queueing PWA close action:', err))
    );
  }
});

