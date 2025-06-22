import 'package:flutter/material.dart';
import 'dart:math' as math;

class AiVisionCoreAnimation extends StatefulWidget {
  const AiVisionCoreAnimation({Key? key}) : super(key: key);

  @override
  _AiVisionCoreAnimationState createState() => _AiVisionCoreAnimationState();
}

class _AiVisionCoreAnimationState extends State<AiVisionCoreAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _borderAnimationController;

  @override
  void initState() {
    super.initState();
    _borderAnimationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 3))
          ..repeat();
  }

  @override
  void dispose() {
    _borderAnimationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: StreamingBorderPainter(
        rotationAnimation: _borderAnimationController,
      ),
      child: Container(), // 透明容器，只用于承载边框绘制
    );
  }
}

class StreamingBorderPainter extends CustomPainter {
  final Animation<double> rotationAnimation;

  StreamingBorderPainter({required this.rotationAnimation})
      : super(repaint: rotationAnimation);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final borderRadius = 12.0; // 相机预览的圆角半径
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    final paint = Paint()
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.cyan.withOpacity(0.8),
          Colors.blue.withOpacity(0.9),
          Colors.purple.withOpacity(0.8),
          Colors.pink.withOpacity(0.6),
          Colors.transparent,
        ],
        startAngle: 0.0,
        endAngle: math.pi * 2,
        transform: GradientRotation(rotationAnimation.value * math.pi * 2),
      ).createShader(rect)
      ..strokeWidth = 3.0
      ..style = PaintingStyle.stroke;

    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant StreamingBorderPainter oldDelegate) => false;
}
