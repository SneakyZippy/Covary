import 'dart:math' as math;
import 'package:flutter/material.dart';

/// The shape of a particle.
enum ParticleShape { circle, ring, square, star }

/// Represents a single active particle.
class Particle {
  Offset position;
  Offset velocity;
  double size;
  Color color;
  double opacity;
  double rotation;
  double rotationSpeed;
  double drag;
  double gravity;
  ParticleShape shape;
  double life; // 0.0 (dead) to 1.0 (born)
  double decaySpeed;

  Particle({
    required this.position,
    required this.velocity,
    required this.size,
    required this.color,
    this.opacity = 1.0,
    this.rotation = 0.0,
    this.rotationSpeed = 0.0,
    this.drag = 0.95,
    this.gravity = 0.15,
    this.shape = ParticleShape.circle,
    this.life = 1.0,
    required this.decaySpeed,
  });

  void update() {
    // Apply gravity
    velocity = Offset(velocity.dx, velocity.dy + gravity);
    // Apply drag
    velocity = Offset(velocity.dx * drag, velocity.dy * drag);
    // Apply velocity to position
    position += velocity;
    // Apply rotation
    rotation += rotationSpeed;
    // Decelerate life
    life = math.max(0.0, life - decaySpeed);
    // Opacity fades with life
    opacity = life;
  }
}

/// An InheritedWidget-based controller to trigger animations from anywhere in the subtree.
class ConfettiOverlay extends StatefulWidget {
  final Widget child;

  const ConfettiOverlay({super.key, required this.child});

  static ConfettiOverlayState? of(BuildContext context) {
    return context.findAncestorStateOfType<ConfettiOverlayState>();
  }

  @override
  State<ConfettiOverlay> createState() => ConfettiOverlayState();
}

class ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final List<Particle> _particles = [];
  final math.Random _random = math.Random();

  // Curated elegant color palette to match brand colors
  static const List<Color> _palette = [
    Color(0xFF38debb), // Primary Aquamarine
    Color(0xFFcdbdff), // Secondary Violet
    Color(0xFFdec65a), // Tertiary Yellow
    Color(0xFF60a5fa), // Azure Blue
    Color(0xFFfb923c), // Coral Orange
    Color(0xFFfb7185), // Ruby Pink
  ];

  @override
  void initState() {
    super.initState();
    // We run the controller continuously if there are active particles
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_updateParticles);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateParticles() {
    if (!mounted) return;
    setState(() {
      for (var p in _particles) {
        p.update();
      }
      _particles.removeWhere((p) => p.life <= 0.0);
    });

    if (_particles.isEmpty && _controller.isAnimating) {
      _controller.stop();
    }
  }

  /// Triggers a localized burst of particles at a specific position.
  void burst(Offset globalPosition, {int count = 18}) {
    if (!mounted) return;
    
    // Convert global offset to local overlay coordinate
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final localPosition = renderBox.globalToLocal(globalPosition);

    setState(() {
      for (int i = 0; i < count; i++) {
        // Random angle and speed
        final double angle = _random.nextDouble() * 2 * math.pi;
        final double speed = 2.0 + _random.nextDouble() * 6.0;
        final double size = 6.0 + _random.nextDouble() * 8.0;

        _particles.add(
          Particle(
            position: localPosition,
            velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed - 2.0),
            size: size,
            color: _palette[_random.nextInt(_palette.length)],
            drag: 0.96,
            gravity: 0.12,
            shape: ParticleShape.values[_random.nextInt(ParticleShape.values.length)],
            decaySpeed: 0.015 + _random.nextDouble() * 0.015,
            rotationSpeed: (_random.nextDouble() - 0.5) * 0.2,
          ),
        );
      }
    });

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  /// Triggers a gentle full-screen celebration from the top/sides.
  void celebrate({int count = 55}) {
    if (!mounted) return;
    final Size size = MediaQuery.of(context).size;

    setState(() {
      for (int i = 0; i < count; i++) {
        // Spawn across the width at the top, slightly randomized height (offscreen or near top)
        final double x = _random.nextDouble() * size.width;
        final double y = -20.0 - _random.nextDouble() * 150.0;
        
        final double speedX = (_random.nextDouble() - 0.5) * 3.0; // slight drift
        final double speedY = 1.0 + _random.nextDouble() * 4.0;
        final double particleSize = 6.0 + _random.nextDouble() * 10.0;

        _particles.add(
          Particle(
            position: Offset(x, y),
            velocity: Offset(speedX, speedY),
            size: particleSize,
            color: _palette[_random.nextInt(_palette.length)],
            drag: 0.98,
            gravity: 0.08,
            shape: ParticleShape.values[_random.nextInt(ParticleShape.values.length)],
            decaySpeed: 0.006 + _random.nextDouble() * 0.008,
            rotationSpeed: (_random.nextDouble() - 0.5) * 0.1,
          ),
        );
      }
    });

    if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_particles.isNotEmpty)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _ConfettiPainter(particles: _particles),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final List<Particle> particles;

  _ConfettiPainter({required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()..style = PaintingStyle.fill;

    for (var p in particles) {
      paint.color = p.color.withValues(alpha: p.opacity);
      
      canvas.save();
      canvas.translate(p.position.dx, p.position.dy);
      canvas.rotate(p.rotation);

      switch (p.shape) {
        case ParticleShape.circle:
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          break;
          
        case ParticleShape.ring:
          paint.style = PaintingStyle.stroke;
          paint.strokeWidth = 2.0;
          canvas.drawCircle(Offset.zero, p.size / 2, paint);
          paint.style = PaintingStyle.fill; // restore
          break;
          
        case ParticleShape.square:
          canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size),
            paint,
          );
          break;
          
        case ParticleShape.star:
          _drawStar(canvas, paint, p.size);
          break;
      }
      
      canvas.restore();
    }
  }

  void _drawStar(Canvas canvas, Paint paint, double size) {
    final Path path = Path();
    const int points = 5;
    final double outerRadius = size / 2;
    final double innerRadius = size / 4;
    double angle = -math.pi / 2;
    final double step = math.pi / points;

    path.moveTo(0, -outerRadius);

    for (int i = 0; i < points * 2; i++) {
      angle += step;
      final double r = (i % 2 == 0) ? innerRadius : outerRadius;
      path.lineTo(r * math.cos(angle), r * math.sin(angle));
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) => true;
}
