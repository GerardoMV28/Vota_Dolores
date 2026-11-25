import 'dart:math';
import 'package:flutter/material.dart';

class ConfetiOverlay extends StatefulWidget {
  const ConfetiOverlay({super.key});

  @override
  State<ConfetiOverlay> createState() => _ConfetiOverlayState();
}

class _ConfetiOverlayState extends State<ConfetiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ParticulaConfeti> _particulas;

  static const _colores = [
    Colors.indigo,
    Colors.amber,
    Colors.pinkAccent,
    Colors.teal,
    Colors.green,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    final rng = Random(42);
    _particulas = List.generate(65, (_) {
      return _ParticulaConfeti(
        xInicial: rng.nextDouble(),
        yInicial: -rng.nextDouble() * 0.4,
        velocidadY: 0.7 + rng.nextDouble() * 0.8,
        amplitudX: 12 + rng.nextDouble() * 24,
        fase: rng.nextDouble() * pi * 2,
        ancho: 6 + rng.nextDouble() * 6,
        alto: 10 + rng.nextDouble() * 8,
        velocidadGiro: (rng.nextDouble() - 0.5) * 10,
        color: _colores[rng.nextInt(_colores.length)],
      );
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfetiPainter(
              particulas: _particulas,
              progreso: _controller.value,
            ),
          );
        },
      ),
    );
  }
}

class _ParticulaConfeti {
  final double xInicial;
  final double yInicial;
  final double velocidadY;
  final double amplitudX;
  final double fase;
  final double ancho;
  final double alto;
  final double velocidadGiro;
  final Color color;

  const _ParticulaConfeti({
    required this.xInicial,
    required this.yInicial,
    required this.velocidadY,
    required this.amplitudX,
    required this.fase,
    required this.ancho,
    required this.alto,
    required this.velocidadGiro,
    required this.color,
  });
}

class _ConfetiPainter extends CustomPainter {
  final List<_ParticulaConfeti> particulas;
  final double progreso;

  _ConfetiPainter({required this.particulas, required this.progreso});

  @override
  void paint(Canvas canvas, Size size) {
    if (progreso >= 1.0) return;

    final opacidad = progreso > 0.75
        ? ((1.0 - progreso) / 0.25).clamp(0.0, 1.0)
        : 1.0;

    for (final p in particulas) {
      final y = (p.yInicial + progreso * p.velocidadY * 1.45) * size.height;
      if (y < -20 || y > size.height + 20) continue;

      final x =
          p.xInicial * size.width +
          sin(progreso * pi * 4 + p.fase) * p.amplitudX;
      final angulo = progreso * p.velocidadGiro * pi;

      final paint = Paint()
        ..color = p.color.withValues(alpha: opacidad)
        ..style = PaintingStyle.fill;

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angulo);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset.zero, width: p.ancho, height: p.alto),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfetiPainter oldDelegate) {
    return oldDelegate.progreso != progreso;
  }
}
