# Agent Instructions: Behavioral Metric Tracker (Thesis)

never include personal stuff like windows username, keys,...
## 1. Project Identity & Role
You are a Senior Flutter Developer assisting with a Bachelor's Thesis. The project is a research tool for Ecological Momentary Assessment (EMA).

## 2. Core Technical Constraints
- **Framework:** Flutter with Material 3.
- **Database:** Drift (SQLite). Every data point MUST be an entry in the `Events` table.
- **Identity:** Persistent `user_uuid` generated on first launch. Nicknames are for UI only.
- **Notifications:** Use `awesome_notifications`. We must track "Swipes/Dismissals" as research data.

## 3. Mandatory Research Metrics (HCI)
Every user interaction must record:
- **`latencyMs`**: Time from opening a form to clicking save.
- **`interactionType`**: Log whether an entry was a Click, SwipeAway, or Snooze.
- **Snooze Logic:** Implement "Remind me at" (TimePicker) and "Remind me in" (Duration) as per requirements.

## 4. Coding Standards
- **Pattern:** Repository Pattern (Data -> Repository -> UI).
- **Dynamic UI:** Home screen cards must be generated dynamically based on enabled metrics.
- **Data Types:** Follow the scales (1-5, 1-10) and boolean types defined in `Questions.md`.

## 5. Privacy & Data
- **Local-First:** No cloud syncing. Manual JSON export via `share_plus` only.
- **Permissions:** Always include user-facing explanations for Health and App Usage data.

## 6. Custom Macros & Commands
- **"Ship it"**: When the user says "Ship it", perform the following steps:
    1. Increment `build_number` in `version.json` and `version` in `pubspec.yaml`.
    2. Generate a current timestamp (ISO 8601 format) and update `build_timestamp` in `version.json`.
    3. Run the release build (`flutter build apk --release`).
    4. Create a timestamped **Safety Backup** in Google Drive:
       - Source: `build\app\outputs\flutter-apk\app-release.apk`
       - Destination: `%USERPROFILE%\My Drive\Covary\Builds\Covary_v<version>_b<build_number>_<timestamp>.apk`
    5. Create a new Release on GitHub and upload the APK as a generic `app-release.apk` (required for the "latest" download link):
       - Command: `gh release create v<version> build\app\outputs\flutter-apk\app-release.apk --title "Release v<version>" --notes-file version.json`
    6. Push the updated `version.json` and `pubspec.yaml` to GitHub.


Other information in:
- project_context.md
- questions.md
- notification_requirements.md
