import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/models/enums.dart';
import '../../data/repositories/event_repository.dart';
import '../../services/metric_service.dart';

class ComplianceScreen extends StatefulWidget {
  const ComplianceScreen({super.key});

  @override
  State<ComplianceScreen> createState() => _ComplianceScreenState();
}

class _ComplianceScreenState extends State<ComplianceScreen> {
  bool _isLoading = true;
  Map<DateTime, double> _complianceMap = {};
  double _recallRatio = 0.0;
  double _overallCompliance = 0.0;
  int _completedSessions = 0;
  int _totalPossibleSessions = 0;

  @override
  void initState() {
    super.initState();
    _loadComplianceData();
  }

  Future<void> _loadComplianceData() async {
    final eventRepo = context.read<EventRepository>();
    final metricService = context.read<MetricService>();
    final now = DateTime.now();
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));
    
    final events = await eventRepo.getEventsInDateRange(fourteenDaysAgo, now);
    
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
    final recall = researchEvents.where((e) {
      if (e.recordedAt == null) {
        // Fallback for older database versions without recordedAt
        return e.triggerSource == TriggerSource.manual;
      }
      
      // If the event was logged more than 15 minutes after the time it "happened"
      // (e.g. user backdated it, or it was a missed window check-in), 
      // then it is considered a retrospective recall.
      final diff = e.recordedAt!.difference(e.timestamp).inMinutes.abs();
      return diff > 15;
    }).length;
    
    // Multi-shaded compliance map based on session completion
    final sessionEvents = events.where((e) => 
      e.category == EventCategory.meta && 
      e.label == 'SessionCompleted'
    ).toList();

    final totalWindows = metricService.allWindows.where((w) => w.isEnabled).length;

    final Map<DateTime, double> tempMap = {};
    double sumRatios = 0.0;
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
      sumRatios += ratio;
    }

    int completedCount = 0;
    for (int i = 0; i < 14; i++) {
      final date = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final sessionsThisDay = sessionEvents.where((e) => 
        e.timestamp.year == date.year && 
        e.timestamp.month == date.month && 
        e.timestamp.day == date.day
      ).length;
      completedCount += sessionsThisDay;
    }

    if (mounted) {
      setState(() {
        _complianceMap = tempMap;
        _recallRatio = total > 0 ? (total - recall) / total : 1.0;
        _overallCompliance = sumRatios / 14;
        _completedSessions = completedCount;
        _totalPossibleSessions = totalWindows * 14;
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
              const SizedBox(height: 24),
              _buildOverallScoreCard(textTheme, colorScheme),
              const SizedBox(height: 24),
              _buildComplianceRingsGrid(textTheme, colorScheme),
              const SizedBox(height: 24),
              _buildRecallCard(textTheme, colorScheme),
              const SizedBox(height: 24),
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

  Widget _buildOverallScoreCard(TextTheme textTheme, ColorScheme colorScheme) {
    final percentage = (_overallCompliance * 100).toStringAsFixed(0);
    final isTargetMet = _overallCompliance >= 0.8;
    
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer.withAlpha(60),
            colorScheme.surfaceContainerHighest.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.primary.withAlpha(80),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 72,
                  height: 72,
                  child: CircularProgressIndicator(
                    value: _overallCompliance,
                    strokeWidth: 6,
                    backgroundColor: colorScheme.outlineVariant.withValues(alpha: 0.3),
                    valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
                  ),
                ),
                Text(
                  '$percentage%',
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Consistency Score',
                    style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        isTargetMet ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        size: 14,
                        color: isTargetMet ? Colors.green.shade400 : Colors.orange.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isTargetMet ? 'Target Met (>80%)' : 'Below Target (<80%)',
                        style: textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isTargetMet ? Colors.green.shade400 : Colors.orange.shade400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Completed $_completedSessions of $_totalPossibleSessions scheduled check-ins over the last 14 days.',
                    style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplianceRingsGrid(TextTheme textTheme, ColorScheme colorScheme) {
    final sortedDates = _complianceMap.keys.toList()..sort((a, b) => a.compareTo(b));
    final row1 = sortedDates.take(7).toList();
    final row2 = sortedDates.skip(7).take(7).toList();
    
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
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '14-Day Session History',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildRingsRow(row1, textTheme, colorScheme),
            const SizedBox(height: 16),
            _buildRingsRow(row2, textTheme, colorScheme),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _LegendItem(color: colorScheme.primary, label: 'Full (100%)'),
                const SizedBox(width: 16),
                _LegendItem(color: colorScheme.primary.withValues(alpha: 0.4), label: 'Partial'),
                const SizedBox(width: 16),
                _LegendItem(
                  color: Colors.transparent, 
                  label: 'Missed (0%)', 
                  hasBorder: true,
                  borderColor: colorScheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRingsRow(List<DateTime> dates, TextTheme textTheme, ColorScheme colorScheme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: dates.map((date) {
        final ratio = _complianceMap[date] ?? 0.0;
        final isFull = ratio >= 0.99;
        final isMissed = ratio <= 0.01;
        
        final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        final weekdayStr = weekdayNames[date.weekday - 1].substring(0, 1);
        
        Color progressColor = colorScheme.primary;
        Color bgRingColor = colorScheme.outlineVariant.withValues(alpha: 0.3);
        Widget ringCenter;

        if (isFull) {
          ringCenter = Icon(
            Icons.check_rounded,
            size: 14,
            color: colorScheme.primary,
          );
        } else if (isMissed) {
          ringCenter = Text(
            '${date.day}',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          );
        } else {
          ringCenter = Text(
            '${date.day}',
            style: textTheme.bodySmall?.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          );
        }

        return Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                weekdayStr,
                style: textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              Tooltip(
                message: '${date.month}/${date.day}: ${(ratio * 100).toStringAsFixed(0)}% compliance',
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 34,
                      height: 34,
                      child: CircularProgressIndicator(
                        value: isMissed ? 0.0 : ratio,
                        strokeWidth: 3.2,
                        backgroundColor: bgRingColor,
                        valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                      ),
                    ),
                    ringCenter,
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRecallCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.tertiaryContainer.withAlpha(80),
            colorScheme.surfaceContainerHighest.withAlpha(40),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: colorScheme.tertiary.withAlpha(80),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
  final bool hasBorder;
  final Color? borderColor;

  const _LegendItem({
    required this.color,
    required this.label,
    this.hasBorder = false,
    this.borderColor,
  });

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
            border: Border.all(
              color: hasBorder 
                  ? (borderColor ?? Theme.of(context).colorScheme.outlineVariant)
                  : Colors.transparent,
              width: 1.2,
            ),
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
