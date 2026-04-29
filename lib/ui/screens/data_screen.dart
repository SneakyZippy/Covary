import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../services/metric_service.dart';
import '../../services/export_service.dart';
import 'raw_data_screen.dart';
import 'metrics_screen.dart';
import 'profile_setup_screen.dart';
import 'permission_shield_screen.dart';
import 'compliance_screen.dart';
import '../../services/profile_service.dart';
import '../../services/health_service.dart';
import '../../services/app_usage_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/services.dart';



/// Screen showing high-level data insights and access to raw logs.
class DataScreen extends StatefulWidget {
  const DataScreen({super.key});

  @override
  State<DataScreen> createState() => _DataScreenState();
}

class _DataScreenState extends State<DataScreen> {
  int _todayEntryCount = 0;
  bool _isLoading = true;
  bool _healthEnabled = false;
  bool _usageEnabled = false;
  bool _notificationsEnabled = false;
  Map<DateTime, bool> _complianceMap = {};
  List<Event> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    
    await Future.wait([
      _loadStats(),
      _checkPermissions(),
      _loadComplianceData(),
      _loadRecentEvents(),
    ]);

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkPermissions() async {
    final health = context.read<HealthService>();
    final usage = context.read<AppUsageService>();
    
    final h = await health.hasPermissions();
    final u = await usage.isPermissionGranted();
    final n = await AwesomeNotifications().isNotificationAllowed();

    if (mounted) {
      setState(() {
        _healthEnabled = h;
        _usageEnabled = u;
        _notificationsEnabled = n;
      });
    }
  }

  Future<void> _loadRecentEvents() async {
    final db = context.read<AppDatabase>();
    final events = await db.getAllEvents();
    
    // Sort and take top 3
    final sorted = events.where((e) => e.category != EventCategory.meta).toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    if (mounted) {
      setState(() {
        _recentEvents = sorted.take(3).toList();
      });
    }
  }

  Future<void> _loadComplianceData() async {
    final db = context.read<AppDatabase>();
    final now = DateTime.now();
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    
    final events = await db.getEventsInDateRange(fourteenDaysAgo, now);
    final researchEvents = events.where((e) => 
      e.category != EventCategory.meta && 
      e.category != EventCategory.appUsage
    ).toList();

    final Map<DateTime, bool> tempMap = {};
    for (int i = 0; i < 14; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final hasData = researchEvents.any((e) => 
        e.timestamp.year == date.year && 
        e.timestamp.month == date.month && 
        e.timestamp.day == date.day
      );
      tempMap[date] = hasData;
    }

    if (mounted) {
      setState(() {
        _complianceMap = tempMap;
      });
    }
  }

