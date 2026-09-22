import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class DashboardMarquee extends StatefulWidget {
  final List<String> messages;

  const DashboardMarquee({
    super.key,
    required this.messages,
  });

  @override
  State<DashboardMarquee> createState() => _DashboardMarqueeState();
}

class _DashboardMarqueeState extends State<DashboardMarquee> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  static const double _gap = 64.0;
  static const double _speedPxPerSecond = 70.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 12))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.messages.join('     •     ');
    final textStyle = const TextStyle(color: Colors.white, fontSize: 13);

    return LayoutBuilder(builder: (context, constraints) {
      final maxWidth = constraints.maxWidth;
      final tp = TextPainter(
        text: TextSpan(text: text, style: textStyle),
        textDirection: ui.TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final textWidth = tp.width + 16.0;

      // If it fits, show static single-line text
      if (textWidth <= maxWidth - 24) {
        if (_controller.isAnimating) _controller.stop();
        return Container(
          color: Colors.transparent,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(text, style: textStyle, maxLines: 1, overflow: TextOverflow.ellipsis, softWrap: false),
        );
      }

      // Animate: compute total distance and duration
      final totalDistance = textWidth + _gap;
      final durationSeconds = (totalDistance / _speedPxPerSecond).clamp(6.0, 40.0);
      _controller.duration = Duration(milliseconds: (durationSeconds * 1000).toInt());
      if (!_controller.isAnimating) _controller.repeat();

      return ClipRect(
        child: Container(
          color: Colors.transparent,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final dx = -_controller.value * totalDistance;
              return Transform.translate(
                offset: Offset(dx, 0),
                child: OverflowBox(
                  maxWidth: double.infinity,
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      const SizedBox(width: 8),
                      SizedBox(width: textWidth, child: Text(text, style: textStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.visible)),
                      const SizedBox(width: _gap),
                      SizedBox(width: textWidth, child: Text(text, style: textStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.visible)),
                      const SizedBox(width: 8),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
    });
  }
}
