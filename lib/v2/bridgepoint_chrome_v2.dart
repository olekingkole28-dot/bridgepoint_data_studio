import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class BridgePointMarkV2 extends StatelessWidget {
  const BridgePointMarkV2({super.key, this.size = 38});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: SvgPicture.asset(
          'assets/brand/bridgepoint-mark-v80.svg',
          fit: BoxFit.contain,
        ),
      );
}

class BridgePointBrandLockupV2 extends StatelessWidget {
  const BridgePointBrandLockupV2({super.key, this.compact = false});
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          BridgePointMarkV2(size: compact ? 34 : 42),
          if (!compact) ...[
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'BRIDGEPOINT',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'INTELLIGENCE',
                  style: TextStyle(
                    color: Color(0xFF35D2E8),
                    fontSize: 8,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.8,
                  ),
                ),
              ],
            ),
          ],
        ],
      );
}

class BridgePointMotionBackgroundV2 extends StatefulWidget {
  const BridgePointMotionBackgroundV2({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  State<BridgePointMotionBackgroundV2> createState() =>
      _BridgePointMotionBackgroundV2State();
}

class _BridgePointMotionBackgroundV2State
    extends State<BridgePointMotionBackgroundV2>
    with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 22),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable && controller.isAnimating) {
      controller.stop();
      controller.value = .15;
    } else if (!disable && !controller.isAnimating) {
      controller.repeat();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, child) => CustomPaint(
          painter: _BridgePointNetworkPainter(progress: controller.value),
          child: Padding(padding: widget.padding, child: child),
        ),
        child: widget.child,
      );
}

class _BridgePointNetworkPainter extends CustomPainter {
  _BridgePointNetworkPainter({required this.progress});
  final double progress;

  static const _nodes = <Offset>[
    Offset(.05, .13),
    Offset(.16, .29),
    Offset(.31, .09),
    Offset(.46, .21),
    Offset(.63, .08),
    Offset(.82, .19),
    Offset(.95, .07),
    Offset(.09, .58),
    Offset(.25, .46),
    Offset(.41, .61),
    Offset(.58, .44),
    Offset(.73, .58),
    Offset(.91, .42),
    Offset(.18, .86),
    Offset(.38, .77),
    Offset(.58, .89),
    Offset(.79, .79),
    Offset(.96, .91),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final phase = progress * math.pi * 2;
    final points = <Offset>[];
    for (var i = 0; i < _nodes.length; i++) {
      final base = _nodes[i];
      final dx = math.sin(phase + i * .71) * .018;
      final dy = math.cos(phase * .83 + i * .49) * .014;
      points.add(Offset((base.dx + dx) * size.width, (base.dy + dy) * size.height));
    }

    final linePaint = Paint()
      ..strokeWidth = 1
      ..color = const Color(0xFF35D2E8).withValues(alpha: .055);
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        final distance = (points[i] - points[j]).distance;
        if (distance < size.shortestSide * .28) {
          final alpha = (1 - distance / (size.shortestSide * .28)) * .09;
          linePaint.color = const Color(0xFF4F7CFF).withValues(alpha: alpha);
          canvas.drawLine(points[i], points[j], linePaint);
        }
      }
    }

    for (var i = 0; i < points.length; i++) {
      final pulse = (math.sin(phase * 1.6 + i) + 1) / 2;
      final glow = Paint()
        ..color = (i % 3 == 0 ? const Color(0xFF35D2E8) : const Color(0xFF4F7CFF))
            .withValues(alpha: .035 + pulse * .035);
      canvas.drawCircle(points[i], 11 + pulse * 7, glow);
      final dot = Paint()
        ..color = (i % 3 == 0 ? const Color(0xFF35D2E8) : const Color(0xFF4F7CFF))
            .withValues(alpha: .18 + pulse * .18);
      canvas.drawCircle(points[i], 1.8 + pulse, dot);
    }

    final sweep = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          const Color(0xFF35D2E8).withValues(alpha: .035),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromLTWH(
          -size.width + progress * size.width * 2.5,
          0,
          size.width * .8,
          size.height,
        ),
      );
    canvas.drawRect(Offset.zero & size, sweep);
  }

  @override
  bool shouldRepaint(covariant _BridgePointNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