  Future<void> _loadStats() async {
    final db = context.read<AppDatabase>();
    final allEvents = await db.getAllEvents();
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    final todayEvents = allEvents.where((e) {
      return e.timestamp.isAfter(todayStart) &&
          e.triggerSource == TriggerSource.manual &&
          e.category != EventCategory.meta;
    }).length;

    if (mounted) {
      setState(() {
        _todayEntryCount = todayEvents;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final metricService = context.watch<MetricService>();
    final profileService = context.watch<ProfileService>();

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadAllData,
          child: CustomScrollView(
            slivers: [
              // Custom Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      Text(
                        'Insights & Data',
                        style: textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Monitor your progress and manage your logs.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Research Identity Card ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfileSetupScreen()),
                    ),
                    borderRadius: BorderRadius.circular(28),
                    child: _IdentityCard(
                      uuid: profileService.uuid,
                      studyDay: profileService.studyDay,
                    ),
                  ),
                ),
              ),

              // --- Activity & Integrity Row ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          flex: 3,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const PermissionShieldScreen()),
                            ),
                            borderRadius: BorderRadius.circular(24),
                            child: _IntegrityDashboard(
                              healthActive: _healthEnabled,
                              usageActive: _usageEnabled,
                              notificationsActive: _notificationsEnabled,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: InkWell(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ComplianceScreen()),
                            ),
                            borderRadius: BorderRadius.circular(24),
                            child: _MiniHeatmap(complianceMap: _complianceMap),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // --- Daily Summary ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: _ActivitySummaryCard(
                    todayCount: _todayEntryCount,
                    activeMetricsCount: metricService.activeMetrics.length,
                  ),
                ),
              ),

              // --- Recent Activity ---
              if (_recentEvents.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _RecentActivityPreview(
                      events: _recentEvents,
                      onViewAll: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RawDataScreen()),
                      ),
                    ),
                  ),
                ),

              // --- Management Section ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
                  child: Text(
                    'Management',
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
                  child: Column(
                    children: [
                      _CompactMenuTile(
                        title: 'Detailed Records',
                        icon: Icons.list_alt_rounded,
                        color: colorScheme.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RawDataScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _CompactMenuTile(
                        title: 'Tracked Metrics',
                        icon: Icons.settings_suggest_rounded,
                        color: colorScheme.tertiary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MetricsScreen()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // --- Data & Privacy Section ---
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Text(
                    'Data & Privacy',
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
                  child: Column(
                    children: [
                      _ActionCard(
                        title: 'Export JSON',
                        subtitle: 'Manual backup for research sharing',
                        icon: Icons.share_rounded,
                        onTap: () async {
                          final exportService = context.read<ExportService>();
                          final success = await exportService.exportData();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(success 
                                  ? 'Export successful!' 
                                  : 'Export failed. Check permissions.'),
                              ),
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                      _StatusCard(
                        title: 'Local Database',
                        status: 'Active',
                        icon: Icons.storage_rounded,
                      ),
                    ],
                  ),
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitySummaryCard extends StatelessWidget {
  final int todayCount;
  final int activeMetricsCount;

  const _ActivitySummaryCard({
    required this.todayCount,
    required this.activeMetricsCount,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Daily Progress',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$todayCount logs today',
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(Icons.check_circle_outline, 
                           size: 14, 
                           color: colorScheme.onPrimaryContainer.withAlpha(180)),
                      const SizedBox(width: 4),
                      Text(
                        '$activeMetricsCount metrics currently active',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimaryContainer.withAlpha(180),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.onPrimaryContainer.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: colorScheme.onPrimaryContainer,
                size: 32,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _CompactMenuTile({
    required this.title,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onTap,
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.secondary),
        title: Text(title, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: textTheme.bodySmall),
        trailing: Icon(Icons.outbound_outlined, size: 20, color: colorScheme.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final IconData icon;

  const _StatusCard({
    required this.title,
    required this.status,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(120),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        leading: Icon(icon, color: colorScheme.onSurfaceVariant),
        title: Text(title, style: textTheme.titleSmall),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withAlpha(100)),
          ),
          child: const Text(
            'ACTIVE',
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String uuid;
  final int studyDay;

  const _IdentityCard({required this.uuid, required this.studyDay});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final shortUuid = uuid.length > 8 ? uuid.substring(0, 8).toUpperCase() : uuid;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [colorScheme.primary, colorScheme.primary.withAlpha(180)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withAlpha(40),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'RESEARCH IDENTITY',
                style: textTheme.labelSmall?.copyWith(
                  color: colorScheme.onPrimary.withAlpha(180),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.onPrimary.withAlpha(40),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'DAY $studyDay',
                  style: textTheme.labelMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Participant ID',
            style: textTheme.bodySmall?.copyWith(color: colorScheme.onPrimary.withAlpha(150)),
          ),
          Row(
            children: [
              Text(
                '#$shortUuid',
                style: textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.copy_rounded, color: colorScheme.onPrimary, size: 20),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: uuid));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Participant ID copied to clipboard')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _IntegrityDashboard extends StatelessWidget {
  final bool healthActive;
  final bool usageActive;
  final bool notificationsActive;

  const _IntegrityDashboard({
    required this.healthActive,
    required this.usageActive,
    required this.notificationsActive,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Data Integrity',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _IntegrityItem(
              label: 'Notifications',
              isActive: notificationsActive,
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 8),
            _IntegrityItem(
              label: 'Health Data',
              isActive: healthActive,
              icon: Icons.favorite_outline_rounded,
            ),
            const SizedBox(height: 8),
            _IntegrityItem(
              label: 'App Usage',
              isActive: usageActive,
              icon: Icons.app_registration_rounded,
            ),
          ],
        ),
      ),
    );
  }
}

class _IntegrityItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData icon;

  const _IntegrityItem({
    required this.label,
    required this.isActive,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: isActive ? colorScheme.primary : colorScheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: isActive ? FontWeight.w500 : FontWeight.normal,
              color: isActive ? colorScheme.onSurface : colorScheme.error,
            ),
          ),
        ),
        Icon(
          isActive ? Icons.check_circle_rounded : Icons.warning_rounded,
          size: 14,
          color: isActive ? Colors.green : colorScheme.error,
        ),
      ],
    );
  }
}

class _MiniHeatmap extends StatelessWidget {
  final Map<DateTime, bool> complianceMap;

  const _MiniHeatmap({required this.complianceMap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final sortedDates = complianceMap.keys.toList()..sort((a, b) => a.compareTo(b));
    // Split into 2 rows of 7
    final firstRow = sortedDates.take(7).toList();
    final secondRow = sortedDates.skip(7).take(7).toList();

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(12.0), // Reduced from 20
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Activity',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            FittedBox(child: _buildHeatRow(firstRow, colorScheme)),
            const SizedBox(height: 4),
            FittedBox(child: _buildHeatRow(secondRow, colorScheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatRow(List<DateTime> dates, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: dates.map((d) {
        final active = complianceMap[d] ?? false;
        return Container(
          width: 10, // Reduced from 12
          height: 10, // Reduced from 12
          margin: const EdgeInsets.all(1.5), // Reduced from 2
          decoration: BoxDecoration(
            color: active ? colorScheme.primary : colorScheme.surface,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(
              color: active ? colorScheme.primary : colorScheme.outlineVariant.withAlpha(50),
              width: 0.5,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _RecentActivityPreview extends StatelessWidget {
  final List<Event> events;
  final VoidCallback onViewAll;

  const _RecentActivityPreview({required this.events, required this.onViewAll});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Recent Logs',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View All'),
              ),
            ],
          ),
        ),
        ...events.map((e) {
          final time = '${e.timestamp.hour.toString().padLeft(2, '0')}:${e.timestamp.minute.toString().padLeft(2, '0')}';
          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 8),
            color: colorScheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              onTap: onViewAll, // Pointing individual logs to the list as well
              borderRadius: BorderRadius.circular(16),
              child: ListTile(
                dense: true,
                leading: Icon(Icons.history_toggle_off_rounded, size: 18, color: colorScheme.secondary),
                title: Text(
                  e.label,
                  style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Value: ${e.value}',
                  style: textTheme.bodySmall,
                ),
                trailing: Text(
                  time,
                  style: textTheme.labelSmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
