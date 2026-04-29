import 'package:flutter/material.dart';
import '../../data/models/icon_mapping.dart';

class MetricIcon extends StatelessWidget {
  final String? iconName;
  final double size;
  final Color? color;

  const MetricIcon({
    super.key,
    this.iconName,
    this.size = 24,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (iconName == null || iconName!.isEmpty) {
      return Icon(Icons.help_outline, size: size, color: color);
    }

    final iconData = getIconData(iconName!);
    
    if (iconData != null) {
      return Icon(
        iconData,
        size: size,
        color: color ?? Theme.of(context).colorScheme.primary,
      );
    }

    // Fallback: Check if it's an emoji
    return Text(
      iconName!,
      style: TextStyle(fontSize: size),
    );
  }
}
