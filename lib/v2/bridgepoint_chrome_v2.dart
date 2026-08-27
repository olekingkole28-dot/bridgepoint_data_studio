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
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable && controller.isAnimating) {
      controller.stop();
      controller.value = .18;
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
          painter: _BridgePointDnaVortexPainter(progress: controller.value),
          child: Padding(padding: widget.padding, child: child),
        ),
        child: widget.child,
      );
}

class _BridgePointDnaVortexPainter extends CustomPainter {
  _BridgePointDnaVortexPainter({required this.progress});
  final double progress;

  static const _cyan = Color(0xFF48E1FF);
  static const _blue = Color(0xFF526CFF);
  static const _violet = Color(0xFF8B5CF6);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final phase = progress * math.pi * 2;
    final rect = Offset.zero & size;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF02060D), Color(0xFF06101C), Color(0xFF040713)],
        ).createShader(rect),
    );

    _drawVortex(
      canvas,
      size,
      center: Offset(size.width * (.78 + math.sin(phase * .33) * .025), size.height * (.20 + math.cos(phase * .29) * .02)),
      radius: size.shortestSide * .46,
      phase: phase,
      clockwise: true,
    );
    _drawVortex(
      canvas,
      size,
      center: Offset(size.width * (.23 + math.cos(phase * .27) * .02), size.height * (.78 + math.sin(phase * .31) * .018)),
      radius: size.shortestSide * .34,
      phase: -phase * .72,
      clockwise: false,
      opacity: .62,
    );

    _drawDna(canvas, size, phase);
    _drawFineStars(canvas, size, phase);
  }

  void _drawVortex(
    Canvas canvas,
    Size size, {
    required Offset center,
    required double radius,
    required double phase,
    required bool clockwise,
    double opacity = 1,
  }) {
    final dir = clockwise ? 1.0 : -1.0;
    final haloRect = Rect.fromCircle(center: center, radius: radius * 1.18);
    canvas.drawCircle(
      center,
      radius * 1.18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: .78 * opacity),
            const Color(0xFF050916).withValues(alpha: .72 * opacity),
            _blue.withValues(alpha: .055 * opacity),
            Colors.transparent,
          ],
          stops: const [0, .20, .63, 1],
        ).createShader(haloRect),
    );

    for (var ring = 0; ring < 14; ring++) {
      final t = ring / 13;
      final rx = radius * (.18 + t * .92);
      final ry = rx * (.32 + t * .12);
      final ringRect = Rect.fromCenter(center: center, width: rx * 2, height: ry * 2);
      final start = phase * dir * (.35 + t * .55) + ring * .73;
      final sweep = math.pi * (1.15 + .5 * math.sin(phase + ring));
      final color = ring % 3 == 0 ? _cyan : ring % 3 == 1 ? _blue : _violet;
      canvas.save();
      canvas.translate(center.dx, center.dy);
      canvas.rotate(dir * (.20 + .08 * math.sin(phase * .4)));
      canvas.translate(-center.dx, -center.dy);
      canvas.drawArc(
        ringRect,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .7 + (1 - t) * .7
          ..color = color.withValues(alpha: (.025 + (1 - t) * .035) * opacity),
      );
      canvas.restore();
    }

    final coreRect = Rect.fromCircle(center: center, radius: radius * .18);
    canvas.drawCircle(
      center,
      radius * .18,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: .98),
            Colors.black.withValues(alpha: .96),
            _cyan.withValues(alpha: .11 * opacity),
            Colors.transparent,
          ],
          stops: const [0, .58, .82, 1],
        ).createShader(coreRect),
    );
  }

  void _drawDna(Canvas canvas, Size size, double phase) {
    final baseY = size.height * .50;
    final amplitude = math.min(44.0, size.height * .055);
    final span = size.width;
    final a = Path();
    final b = Path();
    const steps = 90;

    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      final x = t * span;
      final wave = math.sin(t * math.pi * 5.5 + phase * .75);
      final drift = math.sin(t * math.pi * 1.2 - phase * .22) * 18;
      final y1 = baseY + drift + wave * amplitude;
      final y2 = baseY + drift - wave * amplitude;
      if (i == 0) {
        a.moveTo(x, y1);
        b.moveTo(x, y2);
      } else {
        a.lineTo(x, y1);
        b.lineTo(x, y2);
      }
      if (i % 6 == 0) {
        canvas.drawLine(
          Offset(x, y1),
          Offset(x, y2),
          Paint()
            ..strokeWidth = .75
            ..color = _violet.withValues(alpha: .045),
        );
      }
    }

    canvas.drawPath(
      a,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _cyan.withValues(alpha: .075),
    );
    canvas.drawPath(
      b,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color = _blue.withValues(alpha: .07),
    );
  }

  void _drawFineStars(Canvas canvas, Size size, double phase) {
    for (var i = 0; i < 34; i++) {
      final x = ((i * 73) % 101) / 101 * size.width;
      final y = ((i * 47 + 19) % 97) / 97 * size.height;
      final pulse = (math.sin(phase * .8 + i * 1.71) + 1) / 2;
      canvas.drawCircle(
        Offset(x, y),
        .45 + pulse * .65,
        Paint()..color = Colors.white.withValues(alpha: .025 + pulse * .035),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BridgePointDnaVortexPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
