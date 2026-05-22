import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
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
import '../widgets/data_widgets.dart';
import '../widgets/integrity_dashboard.dart';
import '../widgets/settings_tiles.dart';
import 'package:awesome_notifications/awesome_notifications.dart';

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
    final eventRepo = context.read<EventRepository>();
    final events = await eventRepo.getAllEvents();
    
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
    final eventRepo = context.read<EventRepository>();
    final now = DateTime.now();
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    
    final events = await eventRepo.getEventsInDateRange(fourteenDaysAgo, now);
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
    final eventRepo = context.read<EventRepository>();
    final allEvents = await eventRepo.getAllEvents();
    
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
                    child: IdentityCard(
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
                            child: IntegrityDashboard(
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
                            child: MiniHeatmap(complianceMap: _complianceMap),
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
                  child: ActivitySummaryCard(
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
                    child: RecentActivityPreview(
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
                      CompactMenuTile(
                        title: 'Detailed Records',
                        icon: Icons.list_alt_rounded,
                        color: colorScheme.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RawDataScreen()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      CompactMenuTile(
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
                      ActionCard(
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
                      const StatusCard(
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
