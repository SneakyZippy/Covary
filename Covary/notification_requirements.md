## Feature: Smart Notification Reminders
The goal is to provide users with flexible, low-friction options for managing notifications directly from the alert interface.

### Reminder Options
When a notification is received, the user should be presented with two distinct "Snooze" or "Remind Me" methods:

1.  **"Remind me at" (Clock Picker)**
    * **Function:** Allows the user to select a specific point in time.
    * **UI Element:** A clock-style time picker or a list of specific times.
    * **Use Case:** When a user knows exactly when they will be free (e.g., "I'll be home at 6:00 PM").

2.  **"Remind me in" (Duration Input)**
    * **Function:** Allows the user to select a relative time offset.
    * **UI Element:** A text input or quick-select buttons for durations.
    * **Input Examples:** "1 hour," "2 hours," "10 minutes."
    * **Use Case:** When a user needs a quick delay without checking the current time (e.g., "Remind me in 15 minutes").

---

## Design Priority: Ease of Selection
The primary focus for this feature is **user experience (UX)**. The selection process must be:
* **Intuitive:** No learning curve for the user.
* **Fast:** Minimum number of clicks/taps to set the reminder.
* **Accessible:** Large enough touch targets and clear text.
* 