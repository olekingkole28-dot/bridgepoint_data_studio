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
      duration: const Duration(seconds: 24),
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

// Production background contract: a centered, dimensional black hole sits
// behind the application chrome while recognizable BridgePoint intelligence
// categories spiral inward and disappear at the event horizon. The scene is
// deliberately space-like rather than a generic dotted technology pattern.
class _BridgePointOrbitalDnaPainter extends CustomPainter {
  _BridgePointOrbitalDnaPainter({required this.progress});
  final double progress;

  static const cyan = Color(0xFF48E1FF);
  static const blue = Color(0xFF6C83FF);
  static const violet = Color(0xFF8B5CF6);
  static const gold = Color(0xFFFFC95E);
  static const red = Color(0xFFFF6B6B);
  static const green = Color(0xFF45E6A6);

  static const _intelIcons = <IconData>[
    Icons.home_rounded,
    Icons.roofing_rounded,
    Icons.ac_unit_rounded,
    Icons.filter_tilt_shift_rounded,
    Icons.rotate_right_rounded,
    Icons.local_fire_department_rounded,
    Icons.flood_rounded,
    Icons.water_drop_rounded,
    Icons.flash_on_rounded,
    Icons.description_rounded,
    Icons.assignment_rounded,
    Icons.construction_rounded,
    Icons.solar_power_rounded,
    Icons.shield_rounded,
    Icons.location_city_rounded,
    Icons.insights_rounded,
  ];

  static const _intelColors = <Color>[
    cyan,
    gold,
    Color(0xFF8DE8FF),
    violet,
    blue,
    red,
    Color(0xFF42BFFF),
    blue,
    gold,
    Color(0xFFFF78C6),
    Color(0xFFFF9557),
    gold,
    green,
    cyan,
    violet,
    green,
  ];

  double _clamp01(double value) => value.clamp(0.0, 1.0);

