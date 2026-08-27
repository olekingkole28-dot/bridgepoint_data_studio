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
        child: SvgPicture.asset('assets/brand/bridgepoint-mark-v80.svg', fit: BoxFit.contain),
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
            const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('BRIDGEPOINT', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
              Text('INTELLIGENCE', style: TextStyle(color: Color(0xFF48E1FF), fontSize: 12.5, fontWeight: FontWeight.w900, letterSpacing: 1.8)),
            ]),
          ],
        ],
      );
}

class BridgePointMotionBackgroundV2 extends StatefulWidget {
  const BridgePointMotionBackgroundV2({super.key, required this.child, this.padding = EdgeInsets.zero});
  final Widget child;
  final EdgeInsets padding;

  @override
  State<BridgePointMotionBackgroundV2> createState() => _BridgePointMotionBackgroundV2State();
}

class _BridgePointMotionBackgroundV2State extends State<BridgePointMotionBackgroundV2> with SingleTickerProviderStateMixin {
  late final AnimationController controller;

  @override
  void initState() {
    super.initState();
    controller = AnimationController(vsync: this, duration: const Duration(seconds: 32))..repeat();
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
          painter: _BridgePointOrbitalDnaPainter(progress: controller.value),
          child: Padding(padding: widget.padding, child: child),
        ),
        child: widget.child,
      );
}

class _BridgePointOrbitalDnaPainter extends CustomPainter {
  _BridgePointOrbitalDnaPainter({required this.progress});
  final double progress;

  static const cyan = Color(0xFF48E1FF);
  static const blue = Color(0xFF6C83FF);
  static const violet = Color(0xFF8B5CF6);
  static const gold = Color(0xFFFFC95E);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;
    final center = Offset(size.width * .67, size.height * .36);
    final shortest = size.shortestSide;

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.34, -.22),
          radius: 1.22,
          colors: [Color(0xFF0A1830), Color(0xFF050C18), Color(0xFF02060D)],
          stops: [0, .48, 1],
        ).createShader(rect),
    );

    final depthRect = Rect.fromCircle(center: center, radius: shortest * .34);
    canvas.drawCircle(
      center,
      shortest * .34,
      Paint()
        ..shader = RadialGradient(
          colors: [const Color(0xFF000000).withValues(alpha: .94), violet.withValues(alpha: .09), blue.withValues(alpha: .035), Colors.transparent],
          stops: const [0, .28, .62, 1],
        ).createShader(depthRect),
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(phase * .16);
    for (var i = 0; i < 5; i++) {
      final scale = .62 + i * .17;
      final orbit = Rect.fromCenter(center: Offset.zero, width: shortest * scale * 1.7, height: shortest * scale * .62);
      canvas.rotate(.18 + i * .07);
      canvas.drawOval(orbit, Paint()..style = PaintingStyle.stroke..strokeWidth = i == 0 ? 1.4 : .8..color = (i.isEven ? cyan : violet).withValues(alpha: .035 + i * .006));
    }
    canvas.restore();

    for (var i = 0; i < 18; i++) {
      final a = phase * (.14 + (i % 4) * .018) + i * .83;
      final rx = shortest * (.18 + (i % 6) * .033);
      final ry = rx * (.38 + (i % 3) * .07);
      final p = Offset(center.dx + math.cos(a) * rx, center.dy + math.sin(a) * ry);
      final color = i % 5 == 0 ? gold : i.isEven ? cyan : blue;
      final pulse = .5 + .5 * math.sin(phase * 1.3 + i * .7);
      canvas.drawCircle(p, 7 + pulse * 5, Paint()..color = color.withValues(alpha: .018 + pulse * .018));
      canvas.drawCircle(p, 1.1 + pulse * .45, Paint()..color = color.withValues(alpha: .24 + pulse * .16));
    }

    final dnaA = Path();
    final dnaB = Path();
    final pointsA = <Offset>[];
    final pointsB = <Offset>[];
    const steps = 38;
    final amplitude = math.min(size.height * .05, shortest * .07);
    for (var i = 0; i < steps; i++) {
      final t = i / (steps - 1);
      final x = size.width * (.02 + .92 * t);
      final axisY = size.height * (.82 - .55 * t);
      final wave = math.sin(t * math.pi * 7 + phase * .72) * amplitude;
      final a = Offset(x, axisY + wave);
      final b = Offset(x, axisY - wave);
      pointsA.add(a);
      pointsB.add(b);
      if (i == 0) {
        dnaA.moveTo(a.dx, a.dy);
        dnaB.moveTo(b.dx, b.dy);
      } else {
        dnaA.lineTo(a.dx, a.dy);
        dnaB.lineTo(b.dx, b.dy);
      }
    }
    final dnaPaint = Paint()..strokeWidth = .9..strokeCap = StrokeCap.round;
    canvas.drawPath(dnaA, dnaPaint..color = cyan.withValues(alpha: .075));
    canvas.drawPath(dnaB, dnaPaint..color = blue.withValues(alpha: .065));
    for (var i = 0; i < steps; i += 3) {
      final alpha = .035 + .025 * ((math.sin(phase + i) + 1) / 2);
      canvas.drawLine(pointsA[i], pointsB[i], Paint()..color = violet.withValues(alpha: alpha)..strokeWidth = .7);
      canvas.drawCircle(pointsA[i], 1.6, Paint()..color = cyan.withValues(alpha: .24));
      canvas.drawCircle(pointsB[i], 1.6, Paint()..color = blue.withValues(alpha: .22));
    }

    final glow = Rect.fromCircle(center: Offset(size.width * .08, size.height * .14), radius: shortest * .42);
    canvas.drawCircle(glow.center, glow.width / 2, Paint()..shader = RadialGradient(colors: [cyan.withValues(alpha: .055), Colors.transparent]).createShader(glow));
  }

  @override
  bool shouldRepaint(covariant _BridgePointOrbitalDnaPainter oldDelegate) => oldDelegate.progress != progress;
}
