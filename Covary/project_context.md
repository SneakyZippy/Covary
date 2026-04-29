# Project Context: The Behavioral Metric Tracker (2026)

## 1. Executive Summary

**Goal:** A Bachelor’s Thesis project using Flutter to track the correlation between digital metrics (social media, screen time), health data (sleep, activity), and subjective well-being (mood, fatigue). **Research Focus:** Behavioral feedback loops (e.g., "Doom-scrolling → Bad Sleep → Fatigue") and Human-Computer Interaction (HCI) metrics like notification response latency and dismissal patterns.

## 2. Technical Stack (2026 Standards)

- **Framework:** Flutter (Material 3 UI).
    
- **Local Database:** `drift` (SQLite) for high-integrity, reactive storage.
    
- **Health Integration:** `health` package (wraps Google Health Connect & Apple HealthKit).
    
- **App Usage:**
    
    - **Android:** `usage_stats` (via `PACKAGE_USAGE_STATS` permission).
        
    - **iOS:** Custom `MethodChannel` using native Swift `FamilyControls` and `DeviceActivity` APIs.
        
- **Notification Engine:** `awesome_notifications` (chosen for its native `onDismissActionReceivedMethod` to track swipes).
    
- **Background Tasks:** `workmanager` for periodic data logging (4-hour intervals).
    
- **Export/Sync:** `share_plus` for manual weekly JSON exports via the system Share Sheet.
    

## 3. Data Model: The "Universal Event" (Drift Schema)

Every data point is an "Event" to ensure a clean, flat structure for Python analysis.

```dart
// Drift Table Definition (Simplified)
class Events extends Table {
  TextColumn get id => text().clientDefault(() => uuid.v4())(); // UUID V4
  DateTimeColumn get timestamp => dateTime().withDefault(currentDateAndTime)();
  TextColumn get category => textEnum<EventCategory>()(); // Mood, Behavior, Health, AppUsage, Meta
  TextColumn get label => text().withLength(min: 1, max: 50)(); // e.g., 'Instagram', 'Good Deed'
  TextColumn get value => text()(); // Flexible data storage (String or Double)
  IntColumn get latencyMs => integer().withDefault(const Constant(0))(); // For HCI research
  TextColumn get triggerSource => textEnum<TriggerSource>()(); // Manual, Notification, System
  TextColumn get interactionType => textEnum<InteractionType>()(); // Click, SwipeAway, Snooze
  
  @override
  Set<Column> get primaryKey => {id};
}
```

## 4. Key Implementation Strategies

### A. Notification & HCI Tracking

- **Click Tracking:** Standard `onActionReceivedMethod`.
    
- **Swipe/Dismiss Tracking:** Utilize `awesome_notifications` background listeners to log when a notification is dismissed by the user without being opened.
    
- **Adaptive Prompting:** Logic to check the last 3 `interactionType` values. If all are `SwipeAway`, trigger a UI dialog to suggest rescheduling the notification.
    

### B. User Identity & Privacy

- **UUID:** Static ID generated on first launch for data merging.
    
- **Nickname:** User-editable field for personalization.
    
- **Export:** Weekly batches converted to a single JSON object: `{ "user": { "uuid": "...", "name": "..." }, "data": [...] }`.
    

### C. Dynamic Metrics

- **Customization:** A `CustomMetrics` table stores user-defined metrics.
    
- **Dynamic UI:** The Home Screen renders a `ListView` of "Input Cards" based on which metrics are enabled.
    

## 5. Research Pipeline (Post-Processing)

- **Export Method:** User taps "Export" → JSON file created in temp directory → `share_plus` opens system menu → User shares to **pCloud/Drive/Email**.
    
- **Analysis:** JSON files are imported into a **Jupyter Notebook (Python)**.
    
- **Libraries:** `Pandas` for time-series alignment, `Seaborn` for correlation heatmaps, `SciPy` for T-tests on "Good Deed" impacts.

---

📜 AI Coding Standards: The Behavioral Metric Tracker

1. Architectural Pattern
    - Pattern: Use a Repository Pattern (Data -> Repository -> UI).
    - Data Layer: Drift Database & API Services.
    - Domain Layer: Services that coordinate between the database and the UI.
    - UI Layer: Stateless/Stateful widgets using Provider for state management.
    - State Management: Use the provider package for simplicity and academic clarity.

2. Naming Conventions
    - Classes: PascalCase (e.g., MetricService).
    - Variables/Functions: camelCase (e.g., saveEventToDatabase).
    - Files: snake_case (e.g., metric_service.dart).
    - Database Tables: Plural names (e.g., Events, CustomMetrics, TrackingWindows).

3. UI & Styling (Material 3)
    - Theme: Use Theme.of(context).colorScheme for all colors.
    - Spacing: Use a standard 8dp grid.
    - Widgets: Prefer Card widgets for metric inputs and ListTile for settings.

4. Error Handling & Logging
    - Try-Catch: Wrap all database and sensor (Health/Usage) calls.
    - User Feedback: Use ScaffoldMessenger (Snackbars) to show errors.
    - Logging: Use debugPrint().

5. Documentation Requirements
    - Comments: Every major function must have a brief /// doc comment.
    - Thesis Note: Add comments to complex logic explaining the reasoning.