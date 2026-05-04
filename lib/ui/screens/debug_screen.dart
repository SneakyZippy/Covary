import 'dart:math';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:package_info_plus/package_info_plus.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../services/export_service.dart';
import '../../services/metric_service.dart';
import '../../services/notification_service.dart';
import '../../services/passive_sensing_service.dart';
import '../../services/update_service.dart';
import '../widgets/dialog_utils.dart';

class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  int _eventCount = 0;

  @override
  void initState() {
    super.initState();
    _refreshEventCount();
  }

  Future<void> _refreshEventCount() async {
    final db = context.read<AppDatabase>();
    final events = await db.select(db.events).get();
    setState(() {
      _eventCount = events.length;
    });
  }

  Future<void> _testFatigueDialog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dismiss_count', 3);
    await prefs.setBool('show_fatigue_dialog', true);
    
    if (mounted) {
      await context.read<NotificationService>().checkPendingFatigueDialog();
      _showSnackbar('Fatigue Dialog triggered');
    }
  }

  Future<void> _testMissedCheckin() async {
    final metricService = context.read<MetricService>();
    final now = DateTime.now();
    final start = now.subtract(const Duration(hours: 1));
    final end = now.subtract(const Duration(minutes: 5));

    await metricService.addTrackingWindow(
      label: 'Debug Missed Window',
      startHour: start.hour,
      startMinute: start.minute,
      endHour: end.hour,
      endMinute: end.minute,
    );

    _showSnackbar('Created a missed window. Check the Home Screen!');
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _clearDatabase() async {
    final confirmed = await showTextConfirmationDialog(
      context: context,
      title: 'Clear Database?',
      content: 'This will permanently delete ALL research events. This cannot be undone.',
      confirmationWord: 'DELETE',
      confirmLabel: 'Clear All',
    );

    if (confirmed == true && mounted) {
      final db = context.read<AppDatabase>();
      await db.delete(db.events).go();
      await _refreshEventCount();
      _showSnackbar('Database cleared.');
    }
  }

  Future<void> _resetMetrics() async {
    final confirmed = await showTextConfirmationDialog(
      context: context,
      title: 'Reset Metrics?',
      content: 'This will delete all custom metrics, tracking windows, and sort orders, then re-seed the default ones. Recorded events will NOT be deleted.',
      confirmationWord: 'RESET',
      confirmLabel: 'Reset Defaults',
    );

    if (confirmed == true && mounted) {
      try {
        await context.read<MetricService>().debugResetMetrics();
        _showSnackbar('Metrics reset to defaults.');
      } catch (e) {
        _showSnackbar('Error resetting metrics: $e');
      }
    }
  }

  Future<void> _seedDummyData() async {
    final db = context.read<AppDatabase>();
    final random = Random();
    final now = DateTime.now();

    for (int i = 0; i < 20; i++) {
      final daysAgo = random.nextInt(7);
      final hour = random.nextInt(24);
      final minute = random.nextInt(60);
      final time = now.subtract(Duration(days: daysAgo)).copyWith(
            hour: hour,
            minute: minute,
          );

      await db.insertEvent(EventsCompanion(
        category: drift.Value(EventCategory.values[random.nextInt(EventCategory.values.length)]),
        label: drift.Value('Dummy Event $i'),
        value: drift.Value(random.nextInt(10).toString()),
        triggerSource: drift.Value(TriggerSource.values[random.nextInt(TriggerSource.values.length)]),
        interactionType: drift.Value(InteractionType.values[random.nextInt(InteractionType.values.length)]),
        timestamp: drift.Value(time),
      ));
    }

    await _refreshEventCount();
    if (mounted) _showSnackbar('Seeded 20 dummy events.');
  }

  Future<void> _copyUuid() async {
    final prefs = await SharedPreferences.getInstance();
    final uuid = prefs.getString('user_uuid') ?? 'Not generated yet';
    await Clipboard.setData(ClipboardData(text: uuid));
    if (mounted) _showSnackbar('UUID copied to clipboard: $uuid');
  }

  Future<void> _cancelAllNotifications() async {
    await AwesomeNotifications().cancelAll();
    if (mounted) _showSnackbar('All notifications cancelled.');
  }

  Future<void> _showUpdateDebugInfo() async {
    _showSnackbar('Fetching update info...');
    Map<String, dynamic>? updateInfo;
    String? errorMessage;
    
    try {
      updateInfo = await UpdateService.fetchUpdateInfo();
    } catch (e) {
      errorMessage = e.toString();
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Update Debug Info'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Local Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text('Version: ${packageInfo.version}'),
                Text('Build: ${packageInfo.buildNumber}'),
                const SizedBox(height: 16),
                const Text('Server Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                if (updateInfo != null) ...[
                  Text('Latest Version: ${updateInfo['latest_version']}'),
                  Text('Latest Build: ${updateInfo['build_number']}'),
                  Text('Timestamp: ${updateInfo['build_timestamp'] ?? 'N/A'}'),
                  const SizedBox(height: 8),
                  const Text('Raw JSON:', style: TextStyle(fontWeight: FontWeight.bold)),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(updateInfo.toString()),
                  ),
                ] else
                  Text(
                    errorMessage != null 
                        ? 'Error:\n$errorMessage' 
                        : 'Failed to fetch from server or returned null.',
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showSnackbar('Error: $e');
    }
  }

  Future<void> _viewScheduledNotifications() async {
    _showSnackbar('Fetching scheduled notifications...');
    try {
      final scheduled = await AwesomeNotifications().listScheduledNotifications();
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Scheduled Notifications'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: scheduled.isEmpty
                  ? [const Text('No notifications scheduled.')]
                  : scheduled.map((n) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ID: ${n.content?.id}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text('Title: ${n.content?.title}'),
                            Text('Channel: ${n.content?.channelKey}'),
                            Text('Schedule: ${n.schedule?.toMap()}'),
                          ],
                        ),
                      );
                    }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showSnackbar('Error: $e');
    }
  }

  Future<void> _viewSharedPreferences() async {
    _showSnackbar('Fetching SharedPreferences...');
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      if (!mounted) return;
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('SharedPreferences'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: keys.isEmpty
                  ? [const Text('No preferences found.')]
                  : keys.map((k) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          '$k: ${prefs.get(k)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      );
                    }).toList(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
            TextButton(
              onPressed: () async {
                await prefs.clear();
                if (context.mounted) {
                  Navigator.pop(context);
                  _showSnackbar('SharedPreferences cleared!');
                }
              },
              child: const Text('Clear All', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) _showSnackbar('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Debug Menu'),
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Database Section
          _buildSectionHeader('Database', Icons.storage),
          ListTile(
            title: const Text('Total DB Events'),
            trailing: Text(
              '$_eventCount',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            subtitle: const Text('Tap to refresh count'),
            onTap: _refreshEventCount,
          ),
          ListTile(
            title: const Text('Clear All Events'),
            subtitle: const Text('Deletes every event in the database'),
            trailing: const Icon(Icons.delete_forever, color: Colors.red),
            onTap: _clearDatabase,
          ),
          ListTile(
            title: const Text('Reset Metrics & Windows'),
            subtitle: const Text('Deletes definitions and re-seeds defaults'),
            trailing: const Icon(Icons.refresh, color: Colors.orange),
            onTap: _resetMetrics,
          ),
          ListTile(
            title: const Text('Seed Dummy Data'),
            subtitle: const Text('Inserts 20 random past events for UI testing'),
            trailing: const Icon(Icons.auto_fix_high),
            onTap: _seedDummyData,
          ),
          ListTile(
            title: const Text('Export Data (JSON)'),
            subtitle: const Text('Generates and shares standard export'),
            trailing: const Icon(Icons.share),
            onTap: () async {
              try {
                await context.read<ExportService>().exportData();
              } catch (e) {
                _showSnackbar('Export failed: $e');
              }
            },
          ),
          ListTile(
            title: const Text('View SharedPreferences'),
            subtitle: const Text('Show all local key-value storage items'),
            trailing: const Icon(Icons.data_object),
            onTap: _viewSharedPreferences,
          ),
          ListTile(
            title: const Text('Copy Identity UUID'),
            subtitle: const Text('Copies your persistent researcher UUID to clipboard'),
            trailing: const Icon(Icons.perm_identity),
            onTap: _copyUuid,
          ),
          ListTile(
            title: const Text('Simulate Missed Check-in'),
            subtitle: const Text('Creates a tracking window that ended 5 mins ago'),
            trailing: const Icon(Icons.history_rounded),
            onTap: _testMissedCheckin,
          ),
          const Divider(),

          // App Updates Section
          _buildSectionHeader('App Updates', Icons.update),
          ListTile(
            title: const Text('Check for Updates (Verbose)'),
            subtitle: const Text('Runs the standard update check with UI feedback'),
            trailing: const Icon(Icons.refresh),
            onTap: () {
              UpdateService.checkAndPrompt(context, silent: false);
            },
          ),
          ListTile(
            title: const Text('Compare Versions (Debug)'),
            subtitle: const Text('Shows local vs server version details'),
            trailing: const Icon(Icons.bug_report),
            onTap: _showUpdateDebugInfo,
          ),
          const Divider(),

          // Notifications Section
          _buildSectionHeader('Notifications API', Icons.notifications_active),
          ListTile(
            title: const Text('Request Permissions'),
            subtitle: const Text('Prompt for notification access'),
            trailing: const Icon(Icons.security),
            onTap: () async {
              await context.read<NotificationService>().requestPermissions();
              _showSnackbar('Requested notification permissions');
            },
          ),
          ListTile(
            title: const Text('Test Notification (5s)'),
            subtitle: const Text('Schedule EMA prompt in 5 seconds'),
            trailing: const Icon(Icons.timer),
            onTap: () {
              NotificationService.schedulePrompt(
                delay: const Duration(seconds: 5),
              );
              _showSnackbar('Notification scheduled in 5 seconds');
            },
          ),
          ListTile(
            title: const Text('Cancel All Notifications'),
            subtitle: const Text('Clears all scheduled background alarms'),
            trailing: const Icon(Icons.notifications_off, color: Colors.red),
            onTap: _cancelAllNotifications,
          ),
          ListTile(
            title: const Text('View Scheduled Notifications'),
            subtitle: const Text('Shows list of all pending OS notifications'),
            trailing: const Icon(Icons.list_alt),
            onTap: _viewScheduledNotifications,
          ),
          ListTile(
            title: const Text('Trigger Fatigue Dialog'),
            subtitle: const Text('Fakes 3 missed notifications'),
            trailing: const Icon(Icons.warning_amber),
            onTap: _testFatigueDialog,
          ),
          const Divider(),

          // Passive Sensing Section
          _buildSectionHeader('Background Jobs', Icons.sync),
          ListTile(
            title: const Text('Force Passive Sync'),
            subtitle: const Text('Manually run 4-hour background job'),
            trailing: const Icon(Icons.play_arrow),
            onTap: () async {
              _showSnackbar('Syncing passive data...');
              try {
                await context.read<PassiveSensingService>().syncAll();
                _showSnackbar('Passive sync completed!');
                _refreshEventCount();
              } catch (e) {
                _showSnackbar('Passive sync failed: $e');
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
