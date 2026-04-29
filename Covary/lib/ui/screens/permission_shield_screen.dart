import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import '../../services/app_usage_service.dart';
import '../../services/health_service.dart';
import '../../services/passive_sensing_service.dart';

/// The Permission Shield — a research consent & permission onboarding screen.
///
/// This screen is presented to the user before any Health Connect or App Usage
/// permissions are requested. It clearly explains:
/// - **Why** Covary needs each permission (research context).
/// - **What data** is collected and where it goes (local-only).
/// - **How** to grant special permissions that require a Settings deep-link.
///
/// The screen re-checks permission states when the user returns from system
/// settings (via [AppLifecycleState.resumed]), so the status indicators update
/// in real time without requiring a manual refresh.
///
/// ## Thesis Note
/// Informed consent is a cornerstone of ethical HCI research. This screen
/// design follows the "Privacy Nutrition Label" principle — giving users
/// concise, plain-language explanations before asking for sensitive access.
/// It is accessible at any time via Settings → Data Permissions.
class PermissionShieldScreen extends StatefulWidget {
  const PermissionShieldScreen({super.key});

  @override
  State<PermissionShieldScreen> createState() => _PermissionShieldScreenState();
}

class _PermissionShieldScreenState extends State<PermissionShieldScreen>
    with WidgetsBindingObserver {
  // Permission states — updated on init and every time the app resumes.
  bool _healthGranted = false;
  bool _usageGranted = false;
  bool _notificationsGranted = false;
  bool _batteryIgnored = false;

  // Whether a sync is currently in progress (for the loading indicator).
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    // Register as an AppLifecycle observer so we can re-check permissions
    // when the user returns from the Android Settings screen.
    WidgetsBinding.instance.addObserver(this);
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Called by Flutter whenever the app lifecycle state changes.
  ///
  /// When the user returns from the Usage Access settings page, the state
  /// transitions from [AppLifecycleState.paused] → [AppLifecycleState.resumed].
  /// We use this to refresh permission indicators without any extra UI controls.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permissions silently; the setState will trigger a UI rebuild.
      _checkPermissions();
    }
  }

  /// Queries actual permission states from the OS and updates local state.
  Future<void> _checkPermissions() async {
    final healthService = context.read<HealthService>();
    final appUsageService = context.read<AppUsageService>();

    final healthResult = await healthService.hasPermissions();
    final usageResult = await appUsageService.isPermissionGranted();
    final notifResult = await AwesomeNotifications().isNotificationAllowed();
    final batteryResult = await Permission.ignoreBatteryOptimizations.isGranted;

    if (!mounted) return;
    setState(() {
      _healthGranted = healthResult;
      _usageGranted = usageResult;
      _notificationsGranted = notifResult;
      _batteryIgnored = batteryResult;
    });
  }

  /// Triggers an immediate passive sync cycle.
  ///
  /// This gives the user instant feedback that the permissions are working and
  /// gives the researcher an early baseline data point. Latency is logged as 0
  /// since this is a system-triggered operation.
  Future<void> _runSyncNow() async {
    setState(() => _isSyncing = true);
    try {
      final service = context.read<PassiveSensingService>();
      await service.syncAll();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Sync complete! Data saved locally.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync error: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Theme.of(context).colorScheme.errorContainer,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Data Permissions'),
        centerTitle: false,
        backgroundColor: colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // ── Research Context Banner ──────────────────────────────────────
          _ResearchContextCard(),

          const SizedBox(height: 16),

          // ── Health Connect ───────────────────────────────────────────────
          _PermissionCard(
            icon: Icons.favorite_rounded,
            iconColor: colorScheme.error,
            title: 'Health Connect',
            subtitle: 'Sleep duration & step count',
            explanation:
                'Covary reads your nightly sleep duration and daily step '
                'count from Google Health Connect. These are the two objective '
                'health variables in the research model.\n\n'
                'All data stays on your device and is only exported when you '
                'choose to share it.',
            isGranted: _healthGranted,
            buttonLabel: _healthGranted ? 'Granted ✓' : 'Grant Health Access',
            onGrant: _healthGranted
                ? null
                : () async {
                    final service = context.read<HealthService>();
                    await service.requestPermissions();
                    await _checkPermissions();
                  },
          ),

          const SizedBox(height: 12),

          // ── App Usage Stats ──────────────────────────────────────────────
          _PermissionCard(
            icon: Icons.bar_chart_rounded,
            iconColor: colorScheme.primary,
            title: 'App Usage Stats',
            subtitle: 'Total & social screen time',
            explanation:
                'Covary measures your daily total screen time, time spent '
                'in Social Media apps, and time in Entertainment apps.\n\n'
                'This is a special Android permission that must be enabled '
                'manually. Tap the button below — you will be taken to the '
                'Usage Access settings. Toggle Covary ON, then come back.',
            isGranted: _usageGranted,
            buttonLabel: _usageGranted
                ? 'Granted ✓'
                : 'Open Usage Access Settings',
            onGrant: _usageGranted
                ? null
                : () async {
                    final service = context.read<AppUsageService>();
                    await service.openPermissionSettings();
                    // Permission check will re-run in didChangeAppLifecycleState.
                  },
          ),

          const SizedBox(height: 12),

          // ── Notifications ──────────────────────────────────────────────
          _PermissionCard(
            icon: Icons.notifications_active_rounded,
            iconColor: Colors.teal,
            title: 'Notifications',
            subtitle: 'EMA Prompts & Reminders',
            explanation:
                'Covary needs notification access to send you Ecological '
                'Momentary Assessment (EMA) prompts during the day.\n\n'
                'You will receive 4 daily reminders (Morning, Lunch, Afternoon, '
                'Bedtime) and you can adjust the schedule in Settings.',
            isGranted: _notificationsGranted,
            buttonLabel: _notificationsGranted
                ? 'Granted ✓'
                : 'Open Notification Settings',
            onGrant: _notificationsGranted
                ? null
                : () async {
                    final allowed = await AwesomeNotifications()
                        .requestPermissionToSendNotifications(
                          permissions: [
                            NotificationPermission.Alert,
                            NotificationPermission.Sound,
                            NotificationPermission.Badge,
                            NotificationPermission.Vibration,
                            NotificationPermission.Light,
                          ],
                        );
                    if (!allowed) {
                      // Fallback to notification settings page if prompt is denied or unavailable
                      await AwesomeNotifications().showNotificationConfigPage();
                    }
                    _checkPermissions();
                  },
          ),

          const SizedBox(height: 12),

          // ── Battery Optimization ─────────────────────────────────────────
          _PermissionCard(
            icon: Icons.battery_charging_full_rounded,
            iconColor: Colors.orange,
            title: 'Battery Optimization',
            subtitle: 'Recommended for reliable background sync',
            explanation:
                'Some Android devices use aggressive battery management that can '
                'prevent background syncs from running every 4 hours. Exempting '
                'Covary ensures research data is collected reliably.\n\n'
                'This is optional — the app will still work, but syncs may be '
                'delayed on heavily restricted devices.',
            isGranted: _batteryIgnored,
            buttonLabel: _batteryIgnored
                ? 'Exempted ✓'
                : 'Disable Battery Optimization',
            onGrant: _batteryIgnored
                ? null
                : () async {
                    try {
                      // ignore: deprecated_member_use
                      await Permission.ignoreBatteryOptimizations.request();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Could not open battery settings. '
                              'Please disable optimization manually in your device settings.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                    // State will update via app resume lifecycle
                  },
          ),

          const SizedBox(height: 24),

          // ── Sync Now CTA ─────────────────────────────────────────────────
          AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: (_healthGranted || _usageGranted || _notificationsGranted)
                ? 1.0
                : 0.4,
            child: FilledButton.icon(
              onPressed:
                  (_healthGranted || _usageGranted || _notificationsGranted) &&
                      !_isSyncing
                  ? _runSyncNow
                  : null,
              icon: _isSyncing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.sync_rounded),
              label: Text(_isSyncing ? 'Syncing…' : 'Sync Data Now'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),
          Text(
            'The 4-hour automatic sync will also run in the background.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Research Context Banner
// =============================================================================

/// A banner card explaining the data collection purpose of the study.
///
/// Shown at the top of the Permission Shield to establish the research
/// context before any permission requests are made.
class _ResearchContextCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.primaryContainer, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_rounded,
                  color: colorScheme.primary,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Research Data Collection',
                  style: textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Covary is a Bachelor\'s Thesis research tool studying the '
              'correlation between digital metrics, health data, and '
              'subjective well-being.',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Local-only · No cloud · Manual export only',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Permission Card
// =============================================================================

/// A card representing a single permission item with a status indicator
/// and a grant/settings button.
///
/// The [isGranted] indicator updates reactively in [_PermissionShieldScreenState]
/// via [AppLifecycleState.resumed] (for settings deep-links) and direct
/// permission dialog responses.
class _PermissionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String explanation;
  final bool isGranted;
  final String buttonLabel;
  final VoidCallback? onGrant;

  const _PermissionCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.explanation,
    required this.isGranted,
    required this.buttonLabel,
    required this.onGrant,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header row ---
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // --- Status indicator ---
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: isGranted
                      ? Icon(
                          Icons.check_circle_rounded,
                          key: const ValueKey('granted'),
                          color: Colors.green,
                          size: 28,
                        )
                      : Icon(
                          Icons.radio_button_unchecked_rounded,
                          key: const ValueKey('pending'),
                          color: colorScheme.onSurfaceVariant,
                          size: 28,
                        ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // --- Explanation text ---
            Text(
              explanation,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),

            const SizedBox(height: 16),

            // --- Grant button ---
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onGrant,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: isGranted
                      ? Colors.green.withAlpha(30)
                      : colorScheme.secondaryContainer,
                  foregroundColor: isGranted
                      ? Colors.green
                      : colorScheme.onSecondaryContainer,
                ),
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
