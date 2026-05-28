import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../services/profile_service.dart';
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

import 'metrics_screen.dart';
import 'tracking_windows_screen.dart';
import 'onboarding_screen.dart';
import 'meal_reminders_screen.dart';

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
        child: CustomScrollView(
          slivers: [
            // --- Logo & Branding ---
            SliverToBoxAdapter(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 48, bottom: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: colorScheme.primary.withAlpha(40),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/icon/app_icon.png'),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'COVARY',
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                          color: colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Header ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text(
                  'Settings',
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
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
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(
                        Icons.person_rounded,
                        color: colorScheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      profileService.nickname.isNotEmpty
                          ? profileService.nickname
                          : 'Set Nickname',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      profileService.uuid.substring(0, 8).toUpperCase(),
                      style: textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ProfileSetupScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // --- Appearance Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Appearance',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _ThemeSettingsSection(),
              ),
            ),

            // --- Research Setup Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Research Setup',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: Icon(Icons.tune_rounded, color: colorScheme.primary),
                        title: const Text('Tracked Metrics'),
                        subtitle: const Text('Manage habits and measurement scales'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MetricsScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1, indent: 56),
                      ListTile(
                        leading: Icon(Icons.schedule_rounded, color: colorScheme.primary),
                        title: const Text('Tracking Windows'),
                        subtitle: const Text('Define custom time slots for metrics'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const TrackingWindowsScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- Notification Preferences ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Notification Preferences',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: _NotificationSettingsSection(),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.restaurant_rounded, color: colorScheme.primary),
                    title: const Text('Meal Reminders'),
                    subtitle: const Text('Schedule alerts with quick Snack/Meal/Feast buttons'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MealRemindersScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),


            // --- Passive Sensing Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Passive Sensing',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.security_rounded, color: colorScheme.secondary),
                    title: const Text('Data Permissions'),
                    subtitle: Text(Platform.isAndroid
                        ? 'Health Connect & App Usage access'
                        : 'HealthKit access'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PermissionShieldScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // --- App Categories ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.apps_rounded, color: colorScheme.secondary),
                    title: const Text('App Categories'),
                    subtitle: const Text('Social Media & Entertainment apps'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppCategoryManagerScreen(),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),

            // --- Data Management Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Data Management',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Consumer<SyncService>(
                    builder: (context, syncService, child) {
                      final hasErrorMessage = syncService.syncErrorMessage != null;
                      final lastSyncStr = syncService.lastSyncTime != null
                          ? 'Last sync: ${syncService.lastSyncTime!.toLocal().toString().split('.').first}'
                          : 'Never synced';
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SwitchListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 8,
                            ),
                            secondary: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.cloud_upload_rounded,
                                color: colorScheme.onPrimaryContainer,
                                size: 20,
                              ),
                            ),
                            title: const Text('Enable Cloud Backup'),
                            subtitle: Text(
                              syncService.isSyncing
                                  ? 'Syncing to cloud...'
                                  : hasErrorMessage
                                      ? 'Error: ${syncService.syncErrorMessage}'
                                      : lastSyncStr,
                              style: TextStyle(
                                color: hasErrorMessage ? colorScheme.error : null,
                              ),
                            ),
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
                            const Divider(height: 1, indent: 20, endIndent: 20),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'Research ID (UUID)',
                                              style: textTheme.labelSmall?.copyWith(
                                                color: colorScheme.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            SelectableText(
                                              profileService.uuid,
                                              style: textTheme.bodyMedium?.copyWith(
                                                fontFamily: 'monospace',
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(
                                          Icons.copy_rounded,
                                          color: colorScheme.primary,
                                          size: 20,
                                        ),
                                        onPressed: () {
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
                                        tooltip: 'Copy ID',
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  _ManualBackupButton(syncService: syncService),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.cloud_download_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Restore from Cloud Backup'),
                    subtitle: const Text('Download and merge a research profile'),
                    trailing: Icon(
                      Icons.chevron_right_rounded,
                      color: colorScheme.onSurfaceVariant,
                    ),
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
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.send_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Submit to Researcher'),
                    subtitle: const Text('Email full export to Felix Z.'),
                    trailing: FilledButton(
                      onPressed: () async {
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
                          final success = await exportService.submitToResearcher();
                          if (context.mounted && success) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Opening share sheet... Please pick your Email app.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      child: const Text('Submit'),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.download_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Export Data (JSON)'),
                    subtitle: const Text('Download all local records'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final exportService = context.read<ExportService>();
                        final success = await exportService.exportData();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Export successful! Share intent triggered.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: const Text('Export'),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.schedule_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Export Windows'),
                    subtitle: const Text('Download tracking windows only'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final exportService = context.read<ExportService>();
                        final success = await exportService.exportWindows();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Export successful! Share intent triggered.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: const Text('Export'),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.tune_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Export Metrics'),
                    subtitle: const Text('Download custom metrics only'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final exportService = context.read<ExportService>();
                        final success = await exportService.exportMetrics();
                        if (context.mounted && success) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Export successful! Share intent triggered.',
                              ),
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 4),
                            ),
                          );
                        }
                      },
                      child: const Text('Export'),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.upload_rounded,
                        color: colorScheme.onSecondaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Import Data (JSON)'),
                    subtitle: const Text('Merge external Covary records'),
                    trailing: FilledButton.tonal(
                      onPressed: () async {
                        final importService = context.read<ImportService>();
                        final result = await importService.importData();
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
                      child: const Text('Import'),
                    ),
                  ),
                ),
              ),
            ),

            // --- Help & Feedback Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'Help & Feedback',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.help_outline_rounded, color: colorScheme.secondary),
                    title: const Text('Show Tutorial Again'),
                    subtitle: const Text('Review the research mission and setup tour'),
                    trailing: const Icon(Icons.chevron_right_rounded),
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
                ),
              ),
            ),

            // --- Developer Section ---
            if (profileService.isDeveloperMode) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                  child: Text(
                    'Developer',
                    style: textTheme.titleSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Card(
                    elevation: 0,
                    color: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: Icon(Icons.bug_report_rounded, color: colorScheme.primary),
                      title: const Text('Debug Tools'),
                      subtitle: const Text('Internal diagnostics and logs'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const DebugScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            
            // --- About Section ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
                child: Text(
                  'About',
                  style: textTheme.titleSmall?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Card(
                  elevation: 0,
                  color: colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: colorScheme.secondary),
                    title: const Text('Check for Updates'),
                    subtitle: FutureBuilder<PackageInfo>(
                      future: PackageInfo.fromPlatform(),
                      builder: (context, snapshot) {
                        if (snapshot.hasData) {
                          return Text('Version ${snapshot.data!.version}+${snapshot.data!.buildNumber}');
                        }
                        return const Text('Checking version...');
                      },
                    ),
                    trailing: const Icon(Icons.refresh_rounded),
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
                ),
              ),
            ),

            // Bottom padding
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Theme Settings Section
// =============================================================================

class _ThemeSettingsSection extends StatelessWidget {
  const _ThemeSettingsSection();

  @override
  Widget build(BuildContext context) {
    final themeService = context.watch<ThemeService>();
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme Mode', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('System'),
                  selected: themeService.themeMode == ThemeMode.system,
                  onSelected: (_) => themeService.setThemeMode(ThemeMode.system),
                  avatar: const Icon(Icons.brightness_auto, size: 18),
                ),
                ChoiceChip(
                  label: const Text('Light'),
                  selected: themeService.themeMode == ThemeMode.light,
                  onSelected: (_) => themeService.setThemeMode(ThemeMode.light),
                  avatar: const Icon(Icons.light_mode, size: 18),
                ),
                ChoiceChip(
                  label: const Text('Dark'),
                  selected: themeService.themeMode == ThemeMode.dark,
                  onSelected: (_) => themeService.setThemeMode(ThemeMode.dark),
                  avatar: const Icon(Icons.dark_mode, size: 18),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Accent Color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              children: AppAccentColor.values.map((colorEnum) {
                final isSelected = themeService.accentColor == colorEnum;
                Color displayColor;
                switch (colorEnum) {
                  case AppAccentColor.aquamarine:
                    displayColor = const Color(0xFF38debb);
                    break;
                  case AppAccentColor.deepViolet:
                    displayColor = const Color(0xFF5203d5);
                    break;
                  case AppAccentColor.gold:
                    displayColor = const Color(0xFFdec65a);
                    break;
                  case AppAccentColor.azure:
                    displayColor = const Color(0xFF60a5fa);
                    break;
                  case AppAccentColor.emerald:
                    displayColor = const Color(0xFF34d399);
                    break;
                  case AppAccentColor.coral:
                    displayColor = const Color(0xFFfb923c);
                    break;
                  case AppAccentColor.ruby:
                    displayColor = const Color(0xFFfb7185);
                    break;
                }

                return GestureDetector(
                  onTap: () => themeService.setAccentColor(colorEnum),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: displayColor,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? colorScheme.onSurface : Colors.transparent,
                        width: 3,
                      ),
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: displayColor.computeLuminance() > 0.5 ? Colors.black : Colors.white)
                        : null,
                  ),
                );
              }).toList(),
            ),
          ],
        ),
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

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
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
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_durations.length, (index) {
                final mins = _durations[index];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => _editSnoozeSlot(index),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: colorScheme.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colorScheme.outlineVariant),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Slot ${index + 1}',
                              style: textTheme.labelSmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _formatDuration(mins),
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
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
      ),
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


