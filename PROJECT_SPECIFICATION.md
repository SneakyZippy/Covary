# Covary: Project Specification & Technical Overview

## 1. Vision & Purpose
**Covary** is a behavioral research tool developed for a Bachelor's Thesis in Human-Computer Interaction (HCI). It utilizes **Ecological Momentary Assessment (EMA)** to track and analyze the relationships between digital habits, physical health, and subjective well-being.

The goal is to move beyond simple data collection and provide users with a "Behavioral Feedback Loop"—allowing them to see, in real-time and on-device, how their actions (e.g., screen time, exercise) correlate with their mental state (e.g., mood, stress).

## 2. Core Philosophy
- **Local-First:** All sensitive data is stored exclusively on the user's device in a local SQLite database by default. If a user enables the optional Cloud Backup, their records are synced to Supabase (meaning it is no longer local-only).
- **Opt-In Cloud Backup:** Users can optionally enable secure synchronization to a private Supabase instance. This remains disabled by default. On PWA (Web), scheduled notification details (names and times) are stored on Supabase to enable push notifications.

## 3. Technical Architecture
- **Framework:** Flutter (Material 3 UI).
- **Cross-Platform Deployment:** Must always support running on Android as a native APK, as well as on iOS/Android as a Progressive Web App (PWA).
- **Local Database:** `drift` (SQLite) for reactive, high-integrity storage.
- **Cloud Backend:** `Supabase` (client-side SDK) for optional database backup and syncing.
- **State Management:** `provider` (chosen for academic clarity and reliability).
- **Notifications:** `awesome_notifications` for high-fidelity interaction tracking.
- **Background Processing:** `workmanager` for periodic passive data syncing.

## 4. The "Universal Event" Data Model
To ensure maximum flexibility and clean analysis, every single data point in Covary is stored as a row in a flat **Events** table:

| Column | Type | Description |
| :--- | :--- | :--- |
| `id` | UUID | Unique identifier (v4). |
| `timestamp` | DateTime | When the event occurred (ISO 8601). |
| `category` | Enum | `mood`, `behavior`, `health`, `appUsage`, `meta`, etc. |
| `label` | String | Specific metric name (e.g., 'Steps', 'Instagram'). |
| `value` | String | Flexible value storage (Double, Int, or Bool as string). |
| `latencyMs` | Int | **HCI Metric:** Time from prompt opening to save. |
| `triggerSource`| Enum | `manual`, `notification`, or `system`. |
| `interactionType`| Enum | `click`, `swipeAway`, or `snooze`. |
| `sessionId` | String? | Correlates related events (e.g., all answers in one check-in). |

## 5. Metric Domains
### A. Passive Sensing (Objective)
- **Android:** Direct integration via `Health Connect` (not implemented yet) (Steps, Sleep) and `UsageStats` (Screen Time).
- **iOS:** Currently (not available) utilizes an **Export/Import Method**. Users can import health/usage data via standardized files until native `DeviceActivity` and `HealthKit` integrations are finalized.
- **Metrics:** Total screen time, social media vs. entertainment split, step count, sleep duration/quality.

### B. Active Logging (Subjective)
- **Well-being:** Mood, Energy, Stress (1-5 scales), Overall Wellbeing (1-10).
- **Behaviors:** Binary (Y/N) or counter-based metrics like Sport, Journaling, Good Deeds, and Mindfulness.
- **Customization:** Users can define and reorder their own metrics.

### C. HCI Research Metrics
- **Interaction Distribution:** Tracking how often users engage vs. ignore prompts (Clicks vs. Swipes).
- **Response Latency:** Measuring "Prompt Friction"—how long it takes to process a question.
- **Snooze Logic:** Offering "Remind me at" (Time) and "Remind me in" (Duration) to reduce burden.

## 6. On-Device Analytics Engine
The core of the "Calculate on Device" shift. Covary processes the `Events` table locally to generate insights:

- **Correlation Matrix:** Calculates Spearman's Rank Correlation between any two metrics to find hidden patterns.
- **Lagged Correlations:** Enables users to see delayed effects (e.g., "How does my screen time on Monday affect my mood on Tuesday?"). Selectable offsets from **1 to 7 days**.
- **Trend Analysis:** Weekly and monthly aggregation of usage and health data.
- **Isolate-Based Processing:** Heavy statistical math is performed on background threads to prevent UI stutters.

## 7. Adaptive Research Design
Covary is not just a tracker; it's an adaptive tool:
- **Prompt Fatigue Detection:** If the app detects a pattern of `swipeAway` interactions, it suggests rescheduling notifications to a different time window.
- **Compliance Tracking:** Visualizes "Recall Reliability"—showing how consistent the user is with their logging to ensure high-quality research data.

## 8. Opt-In Cloud Backup Architecture
To facilitate data durability and seamless device transfers without compromising user privacy, Covary provides an optional **Cloud Backup** powered by Supabase.

### A. Security & Isolation
- **No Global Sync:** Data is never synced automatically to a public cloud unless the user explicitly toggles the feature on via **Settings > Data Management > Enable Cloud Backup**.
- **Credential Protection:** Supabase credentials (URL, anonymous publishable API key) are kept in `lib/services/supabase_config.dart` which is ignored in Git tracking.
- **Anonymous Identity:** Uploaded rows are identified exclusively by the persistent `user_uuid` generated during onboarding. Display nicknames are stored for UI personalization but no real-world identifying data (email, name, phone) is collected.

### B. Remote SQL Schema
The remote PostgreSQL database on Supabase mirrors the local Drift database tables in a single compressed JSON payload:

```sql
create table if not exists public.user_syncs (
  uuid uuid primary key,
  nickname text,
  synced_at timestamp with time zone not null default now(),
  payload jsonb not null
);

alter table public.user_syncs enable row level security;

create policy "Allow public upsert by UUID"
on public.user_syncs for all using (true) with check (true);
```

### C. Sync Triggers
When cloud backup is enabled, the app schedules sync tasks under two triggers:
1. **Startup Sync:** Fires when the application is launched, immediately after the profile UUID is resolved.
2. **Resume Sync:** A `WidgetsBindingObserver` monitors application lifecycle changes and initiates a silent background sync whenever the application state changes back to `resumed` (e.g., app unlocked or reopened).
