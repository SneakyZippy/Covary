import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../services/profile_service.dart';
import '../../data/models/enums.dart';
import 'package:covary/services/theme_service.dart';
import 'profile_setup_screen.dart';
import 'permission_shield_screen.dart';
import 'app_category_manager_screen.dart';
import 'debug_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/update_service.dart';
import '../../services/import_service.dart';
import '../../services/sync_service.dart';
import '../../services/notification_service.dart';
import 'package:flutter/services.dart';
import '../widgets/sync_summary_dialog.dart';
import '../widgets/metric_icon.dart';
import '../../services/metric_service.dart';
import '../../data/models/metric_definition.dart';

import 'metrics_screen.dart';
import 'tracking_windows_screen.dart';
import 'onboarding_screen.dart';
import 'meal_reminders_screen.dart';
import 'raw_data_screen.dart';
import '../widgets/help_button.dart';


/// Settings screen for managing profile, notifications, and data.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  int _devTapCount = 0;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileService = context.watch<ProfileService>();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // --- Logo & Branding ---
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  gradient: LinearGradient(
                    colors: [
                      colorScheme.surfaceContainerHighest.withAlpha(60),
                      colorScheme.surfaceContainer.withAlpha(30),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: colorScheme.primary.withAlpha(30),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(40),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    const Align(
                      alignment: Alignment.topRight,
                      child: AppBarHelpButton(screenKey: 'settings'),
                    ),
                    Column(
                      children: [
                        _GlowingAppIcon(colorScheme: colorScheme),
                        const SizedBox(height: 16),
                        Text(
                          'COVARY',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 6,
                            color: colorScheme.primary,
                            shadows: [
                              Shadow(
                                color: colorScheme.primary.withAlpha(120),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'HCI BEHAVIORAL RESEARCH PLATFORM',
                          style: textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant.withAlpha(180),
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // --- Profile card ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        colorScheme.surfaceContainerHighest.withAlpha(80),
                        colorScheme.surfaceContainer.withAlpha(50),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: colorScheme.outlineVariant.withAlpha(80),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha(20),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ProfileSetupScreen(),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    colorScheme.primary,
                                    colorScheme.secondary,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: colorScheme.primary.withAlpha(40),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Icon(
                                Icons.person_rounded,
                                color: colorScheme.onPrimary,
                                size: 26,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    profileService.nickname.isNotEmpty
                                        ? profileService.nickname
                                        : 'Set Nickname',
                                    style: textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        'RESEARCH ID: ',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant.withAlpha(180),
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                      Text(
                                        profileService.uuid.substring(0, 8).toUpperCase(),
                                        style: textTheme.bodySmall?.copyWith(
                                          fontFamily: 'monospace',
                                          color: colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: colorScheme.onSurfaceVariant.withAlpha(150),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // --- Appearance Section ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'Appearance'),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _ThemeSettingsSection(),
              ),
            ),

            // --- Alerts & Preferences ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'Alerts & Preferences'),
            ),
            SliverToBoxAdapter(
              child: _SettingsCardGroup(
                children: [
                  const _NotificationSettingsSection(),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.restaurant_rounded, color: colorScheme.primary, size: 20),
                    title: 'Meal Reminders',
                    subtitle: 'Schedule alerts with quick Snack/Meal/Feast buttons',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MealRemindersScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  Consumer<ProfileService>(
                    builder: (context, profileService, child) {
                      return _SettingsSwitchTile(
                        leading: Icon(
                          Icons.vibration_rounded,
                          color: colorScheme.primary,
                          size: 20,
                        ),
                        title: 'Tactile Haptic Feedback',
                        subtitle: 'Vibrate device slightly on interactions and saves',
                        value: profileService.hapticsEnabled,
                        onChanged: (bool value) async {
                          await profileService.setHapticsEnabled(value);
                        },
                      );
                    },
                  ),
                  if (kIsWeb) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      height: 1,
                      color: colorScheme.outlineVariant.withAlpha(80),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.primary.withAlpha(50),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.info_outline_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'PWA Web Push: To receive notifications in web browsers, scheduled reminder names and times are stored securely on Supabase so they can be pushed to your device.',
                                style: textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // --- Research & Sensing ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'Research & Sensing'),
            ),
            SliverToBoxAdapter(
              child: _SettingsCardGroup(
                children: [
                  _SettingsTile(
                    leading: Icon(Icons.tune_rounded, color: colorScheme.primary, size: 20),
                    title: 'Tracked Metrics',
                    subtitle: 'Manage habits and measurement scales',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MetricsScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.schedule_rounded, color: colorScheme.primary, size: 20),
                    title: 'Tracking Windows',
                    subtitle: 'Define custom time slots for metrics',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TrackingWindowsScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.security_rounded, color: colorScheme.secondary, size: 20),
                    title: 'Data Permissions',
                    subtitle: kIsWeb
                        ? 'Manage your data and exports'
                        : (Platform.isAndroid
                            ? 'Health Connect & App Usage access'
                            : 'HealthKit access'),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PermissionShieldScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.apps_rounded, color: colorScheme.secondary, size: 20),
                    title: 'App Categories',
                    subtitle: 'Social Media & Entertainment apps',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppCategoryManagerScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- Cloud Backup & Sync ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'Cloud Backup & Sync'),
            ),
            SliverToBoxAdapter(
              child: _SettingsCardGroup(
                children: [
                  Consumer<SyncService>(
                    builder: (context, syncService, child) {
                      final hasErrorMessage = syncService.syncErrorMessage != null;
                      final lastSyncStr = syncService.lastSyncTime != null
                          ? 'Last sync: ${syncService.lastSyncTime!.toLocal().toString().split('.').first}'
                          : 'Never synced';
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _SettingsSwitchTile(
                            leading: Icon(
                              Icons.cloud_upload_rounded,
                              color: colorScheme.primary,
                              size: 20,
                            ),
                            title: 'Enable Cloud Backup',
                            subtitle: syncService.isSyncing
                                ? 'Syncing to cloud...'
                                : hasErrorMessage
                                    ? 'Error: ${syncService.syncErrorMessage}'
                                    : lastSyncStr,
                            value: syncService.syncEnabled,
                            onChanged: (bool value) async {
                              await syncService.setSyncEnabled(value);
                              if (context.mounted && value && syncService.syncErrorMessage != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Sync error: ${syncService.syncErrorMessage}'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          if (syncService.syncEnabled) ...[
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 20),
                              height: 1,
                              color: colorScheme.outlineVariant.withAlpha(80),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withAlpha(20),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: colorScheme.primary.withAlpha(40),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: colorScheme.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Note: Cloud backup is enabled. Your events are securely synchronized to Supabase, which means your data is no longer local-only.',
                                        style: textTheme.bodySmall?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: colorScheme.surfaceContainerHighest.withAlpha(100),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: colorScheme.outlineVariant.withAlpha(80),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'RESEARCH ID (UUID)',
                                                style: textTheme.labelSmall?.copyWith(
                                                  color: colorScheme.primary,
                                                  fontWeight: FontWeight.bold,
                                                  letterSpacing: 1.0,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              SelectableText(
                                                profileService.uuid,
                                                style: textTheme.bodyMedium?.copyWith(
                                                  fontFamily: 'monospace',
                                                  fontWeight: FontWeight.w500,
                                                  color: colorScheme.onSurface,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            borderRadius: BorderRadius.circular(12),
                                            onTap: () {
                                              Clipboard.setData(
                                                ClipboardData(text: profileService.uuid),
                                              );
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                const SnackBar(
                                                  content: Text('Research ID copied to clipboard.'),
                                                  behavior: SnackBarBehavior.floating,
                                                  duration: Duration(seconds: 2),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: colorScheme.primary.withAlpha(20),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: Icon(
                                                Icons.copy_rounded,
                                                color: colorScheme.primary,
                                                size: 20,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _ManualBackupButton(syncService: syncService),
                                ],
                              ),
                            ),
                          ],
                          Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            height: 1,
                            color: colorScheme.outlineVariant.withAlpha(80),
                          ),
                          _SettingsTile(
                            leading: Icon(Icons.cloud_download_rounded, color: colorScheme.primary, size: 20),
                            title: 'Restore from Cloud Backup',
                            subtitle: 'Download and merge a research profile',
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  icon: Icon(
                                    Icons.warning_amber_rounded,
                                    color: colorScheme.error,
                                    size: 32,
                                  ),
                                  title: const Text('Restore Cloud Backup?'),
                                  content: const Text(
                                    'This will switch your app to the restored Research ID and merge the remote backup data into your local database. Your current local data will be kept and merged.',
                                    textAlign: TextAlign.center,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    FilledButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                      ),
                                      child: const Text('Restore'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                if (!context.mounted) return;
                                final summary = await showDialog<SyncSummary?>(
                                  context: context,
                                  builder: (context) => const _SettingsRestoreDialog(),
                                );
                                if (context.mounted && summary != null) {
                                  await showDialog(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (context) => SyncSummaryDialog(summary: summary),
                                  );
                                }
                              }
                            },
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),

            // --- Local Data & Files ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'Local Data & Files'),
            ),
            SliverToBoxAdapter(
              child: _SettingsCardGroup(
                children: [
                  _SettingsTile(
                    leading: Icon(Icons.list_alt_rounded, color: colorScheme.primary, size: 20),
                    title: 'Detailed Records',
                    subtitle: 'View and delete individual database logs',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RawDataScreen(),
                        ),
                      );
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.share_rounded, color: colorScheme.primary, size: 20),
                    title: 'Export & Sharing',
                    subtitle: 'Submit to researcher or download backups',
                    onTap: () => _showExportOptionsBottomSheet(context),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.upload_rounded, color: colorScheme.secondary, size: 20),
                    title: 'Import Data (JSON)',
                    subtitle: 'Merge external Covary records',
                    onTap: () async {
                      final importService = context.read<ImportService>();
                      final navigator = Navigator.of(context, rootNavigator: true);
                      bool dialogShown = false;
                      final result = await importService.importData(
                        onImportStart: () {
                          dialogShown = true;
                          showDialog(
                            context: context,
                            barrierDismissible: false,
                            useRootNavigator: true,
                            builder: (ctx) => const _ImportLoadingDialog(),
                          );
                        },
                      );
                      if (dialogShown) {
                        navigator.pop();
                      }
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(result),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    },
                  ),
                ],
              ),
            ),

            // --- System & Info ---
            const SliverToBoxAdapter(
              child: _SettingsSectionHeader(title: 'System & Info'),
            ),
            SliverToBoxAdapter(
              child: _SettingsCardGroup(
                children: [
                  _SettingsTile(
                    leading: Icon(Icons.help_outline_rounded, color: colorScheme.secondary, size: 20),
                    title: 'Show Tutorial Again',
                    subtitle: 'Review the research mission and setup tour',
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Show Tutorial?'),
                          content: const Text('This will take you back to the onboarding slides. Your current settings and data will not be deleted.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Show')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await profileService.resetOnboarding();
                        if (context.mounted) {
                          Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                            MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                            (route) => false,
                          );
                        }
                      }
                    },
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    height: 1,
                    color: colorScheme.outlineVariant.withAlpha(80),
                  ),
                  _SettingsTile(
                    leading: Icon(Icons.info_outline_rounded, color: colorScheme.secondary, size: 20),
                    title: 'Check for Updates',
                    subtitleWidget: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text(
                            'Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}',
                            style: textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          );
                        }
                        return Text(
                          'Checking version...',
                          style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        );
                      },
                    ),
                    trailing: Icon(Icons.refresh_rounded, color: colorScheme.primary, size: 20),
                    onTap: () {
                      UpdateService.checkAndPrompt(context, silent: false);
                      setState(() {
                        if (!profileService.isDeveloperMode) {
                          _devTapCount++;
                          if (_devTapCount >= 7) {
                            profileService.setDeveloperMode(true);
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Developer mode enabled!')),
                            );
                          } else if (_devTapCount >= 3) {
                            final remaining = 7 - _devTapCount;
                            ScaffoldMessenger.of(context).clearSnackBars();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('You are $remaining steps away from being a developer.'),
                                duration: const Duration(milliseconds: 1500),
                              ),
                            );
                          }
                        }
                      });
                    },
                  ),
                  if (profileService.isDeveloperMode) ...[
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      height: 1,
                      color: colorScheme.outlineVariant.withAlpha(80),
                    ),
                    _SettingsTile(
                      leading: Icon(Icons.bug_report_rounded, color: colorScheme.primary, size: 20),
                      title: 'Debug Tools',
                      subtitle: 'Internal diagnostics and logs',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DebugScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  void _showExportOptionsBottomSheet(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(ctx).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Export & Sharing',
                style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Share your data with researchers or download local config backups.',
                style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 24),
            
            // Submit to Researcher
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.send_rounded, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              title: const Text('Submit to Researcher'),
              subtitle: const Text('Email selected metrics export to Felix Z.'),
              onTap: () async {
                Navigator.pop(ctx);
                final selectedLabels = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _ExportMetricSelectorSheet(isSubmission: true),
                );
                if (selectedLabels != null && context.mounted) {
                  _submitDataToResearcher(context, selectedLabels);
                }
              },
            ),
            const Divider(height: 16, indent: 56),

            // Export Data (JSON)
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.download_rounded, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              title: const Text('Export Data (JSON)'),
              subtitle: const Text('Download selected local logs and events'),
              onTap: () async {
                Navigator.pop(ctx);
                final selectedLabels = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const _ExportMetricSelectorSheet(isSubmission: false),
                );
                if (selectedLabels != null && context.mounted) {
                  final exportService = context.read<ExportService>();
                  final success = await exportService.exportData(filteredMetricLabels: selectedLabels);
                  if (context.mounted && success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Export successful! Share intent triggered.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
            ),
            const Divider(height: 16, indent: 56),

            // Export Windows
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.schedule_rounded, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              title: const Text('Export Tracking Windows'),
              subtitle: const Text('Export time windows setup'),
              onTap: () async {
                Navigator.pop(ctx);
                final exportService = context.read<ExportService>();
                final success = await exportService.exportWindows();
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export successful! Share intent triggered.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const Divider(height: 16, indent: 56),

            // Export Metrics
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.tune_rounded, color: colorScheme.onPrimaryContainer, size: 20),
              ),
              title: const Text('Export Tracked Metrics'),
              subtitle: const Text('Export custom metrics definitions'),
              onTap: () async {
                Navigator.pop(ctx);
                final exportService = context.read<ExportService>();
                final success = await exportService.exportMetrics();
                if (context.mounted && success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Export successful! Share intent triggered.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _submitDataToResearcher(BuildContext context, [List<String>? selectedLabels]) async {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.mark_as_unread_rounded, color: colorScheme.primary, size: 32),
        title: const Text('Ready to Submit?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'In the next step, please select your Email app (e.g., Gmail, Outlook).',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'The researcher\'s email address will be included in the message text — just copy and paste it into the "To" field.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer.withAlpha(80),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.primary.withAlpha(100)),
              ),
              child: Column(
                children: [
                  Text(
                    'Researcher Email:',
                    style: textTheme.labelSmall?.copyWith(color: colorScheme.primary),
                  ),
                  const SizedBox(height: 4),
                  const SelectableText(
                    'felix.zoeggeler@edu.fh-joanneum.at',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'The data export is automatically attached as a JSON file.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continue to Email'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!context.mounted) return;
      final exportService = context.read<ExportService>();
      final success = await exportService.submitToResearcher(filteredMetricLabels: selectedLabels);
      if (context.mounted && success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Opening share sheet... Please pick your Email app.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// =============================================================================
// Theme Settings Section
// =============================================================================

class _ThemeSettingsSection extends StatelessWidget {
  const _ThemeSettingsSection();

  Widget _buildColorCircle({
    required BuildContext context,
    required ThemeService themeService,
    required ColorScheme colorScheme,
    required AppAccentColor colorEnum,
  }) {
    final isSelected = themeService.accentColor == colorEnum;
    Color displayColor;
    String colorName;
    switch (colorEnum) {
      case AppAccentColor.white:
        displayColor = Colors.white;
        colorName = 'White';
        break;
      case AppAccentColor.aquamarine:
        displayColor = const Color(0xFF38debb);
        colorName = 'Aquamarine';
        break;
      case AppAccentColor.mint:
        displayColor = const Color(0xFF4ADE80);
        colorName = 'Mint';
        break;
      case AppAccentColor.emerald:
        displayColor = const Color(0xFF34d399);
        colorName = 'Emerald';
        break;
      case AppAccentColor.azure:
        displayColor = const Color(0xFF60a5fa);
        colorName = 'Azure';
        break;
      case AppAccentColor.indigo:
        displayColor = const Color(0xFF6366F1);
        colorName = 'Indigo';
        break;
      case AppAccentColor.deepViolet:
        displayColor = const Color(0xFF5203d5);
        colorName = 'Deep Violet';
        break;
      case AppAccentColor.orchid:
        displayColor = const Color(0xFFF472B6);
        colorName = 'Orchid';
        break;
      case AppAccentColor.ruby:
        displayColor = const Color(0xFFfb7185);
        colorName = 'Ruby';
        break;
      case AppAccentColor.crimson:
        displayColor = const Color(0xFFE11D48);
        colorName = 'Crimson';
        break;
      case AppAccentColor.coral:
        displayColor = const Color(0xFFfb923c);
        colorName = 'Coral';
        break;
      case AppAccentColor.gold:
        displayColor = const Color(0xFFdec65a);
        colorName = 'Gold';
        break;
    }

    return Tooltip(
      message: colorName,
      child: GestureDetector(
        onTap: () => themeService.setAccentColor(colorEnum),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutBack,
          width: isSelected ? 40 : 32,
          height: isSelected ? 40 : 32,
          decoration: BoxDecoration(
            color: displayColor,
            shape: BoxShape.circle,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: displayColor.withAlpha(120),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withAlpha(20),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
            border: Border.all(
              color: isSelected ? Colors.white : colorScheme.surfaceContainerHighest,
              width: isSelected ? 2.5 : 1.5,
            ),
          ),
          child: isSelected
              ? Icon(
                  Icons.check_rounded,
                  color: displayColor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  size: 16,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.surfaceContainerHighest.withAlpha(70),
            colorScheme.surfaceContainer.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.outlineVariant.withAlpha(80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(20),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Theme Mode',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          _ThemeSegmentPicker(
            currentMode: themeService.themeMode,
            onChanged: (mode) => themeService.setThemeMode(mode),
          ),
          const SizedBox(height: 24),
          Text(
            'Accent Color',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: AppAccentColor.values.take(6).map((colorEnum) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: _buildColorCircle(
                        context: context,
                        themeService: themeService,
                        colorScheme: colorScheme,
                        colorEnum: colorEnum,
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: AppAccentColor.values.skip(6).take(6).map((colorEnum) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6.0),
                      child: _buildColorCircle(
                        context: context,
                        themeService: themeService,
                        colorScheme: colorScheme,
                        colorEnum: colorEnum,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Dark Background Style',
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: AppBackgroundStyle.values.map((bgStyle) {
                final isSelected = themeService.backgroundStyle == bgStyle;
                final primary = themeService.primaryColor;
                
                String label;
                Color previewColor;
                Gradient? previewGradient;
                
                switch (bgStyle) {
                  case AppBackgroundStyle.midnightNavy:
                    label = 'Midnight';
                    previewColor = const Color(0xFF0B121F);
                    break;
                  case AppBackgroundStyle.pureBlack:
                    label = 'Pure Black';
                    previewColor = Colors.black;
                    break;
                  case AppBackgroundStyle.deepCharcoal:
                    label = 'Charcoal';
                    previewColor = const Color(0xFF16161A);
                    break;
                  case AppBackgroundStyle.auroraGradient:
                    label = 'Aurora';
                    previewColor = Colors.transparent;
                    previewGradient = LinearGradient(
                      colors: [
                        const Color(0xFF0B121F),
                        Color.lerp(const Color(0xFF0B121F), primary, 0.2)!,
                        Color.lerp(const Color(0xFF070B14), primary, 0.4)!,
                      ],
                    );
                    break;
                }
                
                return FilterChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) => themeService.setBackgroundStyle(bgStyle),
                  backgroundColor: colorScheme.surfaceContainerHighest.withAlpha(80),
                  selectedColor: primary.withAlpha(40),
                  labelStyle: textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? primary : colorScheme.onSurface,
                  ),
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(
                      color: isSelected ? primary : colorScheme.outlineVariant.withAlpha(100),
                      width: 1.5,
                    ),
                  ),
                  avatar: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: previewColor,
                      gradient: previewGradient,
                      border: Border.all(
                        color: Colors.white.withAlpha(80),
                        width: 1,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Notification Settings Section
// =============================================================================

class _NotificationSettingsSection extends StatefulWidget {
  const _NotificationSettingsSection();

  @override
  State<_NotificationSettingsSection> createState() =>
      _NotificationSettingsSectionState();
}

class _NotificationSettingsSectionState
    extends State<_NotificationSettingsSection> {
  List<int> _durations = [];

  @override
  void initState() {
    super.initState();
    _loadDurations();
  }

  Future<void> _loadDurations() async {
    final d = await NotificationService.getSnoozeDurations();
    if (mounted) setState(() => _durations = d);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    if (_durations.isEmpty) {
      return const SizedBox(height: 100, child: Center(child: CircularProgressIndicator()));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            children: [
              Icon(Icons.notifications_active_rounded, size: 20, color: colorScheme.primary),
              const SizedBox(width: 12),
              Text(
                'Quick Snooze Slots',
                style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Text(
            'Customize the quick snooze duration buttons that appear on check-in notifications (alongside "At time...").',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(_durations.length, (index) {
              final mins = _durations[index];
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: InkWell(
                    onTap: () => _editSnoozeSlot(index),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest.withAlpha(120),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colorScheme.outlineVariant.withAlpha(120),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(10),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Text(
                            'SLOT ${index + 1}',
                            style: textTheme.labelSmall?.copyWith(
                              color: colorScheme.onSurfaceVariant.withAlpha(180),
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDuration(mins),
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  String _formatDuration(int minutes) {
    if (minutes >= 60) {
      final h = minutes ~/ 60;
      final m = minutes % 60;
      if (m == 0) return '${h}h';
      return '${h}h ${m}m';
    }
    return '${minutes}m';
  }

  Future<void> _editSnoozeSlot(int index) async {
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => _SnoozeDurationDialog(initialValue: _durations[index]),
    );

    if (result != null && result > 0) {
      final newList = List<int>.from(_durations);
      newList[index] = result;
      // Sort them for cleaner UI? Or let user pick order?
      // User might want specific order. Let's keep their order.
      await NotificationService.setSnoozeDurations(newList);
      setState(() => _durations = newList);
    }
  }
}

class _SnoozeDurationDialog extends StatefulWidget {
  final int initialValue;
  const _SnoozeDurationDialog({required this.initialValue});

  @override
  State<_SnoozeDurationDialog> createState() => _SnoozeDurationDialogState();
}

class _SnoozeDurationDialogState extends State<_SnoozeDurationDialog> {
  late int _minutes;

  @override
  void initState() {
    super.initState();
    _minutes = widget.initialValue;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit Snooze Duration'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'How many minutes should this slot snooze for?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              _durationOption(10),
              _durationOption(30),
              _durationOption(60),
              _durationOption(120),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Custom Minutes',
              suffixText: 'min',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) {
              final parsed = int.tryParse(val);
              if (parsed != null && parsed > 0) {
                setState(() => _minutes = parsed);
              }
            },
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _minutes), child: const Text('Save')),
      ],
    );
  }

  Widget _durationOption(int value) {
    final isSelected = _minutes == value;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text('${value}m'),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _minutes = value);
        },
      ),
    );
  }
}

class _ManualBackupButton extends StatefulWidget {
  final SyncService syncService;

  const _ManualBackupButton({required this.syncService});

  @override
  State<_ManualBackupButton> createState() => _ManualBackupButtonState();
}

class _ManualBackupButtonState extends State<_ManualBackupButton> {
  bool _isBackingUp = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return OutlinedButton.icon(
      onPressed: _isBackingUp || widget.syncService.isSyncing
          ? null
          : () async {
              setState(() => _isBackingUp = true);
              try {
                await widget.syncService.uploadBackup();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Backup completed successfully!'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Backup failed: $e'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: colorScheme.error,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isBackingUp = false);
                }
              }
            },
      icon: _isBackingUp
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
              ),
            )
          : const Icon(Icons.cloud_upload_outlined, size: 18),
      label: Text(_isBackingUp ? 'Backing up...' : 'Back Up Now'),
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

class _SettingsRestoreDialog extends StatefulWidget {
  const _SettingsRestoreDialog();

  @override
  State<_SettingsRestoreDialog> createState() => _SettingsRestoreDialogState();
}

class _SettingsRestoreDialogState extends State<_SettingsRestoreDialog> {
  final TextEditingController _uuidController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _uuidController.dispose();
    super.dispose();
  }

  Future<void> _handleRestore() async {
    final uuid = _uuidController.text.trim();
    if (uuid.isEmpty) {
      setState(() => _error = 'Please enter a valid ID');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final syncService = context.read<SyncService>();
      final summary = await syncService.restoreWithUuid(uuid);
      
      if (!mounted) return;

      if (summary != null) {
        Navigator.of(context).pop(summary);
      } else {
        setState(() {
          _error = 'No backup found. Double check your ID.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error: ${e.toString()}';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(Icons.cloud_download_rounded, color: colorScheme.primary),
          const SizedBox(width: 12),
          const Text('Enter Research ID'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enter the 36-character Research ID to restore.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _uuidController,
              enabled: !_isLoading,
              style: const TextStyle(fontFamily: 'monospace'),
              decoration: InputDecoration(
                hintText: 'e.g. 17b6c8aa-b586-...',
                errorText: _error,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _handleRestore,
          style: FilledButton.styleFrom(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Restore'),
        ),
      ],
    );
  }
}

class _ExportMetricSelectorSheet extends StatefulWidget {
  final bool isSubmission;

  const _ExportMetricSelectorSheet({required this.isSubmission});

  @override
  State<_ExportMetricSelectorSheet> createState() => _ExportMetricSelectorSheetState();
}

class _ExportMetricSelectorSheetState extends State<_ExportMetricSelectorSheet> {
  final Set<String> _selectedLabels = {};
  List<MetricDefinition> _metrics = [];
  bool _initialized = false;
  String _searchQuery = "";

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final metricService = Provider.of<MetricService>(context, listen: false);
      _metrics = metricService.allMetrics;
      // Pre-select only currently enabled metrics
      for (final m in _metrics) {
        if (m.isEnabled) {
          _selectedLabels.add(m.label);
        }
      }
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final filteredMetrics = _metrics.where((m) {
      if (_searchQuery.isEmpty) return true;
      return m.label.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          m.category.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // Group by category
    final Map<EventCategory, List<MetricDefinition>> grouped = {};
    for (final m in filteredMetrics) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    final categoriesInOrder = EventCategory.values.where((c) => grouped.containsKey(c)).toList();

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              widget.isSubmission ? 'Submit to Researcher' : 'Export Data (JSON)',
              style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select the metrics you want to include in this export. Unselected metrics will be filtered out for your privacy.',
              style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search metrics...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded),
                        onPressed: () => setState(() => _searchQuery = ""),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.outlineVariant.withAlpha(120)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: colorScheme.primary, width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Action Buttons: Select All / Clear Selection
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedLabels.addAll(filteredMetrics.map((m) => m.label));
                    });
                  },
                  icon: const Icon(Icons.select_all_rounded, size: 16),
                  label: const Text('Select All', style: TextStyle(fontSize: 12)),
                ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedLabels.removeAll(filteredMetrics.map((m) => m.label));
                    });
                  },
                  icon: const Icon(Icons.deselect_rounded, size: 16),
                  label: const Text('Clear', style: TextStyle(fontSize: 12)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_selectedLabels.length} of ${_metrics.length} selected',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Scrollable Metrics List
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.45,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                itemCount: categoriesInOrder.length,
                itemBuilder: (context, catIndex) {
                  final cat = categoriesInOrder[catIndex];
                  final catMetrics = grouped[cat] ?? [];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildCategoryHeader(cat, colorScheme, textTheme),
                      ...catMetrics.map((metric) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: _buildMetricTile(metric, colorScheme, textTheme),
                        );
                      }),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Action Buttons (Confirm & Cancel)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton(
                    onPressed: _selectedLabels.isEmpty
                        ? null
                        : () {
                            Navigator.pop(context, _selectedLabels.toList());
                          },
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Text('Confirm'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildCategoryHeader(EventCategory category, ColorScheme colorScheme, TextTheme textTheme) {
    String name = category.name.toUpperCase();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Text(
            name,
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Divider(
              color: colorScheme.primary.withAlpha(40),
              thickness: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(MetricDefinition metric, ColorScheme colorScheme, TextTheme textTheme) {
    final isSelected = _selectedLabels.contains(metric.label);
    
    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedLabels.remove(metric.label);
          } else {
            _selectedLabels.add(metric.label);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? colorScheme.primaryContainer.withAlpha(25) 
              : colorScheme.surfaceContainerHighest.withAlpha(80),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected 
                ? colorScheme.primary.withAlpha(120) 
                : colorScheme.outlineVariant.withAlpha(80),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isSelected 
                    ? colorScheme.primary.withAlpha(40) 
                    : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
              ),
              child: MetricIcon(
                iconName: metric.emoji,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            // Label
            Expanded(
              child: Text(
                metric.label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? colorScheme.onSurface : colorScheme.onSurface.withAlpha(200),
                ),
              ),
            ),
            // Animated Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? colorScheme.primary : colorScheme.outline,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      size: 16,
                      color: colorScheme.onPrimary,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Premium UI Helper Widgets
// =============================================================================

class _GlowingAppIcon extends StatefulWidget {
  final ColorScheme colorScheme;
  const _GlowingAppIcon({required this.colorScheme});

  @override
  State<_GlowingAppIcon> createState() => _GlowingAppIconState();
}

class _GlowingAppIconState extends State<_GlowingAppIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: Container(
        width: 96,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: widget.colorScheme.primary.withAlpha(60),
              blurRadius: 24,
              spreadRadius: 2,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Image.asset(
            'assets/icon/app_icon.png',
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}

class _SettingsSectionHeader extends StatelessWidget {
  final String title;

  const _SettingsSectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: colorScheme.primary,
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withAlpha(150),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title.toUpperCase(),
            style: textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withAlpha(80),
                    colorScheme.primary.withAlpha(0),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCardGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCardGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: [
              colorScheme.surfaceContainerHighest.withAlpha(70),
              colorScheme.surfaceContainer.withAlpha(40),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: colorScheme.outlineVariant.withAlpha(80),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: children,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.leading,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest.withAlpha(150),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
              child: leading,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  if (subtitleWidget != null) ...[
                    const SizedBox(height: 4),
                    subtitleWidget!,
                  ] else if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing ??
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withAlpha(150),
                ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSwitchTile extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsSwitchTile({
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withAlpha(150),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: colorScheme.outlineVariant.withAlpha(50),
              ),
            ),
            child: leading,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: colorScheme.primary,
            activeTrackColor: colorScheme.primary.withAlpha(80),
          ),
        ],
      ),
    );
  }
}

class _ThemeSegmentPicker extends StatelessWidget {
  final ThemeMode currentMode;
  final ValueChanged<ThemeMode> onChanged;

  const _ThemeSegmentPicker({
    required this.currentMode,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer.withAlpha(150),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(80)),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _buildSegment(context, ThemeMode.system, Icons.brightness_auto, 'System'),
          _buildSegment(context, ThemeMode.light, Icons.light_mode, 'Light'),
          _buildSegment(context, ThemeMode.dark, Icons.dark_mode, 'Dark'),
        ],
      ),
    );
  }

  Widget _buildSegment(BuildContext context, ThemeMode mode, IconData icon, String label) {
    final isSelected = currentMode == mode;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isSelected
                ? LinearGradient(
                    colors: [
                      colorScheme.primary,
                      colorScheme.primary.withAlpha(200),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(40),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImportLoadingDialog extends StatelessWidget {
  const _ImportLoadingDialog();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 72,
                height: 72,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                ),
              ),
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.upload_rounded,
                  color: colorScheme.onPrimaryContainer,
                  size: 26,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Importing Data',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Please do not close the app. We are merging and restoring your database records...',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}


