import 'package:flutter/material.dart';

/// Animated pulsing dot for connection/session status indicators.
/// When [pulse] is false the animation controller is never started,
/// saving CPU for offline/idle items in long lists.
class StatusDot extends StatefulWidget {
  final Color color;
  final bool pulse;
  final double size;

  const StatusDot({
    super.key,
    required this.color,
    this.pulse = false,
    this.size = 9,
  });

  @override
  State<StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<StatusDot> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _scale = Tween<double>(begin: 0.75, end: 1.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));

    if (widget.pulse) _ctrl.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(StatusDot old) {
    super.didUpdateWidget(old);
    if (widget.pulse != old.pulse) {
      if (widget.pulse) {
        _ctrl.repeat(reverse: true);
      } else {
        _ctrl.stop();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dot = Container(
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: widget.color,
        shape: BoxShape.circle,
        boxShadow: widget.pulse
            ? [
                BoxShadow(
                  color: widget.color.withValues(alpha: 0.65),
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
    );

    if (!widget.pulse) return dot;
    return ScaleTransition(scale: _scale, child: dot);
  }
}
