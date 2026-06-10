import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/design_system.dart';


class HelpContent {
  final String title;
  final String subtitle;
  final List<HelpSection> sections;

  const HelpContent({
    required this.title,
    required this.subtitle,
    required this.sections,
  });
}

class HelpSection {
  final String title;
  final String body;
  final IconData icon;

  const HelpSection({
    required this.title,
    required this.body,
    required this.icon,
  });
}

/// A reusable help/info button for app bars and headers.
///
/// Tapping the button opens a modern, design-system-compliant
/// bottom sheet with contextual tutorial content.
class AppBarHelpButton extends StatelessWidget {
  final String screenKey;
  final Color? iconColor;

  const AppBarHelpButton({
    super.key,
    required this.screenKey,
    this.iconColor,
  });

  // Reusable Registry of Screen Help Content (extracted from TUTORIAL.md)
  static const Map<String, HelpContent> _registry = {
    'home': HelpContent(
      title: 'Home Screen Guide',
      subtitle: 'Your Ecological Momentary Assessment (EMA) cockpit',
      sections: [
        HelpSection(
          title: 'Active Check-In Cards',
          body: 'During your active tracking windows, a prompt card will appear. Tap "Start Now" to log your immediate, in-the-moment feelings.',
          icon: Icons.play_arrow_rounded,
        ),
        HelpSection(
          title: 'Retrospective Missed Cards',
          body: 'Passed windows can still be completed. Subjective questions (mood, stress) are dimmed and disabled by default to minimize memory recall bias, while objective ones (sleep, step count) remain active.',
          icon: Icons.history_toggle_off_rounded,
        ),
        HelpSection(
          title: 'Quick Track Gestures',
          body: '• Single Tap: Instantly logs +1 unit (e.g. coffee cup, water).\n• Long Press: Opens a value slider to log custom amounts, backdate the entry to a specific hour, or save a new default tap amount.',
          icon: Icons.touch_app_rounded,
        ),
        HelpSection(
          title: 'Interactive Timeline',
          body: 'At the bottom, view chronological nodes of today\'s logs. Tap any node to inspect details such as logging latency and trigger source.',
          icon: Icons.timeline_rounded,
        ),
      ],
    ),
    'analytics': HelpContent(
      title: 'Analytics Overview',
      subtitle: 'Deep dive into local data processing',
      sections: [
        HelpSection(
          title: 'Local Computation',
          body: 'All mathematical and statistical processing runs locally on background threads (isolates) to keep your UI responsive and your data secure.',
          icon: Icons.memory_rounded,
        ),
        HelpSection(
          title: 'Usage & Category Trends',
          body: 'Visualize screen time, categories (social vs. gaming), and data completeness graphs.',
          icon: Icons.bar_chart_rounded,
        ),
        HelpSection(
          title: 'Relationships & Time Lags',
          body: 'Find direct correlations or explore delayed causal links (e.g. how weekend sleep affects weekday focus).',
          icon: Icons.swap_horiz_rounded,
        ),
      ],
    ),
    'correlation_matrix': HelpContent(
      title: 'Correlation Matrix Guide',
      subtitle: 'Spearman\'s Rank Correlation Heatmap',
      sections: [
        HelpSection(
          title: 'What is Correlation?',
          body: 'Measures how two metrics move together. A value near +1.0 means they rise together; -1.0 means when one rises, the other drops.',
          icon: Icons.grid_view_rounded,
        ),
        HelpSection(
          title: 'Dynamic Variables & Filters',
          body: 'Tap the filter list icon in the top right to customize which metrics represent rows and columns in your matrix.',
          icon: Icons.filter_list_rounded,
        ),
        HelpSection(
          title: 'Spearman vs. Pearson',
          body: 'Spearman correlation measures monotonic relationships, making it perfect for ordinal scales like 1-5 mood or 1-10 wellness ratings.',
          icon: Icons.psychology_rounded,
        ),
        HelpSection(
          title: 'Data Constraints',
          body: 'For statistical relevance, the matrix requires at least 14 days of logged entries across overlapping metrics.',
          icon: Icons.warning_amber_rounded,
        ),
        HelpSection(
          title: 'Crosshair Tracing & Details',
          body: '• First Click: Highlights the row and column crosshairs to easily trace metric labels.\n• Second Click (on highlighted cell): Opens the detailed correlation chart bottom sheet.',
          icon: Icons.touch_app_rounded,
        ),
      ],
    ),
    'lagged_trend': HelpContent(
      title: 'Lagged Trends Guide',
      subtitle: 'Identify delayed causal behaviors',
      sections: [
        HelpSection(
          title: 'What is Lagged Trend?',
          body: 'Analyses whether a habit today causes a state tomorrow. (e.g. "If my screen time rises today, does my mood drop 2 days from now?")',
          icon: Icons.hourglass_bottom_rounded,
        ),
        HelpSection(
          title: 'Day Offset Slider',
          body: 'Slide the offset from 1 to 7 days to shift the correlation window. The chart highlights how correlation scores peak or decay over time.',
          icon: Icons.linear_scale_rounded,
        ),
        HelpSection(
          title: 'Overlapping Threshold',
          body: 'Requires at least 3 days of overlapping data for the selected day offset to avoid displaying inaccurate predictive trends.',
          icon: Icons.info_outline_rounded,
        ),
      ],
    ),
    'usage_trends': HelpContent(
      title: 'App Usage Trends',
      subtitle: 'Passive digital habit tracking',
      sections: [
        HelpSection(
          title: 'Screen Time Tracking',
          body: 'Computes total active screen time and tracks active categories (Social, Entertainment, Gaming, Productivity).',
          icon: Icons.phone_android_rounded,
        ),
        HelpSection(
          title: 'App Category Manager',
          body: 'Tap the top settings/manager icon to classify specific application package names into standard research categories.',
          icon: Icons.category_rounded,
        ),
        HelpSection(
          title: 'Background Syncing',
          body: 'A background worker fetches UsageStats every 4 hours automatically. If paused, a banner will prompt you on the home screen.',
          icon: Icons.sync_rounded,
        ),
      ],
    ),
    'interaction': HelpContent(
      title: 'HCI Interaction Metrics',
      subtitle: 'Human-Computer Interaction analysis',
      sections: [
        HelpSection(
          title: 'Response Latency',
          body: 'Measures the time (in milliseconds) from when a check-in form opens to when you click "Save". This evaluates prompt friction.',
          icon: Icons.timer_rounded,
        ),
        HelpSection(
          title: 'Swipe vs. Click vs. Snooze',
          body: 'Tracks how you respond to prompts (immediate logs, dismissals/swipes, or snooze delays) to evaluate survey fatigue.',
          icon: Icons.touch_app_rounded,
        ),
        HelpSection(
          title: 'Fatigue Protection',
          body: 'If you swipe away three consecutive notifications, the app prompts you to adjust your schedule to prevent notification spam.',
          icon: Icons.security_rounded,
        ),
      ],
    ),
    'compliance': HelpContent(
      title: 'Compliance & Data Quality',
      subtitle: 'Ensuring study validity',
      sections: [
        HelpSection(
          title: 'Compliance Rate',
          body: 'Tracks completed windows versus missed or swiped sessions. High compliance yields high-quality thesis data.',
          icon: Icons.verified_user_rounded,
        ),
        HelpSection(
          title: 'Recall Reliability',
          body: 'Logs the ratio of in-the-moment check-ins versus retrospective (missed) check-ins. Retrospective entries introduce recall bias.',
          icon: Icons.psychology_rounded,
        ),
      ],
    ),
    'metric_insights': HelpContent(
      title: 'Metric Insights',
      subtitle: 'Detailed single-metric analytics',
      sections: [
        HelpSection(
          title: 'Diurnal Cycles (Circadian)',
          body: 'Groups and compares ratings by morning, afternoon, and evening to highlight circadian fluctuations (e.g. energy levels).',
          icon: Icons.wb_sunny_rounded,
        ),
        HelpSection(
          title: 'Weekly Averages',
          body: 'Identifies whether metrics show significant differences between weekdays and weekends.',
          icon: Icons.calendar_view_week_rounded,
        ),
      ],
    ),
    'settings': HelpContent(
      title: 'Data & App Settings',
      subtitle: 'Customize variables and sync status',
      sections: [
        HelpSection(
          title: 'Custom Metrics Schema',
          body: 'Configure scales, yes/no questions, and counters. Note: Changing metrics mid-study may misalign historical records.',
          icon: Icons.settings_rounded,
        ),
        HelpSection(
          title: 'Tracking Schedule',
          body: 'Define your custom check-in windows. The app automatically aligns local notifications to match these routines.',
          icon: Icons.schedule_rounded,
        ),
        HelpSection(
          title: 'Local First & Cloud Backup',
          body: 'Data is local-first. Synced backups to Supabase are completely anonymous and tied only to your 36-character Research ID.',
          icon: Icons.cloud_upload_rounded,
        ),
        HelpSection(
          title: 'Submit to Researcher',
          body: 'Once the study completes, use the export option to share your logs with the author: felix.zoeggeler@edu.fh-joanneum.at',
          icon: Icons.school_rounded,
        ),
      ],
    ),
    'permission_shield': HelpContent(
      title: 'Permission Shield Guide',
      subtitle: 'Platform integrations for passive sensing',
      sections: [
        HelpSection(
          title: 'Google Health Connect',
          body: 'Synchronizes step counts and sleep duration records. Requires the Health Connect app to be installed and permissions granted.',
          icon: Icons.directions_run_rounded,
        ),
        HelpSection(
          title: 'UsageStats (App Usage)',
          body: 'Used to compute daily screen time. In Android 13+, if grayed out: Settings -> Apps -> Covary -> (top-right menu) Allow restricted settings.',
          icon: Icons.bar_chart_rounded,
        ),
        HelpSection(
          title: 'iOS PWA Limitations',
          body: 'On iOS, the app runs as a Progressive Web App (PWA). Due to Apple browser sandbox rules, background steps and usage scans are disabled.',
          icon: Icons.apple_rounded,
        ),
        HelpSection(
          title: 'Manual Steps Alternative',
          body: 'If you prefer not to grant health permissions or are running on iOS/Web, enable "Step Count (Manual)" in Settings to log your steps manually.',
          icon: Icons.edit_note_rounded,
        ),
      ],
    ),
    'metrics': HelpContent(
      title: 'Tracked Metrics Guide',
      subtitle: 'Manage research variables & habits',
      sections: [
        HelpSection(
          title: 'Enable / Disable Habit Tracking',
          body: 'Toggle individual metrics on or off to customize your check-in questions. Disabled metrics will be hidden from check-ins.',
          icon: Icons.toggle_on_rounded,
        ),
        HelpSection(
          title: 'Adjust Configuration',
          body: 'Tap any metric tile to edit its name, description, emoji, or check-in requirements.',
          icon: Icons.edit_rounded,
        ),
        HelpSection(
          title: 'Bulk Actions & Reordering',
          body: '• Tap the top-right menu for bulk operations (enable/disable all, require all).\n• Drag the handle on the left of any tile to reorder how questions appear in check-ins.',
          icon: Icons.drag_indicator_rounded,
        ),
      ],
    ),
    'tracking_windows': HelpContent(
      title: 'Tracking Schedule Guide',
      subtitle: 'Configure your momentary windows',
      sections: [
        HelpSection(
          title: 'Time Window Anchors',
          body: 'Establish start and end hours for your check-ins (e.g. morning, evening). The app prompts you to check in during these times.',
          icon: Icons.more_time_rounded,
        ),
        HelpSection(
          title: 'Alert Reminders',
          body: 'Exiting a window without completing it triggers a "Missed Session" card. Toggle reminders per window to customize your notifications.',
          icon: Icons.notifications_active_rounded,
        ),
        HelpSection(
          title: 'Drag to Sort',
          body: 'Drag the handle on any window tile to organize the schedule in chronological order.',
          icon: Icons.drag_indicator_rounded,
        ),
      ],
    ),
    'meal_reminders': HelpContent(
      title: 'Meal Reminders Guide',
      subtitle: 'Manage food intake schedules',
      sections: [
        HelpSection(
          title: 'Independent Reminders',
          body: 'Schedule alerts for Breakfast, Lunch, and Dinner. These trigger action-button notifications to log nutrition easily.',
          icon: Icons.restaurant_rounded,
        ),
        HelpSection(
          title: 'Smart Cancelation',
          body: 'If you manually log a meal count on the Home screen, the remaining meal reminders for that day are automatically canceled to prevent annoying prompts.',
          icon: Icons.notifications_off_rounded,
        ),
      ],
    ),
    'app_category_manager': HelpContent(
      title: 'App Category Manager',
      subtitle: 'Classify packages for screen time analytics',
      sections: [
        HelpSection(
          title: 'App Classification',
          body: 'Assign installed app packages to research categories: Social Media (e.g. Instagram, Reddit) or Entertainment (e.g. Netflix, YouTube).',
          icon: Icons.category_rounded,
        ),
        HelpSection(
          title: 'Accurate Research Modeling',
          body: 'Correctly categorizing apps ensures usage stats and screen-time graphs represent your digital habits accurately.',
          icon: Icons.bar_chart_rounded,
        ),
      ],
    ),
    'raw_data': HelpContent(
      title: 'Detailed Records Explorer',
      subtitle: 'Inspect local SQLite database logs',
      sections: [
        HelpSection(
          title: 'Local Audit logs',
          body: 'Browse all saved event rows (Mood, steps, battery, settings changes) stored locally in the SQLite database.',
          icon: Icons.storage_rounded,
        ),
        HelpSection(
          title: 'Filters & Search',
          body: 'Use search inputs and category filters to audit specific timestamps, recorded latencies, or values.',
          icon: Icons.search_rounded,
        ),
        HelpSection(
          title: 'Local Deletion',
          body: 'Swipe or tap any record to delete it permanently from your device. Deleted logs cannot be recovered.',
          icon: Icons.delete_forever_rounded,
        ),
      ],
    ),
  };


