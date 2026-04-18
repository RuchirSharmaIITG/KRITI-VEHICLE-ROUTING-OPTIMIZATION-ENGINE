import 'dart:math';
import 'package:flutter/material.dart';
import '../config/constants.dart';

/// Animated globe background for the landing page
/// Mirrors CyberpunkGlobe.js - shows a rotating dark globe with animated taxi dots
/// Since Flutter doesn't have react-globe.gl, we create a custom 2D globe with
/// animated route arcs and moving dots (same visual effect on mobile)
class AnimatedGlobeBackground extends StatefulWidget {
  const AnimatedGlobeBackground({super.key});

  @override
  State<AnimatedGlobeBackground> createState() => _AnimatedGlobeBackgroundState();
}

class _AnimatedGlobeBackgroundState extends State<AnimatedGlobeBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_GlobeRoute> _routes;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 60),
      vsync: this,
    )..repeat();

    // Generate random routes (same as generateRandomRoutes in CyberpunkGlobe.js)
    _routes = List.generate(15, (i) {
      return _GlobeRoute(
        startAngle: _random.nextDouble() * 2 * pi,
        endAngle: _random.nextDouble() * 2 * pi,
        startRadius: 0.3 + _random.nextDouble() * 0.4,
        endRadius: 0.3 + _random.nextDouble() * 0.4,
        color: routeColorsGlobe[_random.nextInt(routeColorsGlobe.length)],
        progress: _random.nextDouble(),
        speed: 0.0008 + _random.nextDouble() * 0.001,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        // Update route progress
        for (final route in _routes) {
          route.progress += route.speed;
          if (route.progress >= 1.0) route.progress = 0.0;
        }
        return CustomPaint(
          painter: _GlobePainter(
            routes: _routes,
            rotation: _controller.value * 2 * pi,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _GlobeRoute {
  final double startAngle;
  final double endAngle;
  final double startRadius;
  final double endRadius;
  final Color color;
  double progress;
  final double speed;

  _GlobeRoute({
    required this.startAngle,
    required this.endAngle,
    required this.startRadius,
    required this.endRadius,
    required this.color,
    required this.progress,
    required this.speed,
  });
}

class _GlobePainter extends CustomPainter {
  final List<_GlobeRoute> routes;
  final double rotation;

  _GlobePainter({required this.routes, required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) * 0.35;

    // Dark background
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = VeloraColors.background,
    );

    // Globe circle with subtle glow
    final glowPaint = Paint()
      ..color = VeloraColors.blue.withValues(alpha: 0.05)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 40);
    canvas.drawCircle(center, radius + 20, glowPaint);

    // Globe surface
    final globePaint = Paint()
      ..shader = const RadialGradient(
        center: Alignment(-0.3, -0.3),
        radius: 1.0,
        colors: [
          Color(0xFF1E293B),
          Color(0xFF0F172A),
          Color(0xFF020617),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, globePaint);

    // Atmosphere ring
    final atmPaint = Paint()
      ..color = VeloraColors.blue.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, radius + 2, atmPaint);

    // Grid lines (latitude/longitude)
    final gridPaint = Paint()
      ..color = VeloraColors.cyan.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 1; i <= 5; i++) {
      canvas.drawCircle(center, radius * i / 5, gridPaint);
    }
    for (int i = 0; i < 12; i++) {
      final angle = rotation + (i * pi / 6);
      canvas.drawLine(
        center,
        center + Offset(cos(angle) * radius, sin(angle) * radius),
        gridPaint,
      );
    }

    // Draw route arcs
    for (final route in routes) {
      final startAngle = route.startAngle + rotation * 0.3;
      final endAngle = route.endAngle + rotation * 0.3;

      final p1 = center + Offset(
        cos(startAngle) * radius * route.startRadius,
        sin(startAngle) * radius * route.startRadius,
      );
      final p2 = center + Offset(
        cos(endAngle) * radius * route.endRadius,
        sin(endAngle) * radius * route.endRadius,
      );

      // Route arc
      final arcPaint = Paint()
        ..color = route.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..quadraticBezierTo(
          center.dx + (p1.dx - center.dx + p2.dx - center.dx) * 0.3,
          center.dy + (p1.dy - center.dy + p2.dy - center.dy) * 0.3 - 30,
          p2.dx,
          p2.dy,
        );
      canvas.drawPath(path, arcPaint);

      // Moving dot (taxi) along the arc
      final t = route.progress;
      final dotX = (1 - t) * (1 - t) * p1.dx + 2 * (1 - t) * t * (center.dx + (p1.dx - center.dx + p2.dx - center.dx) * 0.3) + t * t * p2.dx;
      final dotY = (1 - t) * (1 - t) * p1.dy + 2 * (1 - t) * t * (center.dy + (p1.dy - center.dy + p2.dy - center.dy) * 0.3 - 30) + t * t * p2.dy;

      // Check if dot is within globe
      final distFromCenter = sqrt(pow(dotX - center.dx, 2) + pow(dotY - center.dy, 2));
      if (distFromCenter <= radius + 5) {
        // Dot glow
        final dotGlowPaint = Paint()
          ..color = const Color(0xFFFBBF24).withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
        canvas.drawCircle(Offset(dotX, dotY), 4, dotGlowPaint);

        // Dot
        final dotPaint = Paint()..color = const Color(0xFFFBBF24);
        canvas.drawCircle(Offset(dotX, dotY), 2.5, dotPaint);
      }
    }

    // Subtle overlay
    final overlayPaint = Paint()
      ..color = VeloraColors.surface.withValues(alpha: 0.1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), overlayPaint);
  }

  @override
  bool shouldRepaint(covariant _GlobePainter oldDelegate) => true;
}