  void _drawMaterialIcon(
    Canvas canvas,
    IconData icon,
    Offset at,
    double size,
    Color color,
    double alpha,
  ) {
    if (alpha <= .005) return;
    final painter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          inherit: false,
          color: color.withValues(alpha: alpha),
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          shadows: [
            Shadow(
              color: color.withValues(alpha: alpha * .48),
              blurRadius: 8,
            ),
          ],
        ),
      ),
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final phase = progress * math.pi * 2;
    final shortest = size.shortestSide;
    final center = Offset(size.width * .5, size.height * .50);
    final horizon = math.max(92.0, shortest * .18);
    final pulse = .5 + .5 * math.sin(phase * 2.0);

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -.08),
          radius: 1.25,
          colors: [Color(0xFF081428), Color(0xFF020713), Color(0xFF000105)],
          stops: [0, .50, 1],
        ).createShader(rect),
    );

    // Natural star field: irregular size/brightness with occasional cross-star
    // twinkles. These are environmental stars, not a UI-dot pattern.
    for (var i = 0; i < 115; i++) {
      final sx = ((math.sin(i * 12.9898 + 1.7) * 43758.5453).abs() % 1) * size.width;
      final sy = ((math.sin(i * 8.233 + 4.1) * 24634.6345).abs() % 1) * size.height;
      final twinkle = .5 + .5 * math.sin(phase * (.18 + (i % 5) * .025) + i);
      final radius = i % 19 == 0 ? 1.35 : i % 7 == 0 ? .9 : .48;
      final alpha = .12 + twinkle * (i % 19 == 0 ? .34 : .14);
      final starPaint = Paint()..color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(Offset(sx, sy), radius, starPaint);
      if (i % 19 == 0) {
        final cross = Paint()
          ..color = Colors.white.withValues(alpha: alpha * .55)
          ..strokeWidth = .55;
        canvas.drawLine(Offset(sx - 3.4, sy), Offset(sx + 3.4, sy), cross);
        canvas.drawLine(Offset(sx, sy - 3.4), Offset(sx, sy + 3.4), cross);
      }
    }

    // Distant planets add depth without competing with the interface.
    final planet1 = Offset(size.width * .13, size.height * .18);
    final planet1Rect = Rect.fromCircle(center: planet1, radius: shortest * .055);
    canvas.drawCircle(
      planet1,
      shortest * .055,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.42, -.38),
          colors: [Color(0xFF7587B7), Color(0xFF27385D), Color(0xFF0A1020)],
          stops: [0, .48, 1],
        ).createShader(planet1Rect),
    );
    canvas.drawCircle(
      planet1,
      shortest * .055,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = blue.withValues(alpha: .12),
    );

    final planet2 = Offset(size.width * .86, size.height * .78);
    final planet2Rect = Rect.fromCircle(center: planet2, radius: shortest * .035);
    canvas.drawCircle(
      planet2,
      shortest * .035,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-.35, -.45),
          colors: [Color(0xFFC58A67), Color(0xFF633B42), Color(0xFF170C17)],
        ).createShader(planet2Rect),
    );

    // Broad gravitational lens around the hole.
    final glowRect = Rect.fromCircle(center: center, radius: horizon * 3.25);
    canvas.drawCircle(
      center,
      horizon * 3.25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.black.withValues(alpha: .99),
            Colors.black.withValues(alpha: .94),
            violet.withValues(alpha: .15 + pulse * .035),
            blue.withValues(alpha: .10),
            cyan.withValues(alpha: .035),
            Colors.transparent,
          ],
          stops: const [0, .25, .43, .58, .76, 1],
        ).createShader(glowRect),
    );

    // Thick dimensional accretion disk with front/back light arcs.
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-.18 + math.sin(phase * .18) * .018);
    for (var i = 0; i < 14; i++) {
      final orbit = Rect.fromCenter(
        center: Offset.zero,
        width: horizon * (3.45 + i * .085),
        height: horizon * (.70 + i * .022),
      );
      final start = .04 + phase * (.055 + i * .0013);
      final sweep = math.pi * (1.74 - (i % 4) * .055);
      final color = i % 5 == 0
          ? gold
          : i % 2 == 0
              ? cyan
              : violet;
      final alpha = .09 + i * .008 + pulse * .022;
      canvas.drawArc(
        orbit,
        start,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.0 + (i % 4) * .65
          ..color = color.withValues(alpha: alpha)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2.2 + (i % 4) * .8),
      );
    }
    canvas.restore();

    // Material icons representing the data BridgePoint ingests. Every icon
    // follows a shrinking spiral, fades as it reaches the rim, and resets so
    // the ingestion motion runs continuously.
    for (var i = 0; i < _intelIcons.length; i++) {
      final journey = (progress * 1.18 + i / _intelIcons.length) % 1.0;
      final eased = Curves.easeInCubic.transform(journey);
      final radius = horizon * (3.95 - eased * 3.18);
      final angle = i * .92 + journey * math.pi * 4.35 + phase * .08;
      final at = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius * .47,
      );
      final enter = _clamp01(journey / .10);
      final vanish = 1 - _clamp01((journey - .82) / .15);
      final alpha = .16 + .70 * enter * vanish;
      final iconSize = (14.0 + (i % 4) * 2.2) * (.96 - eased * .30);
      _drawMaterialIcon(
        canvas,
        _intelIcons[i],
        at,
        iconSize,
        _intelColors[i],
        alpha,
      );
    }

    // Bright gravitational rim and an opaque event horizon. The app's cards,
    // sheets and rails render after this painter, so they naturally cover it.
    canvas.drawCircle(
      center,
      horizon * (1.075 + pulse * .018),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.1
        ..color = cyan.withValues(alpha: .20 + pulse * .08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );
    canvas.drawCircle(
      center,
      horizon * (.79 + pulse * .010),
      Paint()..color = Colors.black.withValues(alpha: .998),
    );
    canvas.drawCircle(
      center,
      horizon * .805,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = violet.withValues(alpha: .11 + pulse * .025),
    );
  }

  @override
  bool shouldRepaint(covariant _BridgePointOrbitalDnaPainter oldDelegate) =>
      oldDelegate.progress != progress;
}
