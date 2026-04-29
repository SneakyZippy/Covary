import 'package:flutter/material.dart';

// =============================================================================
// Compact Menu Tile
// =============================================================================

/// A standard list-tile card used for navigation items on Insights/Settings screens.
class CompactMenuTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const CompactMenuTile({
    super.key,
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

// =============================================================================
// Action Card
// =============================================================================

/// A list-tile card for actions that open external flows (export, import, etc.).
class ActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
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

// =============================================================================
// Status Card
// =============================================================================

/// A read-only card showing a labelled status badge (e.g. "ACTIVE").
class StatusCard extends StatelessWidget {
  final String title;
  final String status;
  final IconData icon;

  const StatusCard({
    super.key,
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