  /// Directly displays the help bottom sheet for a given screen key
  static void showHelpBottomSheet(BuildContext context, String screenKey) {
    final content = _registry[screenKey];
    if (content == null) return;

    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.85,
        minChildSize: 0.4,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(CovaryDesignSystem.radiusXl)),
            border: Border.all(color: colorScheme.outlineVariant.withAlpha(80), width: 1.5),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: ListView(
              controller: scrollController,
              physics: const BouncingScrollPhysics(),
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant.withAlpha(120),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  content.title,
                  style: textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content.subtitle,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                Divider(color: colorScheme.outlineVariant.withAlpha(80)),
                const SizedBox(height: 16),
                ...content.sections.map((section) => Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withAlpha(40),
                          borderRadius: BorderRadius.circular(CovaryDesignSystem.radiusMd),
                          border: Border.all(color: colorScheme.primary.withAlpha(50)),
                        ),
                        child: Icon(
                          section.icon,
                          color: colorScheme.primary,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              section.title,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              section.body,
                              style: textTheme.bodyMedium?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      final url = Uri.parse('https://github.com/SneakyZippy/Covary/blob/main/TUTORIAL.md');
                      try {
                        if (await canLaunchUrl(url)) {
                          await launchUrl(url, mode: LaunchMode.externalApplication);
                        }
                      } catch (e) {
                        debugPrint('Could not launch tutorial URL: $e');
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text(
                      'View Full Tutorial on GitHub',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: colorScheme.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(100),
                        side: BorderSide(color: colorScheme.primary.withAlpha(80)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (!_registry.containsKey(screenKey)) {
      return const SizedBox.shrink();
    }

    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      color: iconColor ?? colorScheme.onSurfaceVariant,
      tooltip: 'Show Page Guide',
      onPressed: () => showHelpBottomSheet(context, screenKey),
    );
  }
}
