import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

  @override
  void initState() {
    super.initState();
    _loadInteractionData();
  }

  Future<void> _loadInteractionData() async {
    final db = context.read<AppDatabase>();
    final events = await db.getAllEvents();

    // Bug 1 fix: the old filter excluded ALL meta events, which meant
    // SwipeAway and Snooze (logged as meta by NotificationService) were
    // invisible in analytics. We now include meta events that represent
    // real user interactions with notification prompts, identified by
    // their triggerSource being 'notification' or by having a non-click
    // interactionType (swipeAway / snooze always come from notifications).
    //
    // Excluded: appUsage (passive), and meta events that are purely
    // system bookkeeping (SessionCompleted, PassiveSyncCompleted, etc.)
    // identified by being system-triggered with a click interactionType.
    final researchEvents = events.where((e) {
      if (e.category == EventCategory.appUsage) return false;
      if (e.category == EventCategory.meta) {
        // Include notification-interaction meta events (swipeAway, snooze,
        // and notification-click events logged by NotificationService).
        if (e.triggerSource == TriggerSource.notification) return true;
        if (e.interactionType == InteractionType.swipeAway) return true;
        if (e.interactionType == InteractionType.snooze) return true;
        // Exclude all other system/bookkeeping meta events.
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

    if (mounted) {
      setState(() {
        _interactionCounts = counts;
        _avgLatency = latencyCount > 0 ? totalLatency / latencyCount : 0.0;
        _totalInteractions = researchEvents.length;
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
        title: const Text('HCI Interaction Metrics'),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _buildHeader(textTheme, colorScheme),
              const SizedBox(height: 32),
              _buildLatencyCard(textTheme, colorScheme),
              const SizedBox(height: 24),
              _buildDistributionCard(textTheme, colorScheme),
              const SizedBox(height: 32),
              _buildInteractionLog(textTheme, colorScheme),
            ],
          ),
    );
  }

  Widget _buildHeader(TextTheme textTheme, ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Interaction Behavior',
          style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          'Analysis of prompt engagement and response friction.',
          style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildLatencyCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.primaryContainer.withAlpha(100),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Average Latency',
                    style: textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${(_avgLatency / 1000).toStringAsFixed(2)}s',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Time from prompt to save',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withAlpha(180),
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.speed_rounded, size: 48, color: colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _buildDistributionCard(TextTheme textTheme, ColorScheme colorScheme) {
    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withAlpha(150),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Engagement Type',
              style: textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            _InteractionBar(
              label: 'Clicks',
              count: _interactionCounts[InteractionType.click] ?? 0,
              total: _totalInteractions,
              color: Colors.green,
              icon: Icons.touch_app_rounded,
            ),
            const SizedBox(height: 16),
            _InteractionBar(
              label: 'Snoozes',
              count: _interactionCounts[InteractionType.snooze] ?? 0,
              total: _totalInteractions,
              color: Colors.orange,
              icon: Icons.snooze_rounded,
            ),
            const SizedBox(height: 16),
            _InteractionBar(
              label: 'Swipes',
              count: _interactionCounts[InteractionType.swipeAway] ?? 0,
              total: _totalInteractions,
              color: Colors.red,
              icon: Icons.swipe_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInteractionLog(TextTheme textTheme, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withAlpha(100),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withAlpha(100)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: colorScheme.secondary, size: 20),
              const SizedBox(width: 8),
              Text(
                'HCI Insight',
                style: textTheme.labelLarge?.copyWith(
                  color: colorScheme.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'High latency combined with frequent snoozing may indicate "Prompt Fatigue" or survey friction in specific contexts.',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InteractionBar extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;
  final IconData icon;

  const _InteractionBar({
    required this.label,
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
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(label, style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('$count', style: textTheme.labelSmall),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: ratio,
            backgroundColor: color.withAlpha(30),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
