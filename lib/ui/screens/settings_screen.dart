import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/export_service.dart';
import '../../services/profile_service.dart';
import 'package:covary/services/theme_service.dart';
import 'profile_setup_screen.dart';
import 'permission_shield_screen.dart';
import 'app_category_screen.dart';
import 'debug_screen.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../services/update_service.dart';
import '../../services/import_service.dart';
import '../../services/notification_service.dart';

import 'metrics_screen.dart';
import 'tracking_windows_screen.dart';

/// Settings screen for managing profile, notifications, and data.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final profileService = context.watch<ProfileService>();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // --- Header ---
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
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
                          builder: (_) => const AppCategoryScreen(),
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
                        Icons.download_rounded,
                        color: colorScheme.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                    title: const Text('Export Data (JSON)'),
                    subtitle: const Text('Download all local records'),
                    trailing: FilledButton(
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
                      }
                    },
                  ),
                ),
              ),
            ),

            // --- Developer Section ---
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

