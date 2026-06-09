import 'package:flutter/material.dart';
import 'usage_trends_screen.dart';
import 'correlation_matrix_screen.dart';
import 'interaction_screen.dart';
import 'compliance_screen.dart';
import 'lagged_trend_screen.dart';
import 'metric_insights_screen.dart';
import '../../ui/theme/design_system.dart';
import '../widgets/help_button.dart';


class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            // Custom Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Analytics',
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        const AppBarHelpButton(screenKey: 'analytics'),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Text(
                      'Deep dive into your behavioral data and discover patterns.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Grid of Analytics Options
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildListDelegate([
                  _AnalyticsCard(
                    title: 'Usage Trends',
                    description: 'Daily & weekly app usage patterns over time.',
                    icon: Icons.insights_rounded,
                    color: colorScheme.primary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UsageTrendsScreen()),
                    ),
                  ),
                  _AnalyticsCard(
                    title: 'Correlation',
                    description: 'Analyze relationships between behaviors.',
                    icon: Icons.grid_view_rounded,
                    color: colorScheme.tertiary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const CorrelationMatrixScreen()),
                    ),
                  ),
                  _AnalyticsCard(
                    title: 'HCI Metrics',
                    description: 'Analysis of interaction behavior and response latency.',
                    icon: Icons.touch_app_rounded,
                    color: colorScheme.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const InteractionScreen()),
                    ),
                  ),
                  _AnalyticsCard(
                    title: 'Data Quality',
                    description: 'Consistency and recall reliability metrics.',
                    icon: Icons.verified_user_rounded,
                    color: colorScheme.error,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ComplianceScreen()),
                    ),
                  ),
                  _AnalyticsCard(
                    title: 'Metric Insights',
                    description: 'Daily trends and circadian rhythms for individual metrics.',
                    icon: Icons.show_chart_rounded,
                    color: colorScheme.primaryContainer,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const MetricInsightsScreen()),
                    ),
                  ),
                  _AnalyticsCard(
                    title: 'Lagged Trend',
                    description: 'Discover time-delayed correlations between metrics.',
                    icon: Icons.timeline_rounded,
                    color: CovaryDesignSystem.secondary,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LaggedTrendScreen()),
                    ),
                  ),
                ]),
              ),
            ),

            // Bottom Section: Tips or Context
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_outline_rounded, color: colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Did you know?',
                            style: textTheme.labelLarge?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Consistent logging improves the accuracy of these insights. The Correlation Matrix works best with at least 14 days of data.',
                        style: textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _AnalyticsCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const Spacer(),
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 10,
                  height: 1.3,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
}
