import 'dart:math';
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  const ParticleBackground({super.key});

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  final int particleCount = 80; // Parçacık sayısı

  @override
  void initState() {
    super.initState();
    // Parçacıkları ilklendir
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle(
        x: _random.nextDouble() * 500, // Başlangıç rastgele pozisyon, build içinde güncellenecek
        y: _random.nextDouble() * 1000,
        vx: (_random.nextDouble() - 0.5) * 1.5, // Hız vektörü x
        vy: (_random.nextDouble() - 0.5) * 1.5, // Hız vektörü y
        radius: _random.nextDouble() * 2 + 1, // 1-3 px arası boyut
      ));
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..addListener(() {
        setState(() {
          _updateParticles();
        });
      });
    _controller.repeat();
  }

  void _updateParticles() {
    final size = MediaQuery.of(context).size;
    for (var p in _particles) {
      p.x += p.vx;
      p.y += p.vy;

      // Ekran dışına çıkarsa geri dön
      if (p.x < 0 || p.x > size.width) p.vx *= -1;
      if (p.y < 0 || p.y > size.height) p.vy *= -1;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: ParticlePainter(_particles),
    );
  }
}

class Particle {
  double x;
  double y;
  double vx;
  double vy;
  double radius;

  Particle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.radius,
  });
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;
  final double linkDistance = 120.0; // Çizgi çekilecek max mesafe

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    final curPaint = Paint()..color = Colors.blueAccent.withValues(alpha: 0.6);
    final linkPaint = Paint()..strokeWidth = 1.0;

    // Background is dark
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF141416),
    );

    for (int i = 0; i < particles.length; i++) {
      final p1 = particles[i];

      // Nokta çiz
      curPaint.color = Colors.blueAccent.withValues(alpha: 0.8);
      canvas.drawCircle(Offset(p1.x, p1.y), p1.radius, curPaint);

      // Yakındaki noktalara çizgi çek
      for (int j = i + 1; j < particles.length; j++) {
        final p2 = particles[j];
        final distance = sqrt(pow(p1.x - p2.x, 2) + pow(p1.y - p2.y, 2));

        if (distance < linkDistance) {
          final alpha = (1.0 - (distance / linkDistance)).clamp(0.0, 1.0);
          // Antigravity renklerine ithafen mavi-mor karışımı bir tonda ağ
          linkPaint.color = const Color(0xFF6C5CE7).withValues(alpha: alpha * 0.5);
          canvas.drawLine(Offset(p1.x, p1.y), Offset(p2.x, p2.y), linkPaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
