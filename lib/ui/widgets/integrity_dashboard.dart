import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// =============================================================================
// Integrity Dashboard
// =============================================================================

/// Shows the status of the three data sources: Notifications, Health, Usage.
class IntegrityDashboard extends StatelessWidget {
  final bool healthActive;
  final bool usageActive;
  final bool notificationsActive;

  const IntegrityDashboard({
    super.key,
    required this.healthActive,
    required this.usageActive,
    required this.notificationsActive,
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
            IntegrityItem(
              label: 'Notifications',
              isActive: notificationsActive,
              icon: Icons.notifications_active_outlined,
            ),
            const SizedBox(height: 8),
            IntegrityItem(
              label: 'Health Data',
              isActive: healthActive,
              icon: Icons.favorite_outline_rounded,
              isSupported: !kIsWeb,
            ),
            const SizedBox(height: 8),
            IntegrityItem(
              label: 'App Usage',
              isActive: usageActive,
              icon: Icons.app_registration_rounded,
              isSupported: !kIsWeb,
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Integrity Item Row
// =============================================================================

/// A single row inside [IntegrityDashboard] showing one data source's status.
class IntegrityItem extends StatelessWidget {
  final String label;
  final bool isActive;
  final IconData icon;
  final bool isSupported;

  const IntegrityItem({
    super.key,
    required this.label,
    required this.isActive,
    required this.icon,
    this.isSupported = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Harmonious colors tailored to show active, inactive/error, and unsupported/disabled states
    final Color itemColor = !isSupported
        ? colorScheme.onSurfaceVariant.withAlpha(100)
        : (isActive ? colorScheme.primary : colorScheme.error);

    final Color labelColor = !isSupported
        ? colorScheme.onSurfaceVariant.withAlpha(100)
        : (isActive ? colorScheme.onSurface : colorScheme.error);

    final IconData statusIcon = !isSupported
        ? Icons.remove_circle_outline_rounded
        : (isActive ? Icons.check_circle_rounded : Icons.warning_rounded);

    final Color statusIconColor = !isSupported
        ? colorScheme.outlineVariant
        : (isActive ? Colors.green : colorScheme.error);

    return Row(
      children: [
        Icon(icon, size: 16, color: itemColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: textTheme.bodySmall?.copyWith(
              fontWeight: (isSupported && isActive) ? FontWeight.w500 : FontWeight.normal,
              color: labelColor,
            ),
          ),
        ),
        if (!isSupported)
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: Text(
              'Unsupported',
              style: textTheme.bodySmall?.copyWith(
                fontSize: 10,
                color: colorScheme.onSurfaceVariant.withAlpha(100),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        Icon(
          statusIcon,
          size: 14,
          color: statusIconColor,
        ),
      ],
    );
  }
}
