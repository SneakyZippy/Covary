import 'package:flutter/material.dart';

/// A widget that animates its child into view with a fade-in and slide-up transition.
/// Multiple items can specify increasing [delay] durations to achieve a staggered effect.
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final Duration delay;
  final Duration duration;
  final Offset offset;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 500),
    this.offset = const Offset(0.0, 0.12), // Percentage offset for translation (dy = 0.12 means slide up 12% of height/100px)
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> {
  bool _shouldShow = false;

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _shouldShow = true;
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) {
          setState(() {
            _shouldShow = true;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow) {
      // Invisible placeholder to maintain layout layout space before animate triggers
      return Opacity(
        opacity: 0.0,
        child: widget.child,
      );
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: widget.duration,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              widget.offset.dx * (1.0 - value) * 100.0,
              widget.offset.dy * (1.0 - value) * 100.0,
            ),
            child: child,
          ),
        );
      },
      child: widget.child,
    );
  }
}
