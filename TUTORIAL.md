# Covary User Guide & Comprehensive Tutorial

Welcome to **Covary**, an advanced, privacy-focused research tool developed for a Bachelor's Thesis in Human-Computer Interaction (HCI). Covary uses **Ecological Momentary Assessment (EMA)** to capture real-time, in-the-moment details about your daily mood, health, digital habits, and behaviors.

This guide covers everything you need to know about navigating the app, customizing your logging, analyzing your patterns, and contributing data to research.

---

## 1. Core Philosophy & Research Mission

Most health trackers only show you simple counts (e.g., your screen time or steps). Covary is designed to close the **Behavioral Feedback Loop**. It runs a local analytics engine directly on your device to show you how different metrics correlate over time (e.g., *"How does my social media usage on Sunday impact my mood on Monday?"*).

### 🔒 Privacy-First Design
- **Local-First Storage:** All logging remains in a secure, local SQLite database on your device.
- **Opt-In Sync:** If you choose to enable the optional **Cloud Backup**, your data is securely sent over HTTPS and backed up to a private Supabase instance using a randomized, anonymous **Research ID (UUID)**. The sync payload is stored as plain JSON in the cloud database, but it is tied only to your anonymous ID—no real-world identifiers (names, emails, passwords) are ever collected or uploaded.
- **Academic Contribution:** To support the research, you can manually export your logs at the end of the study and send the JSON file to the researcher.

---

## 2. Onboarding & Initial Setup

When you launch Covary for the first time, you will go through a setup tour:
1. **Welcome & Restore:** Learn about the app's mission. If you are migrating devices or re-installing, you can tap **Restore from Cloud Backup** and enter your previous 36-character Research ID to recover your records.
2. **Research Presets:** Choose a pre-defined bundle of metrics that fits your logging goals:
   - **Essential:** Focuses on baseline metrics like Mood, Energy, Sleep, and Wellbeing.
   - **Full Circadian:** Expands into circadian anchors and subjective well-being.
   - **Productivity:** Tracks study habits, focus, and screen use.
   - **Health Habits:** Focuses on exercise, nutrition, and symptoms.
   - **All-Inclusive:** Activates every available metric.
3. **Schedule Windows:** Establish your custom tracking slots. These windows represent when the app will nudge you to check in (e.g., Morning check-in, Afternoon check-in, Evening check-in).
4. **Metric Customization:** Toggle individual variables on or off depending on what you want to track.
5. **Profile Nickname:** Pick a nickname. This nickname is only shown in the app's local user interface to personalize greetings (e.g., *"Good morning, Researcher"*).

> [!TIP]
> You can replay this onboarding tour at any time by going to **Settings ➔ System & Info ➔ Show Tutorial Again**.

---

## 3. The Home Screen & Logging Mechanics

The Home Screen is your operational dashboard. It is designed dynamically to highlight current actions and prevent survey fatigue.

```
+--------------------------------------------------------+
|  Good morning 👋                                       |
|  Felix                                                 |
|  [🔥 5 Day Streak]          [📊 120 Total Logs]        |
|  [■][■][■][■][■][■][■][□][□][□][□][□][□][□] (14 Days)  |
+--------------------------------------------------------+
|  Morning Check-in                                      |
|  Ready to track your progress?                         |
|  [               Start Now               ]             |
+--------------------------------------------------------+
|  Quick Track                                           |
|  +--------------------+    +--------------------+      |
|  | ☕ Coffee          |    | 💧 Water           |      |
|  | Today: 2 cups      |    | Today: 500 ml      |      |
|  +--------------------+    +--------------------+      |
+--------------------------------------------------------+
```

### 📅 Active Check-in Cards
If the current time falls within one of your active tracking windows (e.g., morning, afternoon, or evening) and you haven't logged it yet, a prominent **Check-in Card** will appear at the top. 
- Tap **Start Now** to open the guided check-in form.
- The guided form presents questions sequentially based on your active metrics, utilizing 1–5 scales (Mood/Stress), 1–10 sliders (Wellbeing), Yes/No buttons, and number entries.
- **HCI Metric:** The app measures your **latency (in milliseconds)** from opening the form to clicking "Save." This measures how much friction each question introduces.

