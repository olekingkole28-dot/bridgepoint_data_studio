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
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                Text(
                  'INTELLIGENCE',
                  style: TextStyle(
                    color: Color(0xFF48E1FF),
                    fontSize: 12.5,
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
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disabled = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disabled && _controller.isAnimating) {
      _controller
        ..stop()
        ..value = .18;
    } else if (!disabled && !_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _controller,
        child: widget.child,
        builder: (context, child) => CustomPaint(
          painter: _BridgePointDnaNetworkPainter(progress: _controller.value),
          child: Padding(
            padding: widget.padding,
            child: child,
          ),
        ),
      );
}

class _BridgePointDnaNetworkPainter extends CustomPainter {
  const _BridgePointDnaNetworkPainter({required this.progress});
  final double progress;

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF6C83FF);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = progress * math.pi * 2;

    _drawGlow(canvas, size, .18, .14, _cyan);
    _drawGlow(canvas, size, .82, .22, _blue);
    _drawGlow(canvas, size, .58, .82, const Color(0xFF8B5CF6));

    // Animated double helix — intentionally subtle so the data remains primary.
    for (final side in const <double>[.12, .88]) {
      final centerX = size.width * side;
      final amplitude = math.min(44.0, math.max(18.0, size.width * .042));
      Offset? previousA;
      Offset? previousB;
      for (var i = 0; i <= 58; i++) {
        final t = i / 58.0;
        final y = t * size.height;
        final wave = math.sin(t * math.pi * 8 + phase + side * math.pi);
        final a = Offset(centerX + wave * amplitude, y);
        final b = Offset(centerX - wave * amplitude, y);

        if (previousA != null && previousB != null) {
          canvas.drawLine(
            previousA,
            a,
            Paint()
              ..strokeWidth = 1.2
              ..color = _cyan.withValues(alpha: .10),
          );
          canvas.drawLine(
            previousB,
            b,
            Paint()
              ..strokeWidth = 1.2
              ..color = _blue.withValues(alpha: .09),
          );
        }

        if (i % 4 == 0) {
          canvas.drawLine(
            a,
            b,
            Paint()
              ..strokeWidth = .8
              ..color = Colors.white.withValues(alpha: .045),
          );
          canvas.drawCircle(
            a,
            2.2,
            Paint()..color = _cyan.withValues(alpha: .24),
          );
          canvas.drawCircle(
            b,
            2.2,
            Paint()..color = _blue.withValues(alpha: .22),
          );
        }

        previousA = a;
        previousB = b;
      }
    }

    // Secondary property-intelligence network.
    final nodes = <Offset>[];
    for (var row = 0; row < 4; row++) {
      for (var col = 0; col < 6; col++) {
        final baseX = (col + .55) / 6.1;
        final baseY = (row + .55) / 4.2;
        final driftX = math.sin(phase + row * .7 + col * .43) * .012;
        final driftY = math.cos(phase * .8 + col * .55) * .010;
        nodes.add(Offset(
          (baseX + driftX) * size.width,
          (baseY + driftY) * size.height,
        ));
      }
    }

    final maxLink = size.shortestSide * .24;
    for (var i = 0; i < nodes.length; i++) {
      for (var j = i + 1; j < nodes.length; j++) {
        final distance = (nodes[i] - nodes[j]).distance;
        if (distance > maxLink) continue;
        final strength = (1 - distance / maxLink) * .06;
        canvas.drawLine(
          nodes[i],
          nodes[j],
          Paint()
            ..strokeWidth = .8
            ..color = _blue.withValues(alpha: strength),
        );
      }
      final pulse = (math.sin(phase * 1.5 + i * .7) + 1) / 2;
      canvas.drawCircle(
        nodes[i],
        1.6 + pulse * .9,
        Paint()..color = _cyan.withValues(alpha: .13 + pulse * .12),
      );
    }

    final sweepRect = Rect.fromLTWH(
      -size.width + progress * size.width * 2.5,
      0,
      size.width * .8,
      size.height,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent,
            _cyan.withValues(alpha: .028),
            Colors.transparent,
          ],
        ).createShader(sweepRect),
    );
  }

  void _drawGlow(
    Canvas canvas,
    Size size,
    double x,
    double y,
    Color color,
  ) {
    final radius = size.shortestSide * .34;
    final center = Offset(size.width * x, size.height * y);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: .055), Colors.transparent],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(covariant _BridgePointDnaNetworkPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
