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
      duration: const Duration(seconds: 28),
    )..repeat();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable && controller.isAnimating) {
      controller.stop();
      controller.value = .22;
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

// Kept under the original class name because the production release audit uses
// this symbol as the Clean V2 animated-atmosphere contract.
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
    final shortest = size.shortestSide;
    final compact = size.width < 760;
    final center = Offset(
      size.width * (compact ? .73 : .77),
      size.height * (compact ? .34 : .31),
    );
    final horizon = math.max(62.0, shortest * .115);
    final pulse = .5 + .5 * math.sin(phase * 2.0);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(.44, -.28),
          radius: 1.35,
          colors: [Color(0xFF0B1930), Color(0xFF040A14), Color(0xFF010308)],
          stops: [0, .46, 1],
        ).createShader(rect),
    );

    // Sparse depth stars. Their coordinates are deterministic so the scene
    // stays calm instead of looking like visual noise.
    for (var i = 0; i < 80; i++) {
      final sx = ((math.sin(i * 12.9898) * 43758.5453).abs() % 1) * size.width;
      final sy = ((math.sin(i * 8.233 + 2.7) * 24634.6345).abs() % 1) * size.height;
      final twinkle = .35 + .65 * (.5 + .5 * math.sin(phase * .75 + i));
      canvas.drawCircle(
        Offset(sx, sy),
        i % 11 == 0 ? 1.25 : .65,
        Paint()..color = Colors.white.withValues(alpha: .035 + twinkle * .055),
      );
    }

    // Gravitational glow behind the event horizon.
    final glowRect = Rect.fromCircle(center: center, radius: horizon * 3.15);
    canvas.drawCircle(
      center,
      horizon * 3.15,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: .97),
            Colors.black.withValues(alpha: .90),
            violet.withValues(alpha: .10 + pulse * .025),
            blue.withValues(alpha: .055),
            cyan.withValues(alpha: .018),
            Colors.transparent,
          ],
          stops: const [0, .28, .47, .64, .79, 1],
        ).createShader(glowRect),
    );

    // Accretion disk: several offset elliptical arcs make the disk look
    // dimensional while keeping the motion slow enough for dashboards.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.15 + math.sin(phase * .22) * .018);
    for (var i = 0; i < 10; i++) {
      final grow = i * .07;
      final orbit = Rect.fromCenter(
        center: Offset.zero,
        width: horizon * (3.25 + grow),
        height: horizon * (.63 + i * .018),
      );
      final start = .08 + phase * (.055 + i * .0018);
      final sweep = math.pi * (1.72 - (i % 3) * .08);
      final color = i % 4 == 0
          ? gold
          : i.isEven
              ? cyan
              : violet;
      final alpha = .075 + i * .009 + pulse * .018;
      canvas.drawArc(
        orbit,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = .9 + (i % 3) * .55
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.5 + (i % 3)),
      );
    }
    canvas.restore();

    // Bright lensing rim.
    canvas.drawCircle(
      center,
      horizon * (1.03 + pulse * .018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.25
        ..color = cyan.withValues(alpha: .11 + pulse * .055)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Event horizon — deliberately near-black, with a tiny pulse rather than
    // a distracting size animation.
    canvas.drawCircle(
      center,
      horizon * (.78 + pulse * .012),
      Paint()..color = Colors.black.withValues(alpha: .985),
    );

    // Orbiting particles create obvious motion without turning the entire app
    // into a video background.
    for (var i = 0; i < 26; i++) {
      final angle = phase * (.27 + (i % 5) * .018) + i * .73;
      final radius = horizon * (1.42 + (i % 8) * .16);
      final p = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * .31,
      );
      final color = i % 5 == 0
          ? gold
          : i.isEven
              ? cyan
              : violet;
      canvas.drawCircle(
        p,
        1.15 + (i % 3) * .48,
        Paint()
          ..color = color.withValues(alpha: .13 + pulse * .09)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }

    // Very faint lower-left energy filament keeps the visual identity present
    // when the black hole is partially covered by a card or rail.
    final filament = Path();
    const steps = 44;
    for (var i = 0; i < steps; i++) {
      final x = size.width * (.02 + .72 * i / (steps - 1));
      final axis = size.height * (.90 - .30 * i / (steps - 1));
      final y = axis + math.sin(i * .56 + phase * .42) * shortest * .012;
      if (i == 0) {
        filament.moveTo(x, y);
      } else {
        filament.lineTo(x, y);
      }
    }
    canvas.drawPath(
      filament,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .75
        ..color = cyan.withValues(alpha: .045)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
  }

  @override
  bool shouldRepaint(covariant _BridgePointOrbitalDnaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