### ⏳ Missed Session Cards
If a scheduled tracking window passes and you didn't log it, a **Missed Session Card** appears. Covary handles this gracefully:
- **Retrospective Logging:** Tapping **Complete** opens a guided check-in for that missed window's target time, with a warning banner prompting you that subjective ratings may suffer from memory bias.
- **Recall Warning & Dimmings:** Within the missed session card, metrics are split by reliability. Subjective metrics (e.g., mood and stress scale questions) are dimmed and disabled by default with a "Log anyway" override hatch to remind you of potential recall bias, whereas objective, fact-based metrics (e.g., counters, sleep duration) are immediately interactive.
- **Dismissing:** You can swipe the card away or tap "Dismiss" (after confirming via a dialog). Dismissing logs a `SessionDismissed` event with a `SwipeAway` interaction type for research purposes.

### ⚡ Quick Track Grid (Taps & Long-Presses)
Located under the **Quick Track** section, this grid displays metrics configured to be logged anytime.
The gestures here are powerful and context-sensitive:

#### For Counters (e.g., Water Intake, Coffee, Alcohol, Toilet visits):
* **Single Tap:** Instantly logs one unit of that metric (e.g., +250ml water or +1 coffee cup) with a satisfying confetti burst and floating SnackBar. Tapping **UNDO** on the SnackBar will delete the entry immediately.
* **Long Press:** Opens a **Value Slider Sheet** which allows you to:
  1. Slide to select a custom amount (e.g., logging a large 500ml bottle of water or 2 cups of coffee at once).
  2. Change the logging time (e.g., logging a coffee you had 3 hours ago).
  3. Toggle **Save as default**. This changes the value of a **Single Tap** to this new value (e.g., if you always drink from a 500ml bottle, save 500ml as default so a single tap logs 500ml).

#### For Non-Counters (e.g., Mood, Wellbeing, Sport):
* **Single Tap:** Opens the standard input modal for that metric.
* **Long Press:** Opens a time picker first. This allows you to backdate the entry to a specific time today before showing the input card.

