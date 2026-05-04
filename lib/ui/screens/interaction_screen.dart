import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';

import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';

class InteractionScreen extends StatefulWidget {
  const InteractionScreen({super.key});

  @override
  State<InteractionScreen> createState() => _InteractionScreenState();
}

class _InteractionScreenState extends State<InteractionScreen> {
  bool _isLoading = true;
  Map<InteractionType, int> _interactionCounts = {};
  double _avgLatency = 0.0;
  int _totalInteractions = 0;
  double _engagementScore = 0.0;
  List<FlSpot> _clickSpots = [];
  List<FlSpot> _frictionSpots = []; // Snoozes + Swipes
  List<DateTime> _trendDates = [];

  @override
  void initState() {
    super.initState();
    _loadInteractionData();
  }

  Future<void> _loadInteractionData() async {
    final db = context.read<AppDatabase>();
    final events = await db.getAllEvents();

    final researchEvents = events.where((e) {
      if (e.category == EventCategory.appUsage) return false;
      if (e.category == EventCategory.meta) {
        if (e.triggerSource == TriggerSource.notification) return true;
        if (e.interactionType == InteractionType.swipeAway) return true;
        if (e.interactionType == InteractionType.snooze) return true;
        return false;
      }
      return true;
    }).toList();

    final counts = <InteractionType, int>{};
    int totalLatency = 0;
    int latencyCount = 0;

    for (final e in researchEvents) {
      counts[e.interactionType] = (counts[e.interactionType] ?? 0) + 1;
      if (e.latencyMs > 0) {
        totalLatency += e.latencyMs;
        latencyCount++;
      }
    }

    // --- Trend Calculation (Last 14 Days) ---
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final List<FlSpot> clicks = [];
    final List<FlSpot> friction = [];
    final List<DateTime> dates = [];

    for (int i = 13; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      dates.add(date);
      
      final dayEvents = researchEvents.where((e) =>
          e.timestamp.year == date.year &&
          e.timestamp.month == date.month &&
          e.timestamp.day == date.day).toList();

      final dayClicks = dayEvents.where((e) => e.interactionType == InteractionType.click).length;
      final dayFriction = dayEvents.where((e) => 
          e.interactionType == InteractionType.snooze || 
          e.interactionType == InteractionType.swipeAway).length;

      clicks.add(FlSpot((13 - i).toDouble(), dayClicks.toDouble()));
      friction.add(FlSpot((13 - i).toDouble(), dayFriction.toDouble()));
    }

    final clickCount = counts[InteractionType.click] ?? 0;
    final total = researchEvents.length;

    if (mounted) {
      setState(() {
        _interactionCounts = counts;
        _avgLatency = latencyCount > 0 ? totalLatency / latencyCount : 0.0;
        _totalInteractions = total;
        _engagementScore = total > 0 ? clickCount / total : 0.0;
        _clickSpots = clicks;
        _frictionSpots = friction;
        _trendDates = dates;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction Analysis'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHCIInfo(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInteractionData,
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _buildEngagementHeader(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  _buildPrimaryStats(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  _buildTrendCard(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  _buildDistributionCard(textTheme, colorScheme),
                  const SizedBox(height: 32),
                  _buildInsightCard(textTheme, colorScheme),
                ],
              ),
            ),
    );
  }

  Widget _buildEngagementHeader(TextTheme textTheme, ColorScheme colorScheme) {
    String level;
    Color color;
    if (_engagementScore > 0.8) {
      level = 'Exceptional';
      color = Colors.green;
    } else if (_engagementScore > 0.5) {
      level = 'Active';
      color = colorScheme.primary;
    } else {
      level = 'Needs Attention';
      color = colorScheme.error;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Engagement Status',
                  style: textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  level,
                  style: textTheme.headlineMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_graph_rounded, color: color, size: 32),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _engagementScore,
            minHeight: 12,
            backgroundColor: colorScheme.surfaceContainerHighest,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryStats(TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Response Speed',
            value: '${(_avgLatency / 1000).toStringAsFixed(2)}s',
            subtitle: 'Avg. time to log',
            icon: Icons.timer_outlined,
            color: colorScheme.primary,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _StatCard(
            label: 'Interaction count',
            value: '$_totalInteractions',
            subtitle: 'Total events',
            icon: Icons.analytics_outlined,
            color: colorScheme.secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Engagement Fatigue Trend',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tracking clicks vs. dismissals over the last 14 days.',
          style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Container(
          height: 240,
          padding: const EdgeInsets.fromLTRB(12, 24, 24, 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest.withAlpha(100),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
          ),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      if (value.toInt() % 4 != 0) return const SizedBox.shrink();
                      final date = _trendDates[value.toInt()];
                      return Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          DateFormat('MM/dd').format(date),
                          style: textTheme.labelSmall?.copyWith(fontSize: 9),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: _clickSpots,
                  isCurved: true,
                  color: Colors.green,
                  barWidth: 4,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.green.withAlpha(20)),
                ),
                LineChartBarData(
                  spots: _frictionSpots,
                  isCurved: true,
                  color: Colors.red,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dashArray: [5, 5],
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(show: true, color: Colors.red.withAlpha(10)),
                ),
              ],
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (spot) => colorScheme.surfaceContainerHighest,
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      final isClick = s.barIndex == 0;
                      return LineTooltipItem(
                        '${isClick ? "Clicks" : "Friction"}: ${s.y.toInt()}',
                        textTheme.labelSmall!.copyWith(
                          color: isClick ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    }).toList();
                  },
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendItem(color: Colors.green, label: 'Logs', dotted: false),
            const SizedBox(width: 24),
            _LegendItem(color: Colors.red, label: 'Dismissals', dotted: true),
          ],
        ),
      ],
    );
  }

  Widget _buildDistributionCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interaction Breakdown',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          color: colorScheme.surfaceContainerHighest.withAlpha(150),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                _InteractionBar(
                  label: 'Immediate Logging',
                  description: 'Proactive or immediate responses',
                  count: _interactionCounts[InteractionType.click] ?? 0,
                  total: _totalInteractions,
                  color: Colors.green,
                  icon: Icons.check_circle_rounded,
                ),
                const SizedBox(height: 20),
                _InteractionBar(
                  label: 'Snoozed Prompts',
                  description: 'Delayed responses to a later time',
                  count: _interactionCounts[InteractionType.snooze] ?? 0,
                  total: _totalInteractions,
                  color: Colors.orange,
                  icon: Icons.access_time_filled_rounded,
                ),
                const SizedBox(height: 20),
                _InteractionBar(
                  label: 'Dismissed / Swiped',
                  description: 'Ignored or swiped away prompts',
                  count: _interactionCounts[InteractionType.swipeAway] ?? 0,
                  total: _totalInteractions,
                  color: Colors.red,
                  icon: Icons.block_flipped,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInsightCard(TextTheme textTheme, ColorScheme colorScheme) {
    String insight;
    IconData icon;
    if (_avgLatency < 5000 && _engagementScore > 0.7) {
      insight = 'Quick responses and high engagement suggest low "survey friction" and high data reliability.';
      icon = Icons.bolt_rounded;
    } else if (_avgLatency > 15000) {
      insight = 'Higher response times may indicate cognitive load or that prompts are arriving at inconvenient times.';
      icon = Icons.hourglass_empty_rounded;
    } else {
      insight = 'Consistency is key. Regular interactions provide the most stable data for correlation analysis.';
      icon = Icons.tips_and_updates_outlined;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.secondaryContainer.withAlpha(150),
            colorScheme.secondaryContainer.withAlpha(50),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.secondary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: colorScheme.secondary, size: 24),
              const SizedBox(width: 12),
              Text(
                'HCI Researcher Insight',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            insight,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSecondaryContainer,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  void _showHCIInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('HCI Metrics Explained'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoItem(
                title: 'Response Speed (Latency)',
                desc: 'How long it takes from seeing a prompt to saving data. High speed suggests the app is easy to use "in the moment."',
              ),
              SizedBox(height: 16),
              _InfoItem(
                title: 'Snooze Frequency',
                desc: 'Indicates "Resistance." If you snooze often, the prompt timing might need adjustment to better fit your routine.',
              ),
              SizedBox(height: 16),
              _InfoItem(
                title: 'Dismissal Rate',
                desc: 'Measures "Survey Fatigue." Swiping away prompts reduces data density and may introduce gaps in your research.',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Got it')),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withAlpha(100)),
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 16),
          Text(
            value,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionBar extends StatelessWidget {
  final String label;
  final String description;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _InteractionBar({
    required this.label,
    required this.description,
    required this.count,
    required this.total,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? count / total : 0.0;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(description, style: textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
            Text(
              '${(ratio * 100).toInt()}%',
              style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: color),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withAlpha(30),
            color: color,
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final String title;
  final String desc;

  const _InfoItem({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          desc,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool dotted;

  const _LegendItem({required this.color, required this.label, required this.dotted});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: dotted ? Center(child: Container(width: 10, height: 3, color: Colors.white.withAlpha(150))) : null,
        ),
        const SizedBox(width: 8),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

