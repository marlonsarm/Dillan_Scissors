import 'package:flutter/material.dart';

class BarberPole extends StatefulWidget {
  final double width;
  final double height;

  const BarberPole({super.key, this.width = 12, this.height = 76});

  @override
  State<BarberPole> createState() => _BarberPoleState();
}

class _BarberPoleState extends State<BarberPole>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.width / 2),
      child: SizedBox(
        width: widget.width,
        height: widget.height,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return CustomPaint(
              painter: _BarberPolePainter(_controller.value),
              size: Size(widget.width, widget.height),
            );
          },
        ),
      ),
    );
  }
}

class _BarberPolePainter extends CustomPainter {
  final double progress;
  _BarberPolePainter(this.progress);

  static const _colors = [
    Color(0xFFD4302B), // rojo
    Color(0xFFF5F0E6), // blanco
    Color(0xFF1F4FA3), // azul
    Color(0xFFF5F0E6), // blanco
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const stripeHeight = 18.0;
    final totalColors = _colors.length;
    final offset = progress * stripeHeight * totalColors;
    final diag = size.width * 1.5;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, size.height));

    for (double y = -stripeHeight * totalColors - diag;
        y < size.height + diag;
        y += stripeHeight) {
      final index = ((y + offset) / stripeHeight).floor();
      final color = _colors[((index % totalColors) + totalColors) % totalColors];
      paint.color = color;

      final path = Path()
        ..moveTo(0, y)
        ..lineTo(size.width, y - diag)
        ..lineTo(size.width, y - diag + stripeHeight)
        ..lineTo(0, y + stripeHeight)
        ..close();

      canvas.drawPath(path, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _BarberPolePainter oldDelegate) => true;
}