### 📈 Activity Overview & Streaks
Tapping the **Streak & Log Counts** section at the top of the Home Screen navigates to your **Activity History**.
- The 14-day grid shows your logging intensity (darker shades of your active theme's primary color represent more frequent daily logging).
- The daily streak tracks consecutive days with at least one active metric log.

### 🕒 Interactive Today's Timeline
At the bottom of the home screen, you will find a chronological list of all logs recorded today.
- **Visual Nodes:** Each log has a colored circle indicating its category (e.g., Blue for Mood, Green for Behavior, Ruby for Health, Coral for Nutrition).
- **Tap to Expand:** Tapping any log in the timeline expands a card detailing its properties:
  - **Category:** The high-level research domain.
  - **Source:** How the log was initiated (`Manual` vs. `Notification` vs. `System`).
  - **Latency:** The time (in seconds) it took to fill out and save the log.

---

## 4. Smart Alerts & Interactive Notifications

Covary's notifications are not just reminders; they are designed to be interactive and adapt to your behaviors.

### 🔕 Snoozing Options
When a check-in reminder arrives on your phone, expanding the notification reveals interactive buttons:
- **Guided Check-in:** Tapping the main body of the notification opens the app directly into the guided check-in screen.
- **Snooze Durations:** Tap a snooze option (e.g., `+15m`, `+1h`) to dismiss the notification and schedule it to trigger again after that duration.
- **Remind At...:** Tapping this option launches a time picker dialog immediately on your screen, allowing you to select a specific time (e.g., 18:30) to be prompted.

> [!NOTE]
> You can change the default snooze duration options in **Settings ➔ Alerts & Preferences ➔ Edit Snooze Duration**.

### 🍽️ Meal Reminders
Covary includes independent meal notifications (Breakfast, Lunch, and Dinner) scheduled in your settings.
- Tapping a meal notification's action buttons (🍪 **Snack**, 🍲 **Meal**, 🍖 **Feast**) logs your nutrition intake directly from your lock screen without needing to open the app.
- If you manually record a meal count on the home screen, Covary is smart enough to detect it and automatically cancels or reschedules the remaining meal reminders for the day.

### 🛡️ Fatigue Detection (Adaptive Prompting)
To prevent prompt annoyance:
- If you swipe away or dismiss three check-in notifications in a row without opening them, the app registers these dismissals (`SwipeAway`).
- On the next launch, Covary will display a **Too Many Reminders?** dialog, suggesting that you adjust your tracking schedules or pause notifications to match your daily routine.

---

## 5. Research Permissions (Platform Setup)

Because Covary measures passive habits like screen time and steps, it requires system-level integrations. If permissions are missing, a red **"Research Data Paused"** banner appears on the Home Screen. Tap it to open the **Permission Shield Screen**.

### 🤖 Android Setup
1. **Health Connect:** Grant Health Connect permissions so Covary can pull your daily Step Count and Sleep Duration.
2. **App Usage (UsageStats):** Used to compute daily Screen Time. 
   - *Android 13+ Note:* Android may gray out this toggle. To fix this, go to your phone's *Settings ➔ Apps ➔ Covary ➔ tap the three dots (⋮) in the top-right ➔ select "Allow restricted settings"*. Then return to the app's permission screen and flip the toggle.
3. **Battery Optimization:** Turn off battery optimization for Covary. This ensures the 4-hour background sync task can fetch steps and screen time reliably.

### 🍎 iOS Setup
1. **PWA-Only Support:** On iOS, Covary is supported exclusively as a Progressive Web App (PWA) installed from Safari.
2. **Platform Restrictions:** Because PWAs on iOS do not have access to native background sensing APIs (like HealthKit or screen-time tracking), automatic fetching of steps, sleep, and app usage is disabled.
3. **Manual Logging & Imports:** You can track these categories manually or import standardized data files in the app settings to backfill them.

---

## 6. On-Device Analytics Engine

Tapping the **Analytics** tab opens a dashboard that runs heavy statistical processing locally on background threads (isolates) to prevent UI stuttering.

| Analytics Tool | Description | Best Practices |
| :--- | :--- | :--- |
| **Usage Trends** | Graphs your daily screen time, hourly app breakdown, and category split (social media vs. entertainment). | Check regularly to view your overall digital consumption. |
| **Correlation Matrix** | Displays a heatmap representing Spearman's Rank Correlation between any two active metrics. | Works best with **at least 14 days of data**. |
| **HCI Metrics** | Visualizes your prompt interaction patterns (clicks vs. swipes vs. snoozes) and response latencies over time. | Helps identify which metrics are causing fatigue. |
| **Data Quality** | Graphs your daily compliance rates (completed vs. missed logs) and reliance on retrospective logging. | High compliance ensures more statistically significant correlations. |
| **Metric Insights** | Allows you to select an individual metric to view its daily averages and circadian rhythms (e.g., mood levels in morning vs. evening). | Use to pinpoint specific times of day when habits peak. |
| **Lagged Trend** | Analyzes delayed effects (e.g., poor sleep today correlates with high stress tomorrow) using a selectable offset of **1 to 7 days**. | Essential for finding causal chains. |

---

## 7. Data Management & Settings

The Settings Screen ([settings_screen.dart](file:///c:/BachelorProjekt/Covary/lib/ui/screens/settings_screen.dart)) houses all configuration and file management tools.

### ⚙️ Custom Metrics & Windows

> [!WARNING]
> Try not to change metrics too frequently while active tracking is underway. Changing labels or input types can make it difficult to align and query your historical records reliably, as there is no automatic migration path for existing data when its schema changes.

- **Tracked Metrics:** Rename, reorder, delete custom metrics, or change their input types (yes/no, Likert scales, counters).
- **Tracking Windows:** Adjust start/end hours of your prompts or change trigger times.
- **App Categories:** Define which package names on your phone fall under "Social Media" or "Entertainment" to refine screen-time metrics.

### 💾 Backup & Restores
- **Enable Cloud Backup:** Securely syncs your database payload to Supabase. Tap **Backup Now** to trigger an instant sync.
- **Restore / Merge:** Input your 36-character Research ID to download and merge your previous profile and history.

### 📂 Local Data Explorer & Exports
- **Detailed Records:** A raw database browser. You can search, inspect, and delete individual event rows from your SQLite tables.
- **Export Data (JSON):** Generates a standardized JSON backup of your events to share via the system share sheet.
- **Submit to Researcher:** Automatically compiles permitted metrics and drafts an email package to send to the thesis author (`felix.zoeggeler@edu.fh-joanneum.at`).
