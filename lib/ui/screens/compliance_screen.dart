import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/database/app_database.dart';
import '../../data/models/enums.dart';
import '../../services/metric_service.dart';
import 'activity_history_screen.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  bool _isLoading = true;
  Map<DateTime, double> _complianceMap = {};
  double _recallRatio = 0.0;

  @override
  void initState() {
    super.initState();
    _loadComplianceData();
  }

  Future<void> _loadComplianceData() async {
    final db = context.read<AppDatabase>();
    final metricService = context.read<MetricService>();
    final now = DateTime.now();
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    
    final events = await db.getEventsInDateRange(fourteenDaysAgo, now);
    
    // Filter out meta events and app usage for compliance.
    // IMPORTANT: We also exclude system-triggered events (passive sensing)
    // because they don't represent user-initiated compliance.
    final researchEvents = events.where((e) => 
      e.category != EventCategory.meta && 
      e.category != EventCategory.appUsage &&
      e.triggerSource != TriggerSource.system
    ).toList();

    // Calculate Real-time vs Recall (excluding system data)
    final total = researchEvents.length;
    final recall = researchEvents.where((e) => e.triggerSource == TriggerSource.manual).length;
    
    // Multi-shaded compliance map based on session completion
    final sessionEvents = events.where((e) => 
      e.category == EventCategory.meta && 
      e.label == 'SessionCompleted'
    ).toList();

    final totalWindows = metricService.allWindows.length;

    final Map<DateTime, double> tempMap = {};
    for (int i = 0; i < 14; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      
      final sessionsThisDay = sessionEvents.where((e) => 
        e.timestamp.year == date.year && 
        e.timestamp.month == date.month && 
        e.timestamp.day == date.day
      ).length;

      // Ratio of completed windows vs available windows
      final ratio = totalWindows > 0 
          ? (sessionsThisDay / totalWindows).clamp(0.0, 1.0) 
          : (sessionsThisDay > 0 ? 1.0 : 0.0);
      
      tempMap[date] = ratio;
    }

    if (mounted) {
      setState(() {
        _complianceMap = tempMap;
        _recallRatio = total > 0 ? (total - recall) / total : 1.0;
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
        title: const Text('Data Quality & Compliance'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(textTheme, colorScheme),
              const SizedBox(height: 32),
              _buildHeatmap(textTheme, colorScheme),
              const SizedBox(height: 32),
              _buildRecallCard(textTheme, colorScheme),
              const SizedBox(height: 32),
              _buildInfoCard(textTheme, colorScheme),
            ],
          ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Compliance Overview',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Tracking consistency is vital for valid research results.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildHeatmap(TextTheme textTheme, ColorScheme colorScheme) {
    final sortedDates = _complianceMap.keys.toList()..sort((a, b) => a.compareTo(b));
    
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ActivityHistoryScreen()),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '14-Day Activity',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: sortedDates.map((date) {
                final ratio = _complianceMap[date] ?? 0.0;
                final active = ratio > 0;
                
                // Shade intensity: 0.0 (Missed) -> 1.0 (Full)
                // We use a dark base for partial logs as requested by the user.
                final Color cellColor = active 
                    ? Color.lerp(const Color(0xFF0A1F0A), colorScheme.primary, ratio)!
                    : colorScheme.surface;

                return Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: active ? cellColor : colorScheme.outlineVariant,
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: active ? Colors.white : colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                _LegendItem(color: colorScheme.primary, label: 'Full'),
                const SizedBox(width: 12),
                _LegendItem(color: Color.lerp(const Color(0xFF0A1F0A), colorScheme.primary, 0.4)!, label: 'Partial'),
                const SizedBox(width: 12),
                _LegendItem(color: colorScheme.surface, label: 'Missed'),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildRecallCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recall Reliability',
                  style: textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onTertiaryContainer,
                  ),
                ),
                Icon(Icons.timer_outlined, color: colorScheme.onTertiaryContainer, size: 20),
              ],
            ),
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: _recallRatio,
              backgroundColor: colorScheme.onTertiaryContainer.withAlpha(30),
              color: colorScheme.tertiary,
              borderRadius: BorderRadius.circular(8),
              minHeight: 12,
            ),
            const SizedBox(height: 12),
            Text(
              '${(_recallRatio * 100).toStringAsFixed(1)}% In-the-moment logs',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: colorScheme.onTertiaryContainer,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Higher percentages indicate better data validity by reducing retrospective recall bias.',
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onTertiaryContainer.withAlpha(180),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              'These metrics help researchers evaluate the ecological validity of your data.',
              style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
