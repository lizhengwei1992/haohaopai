import 'package:flutter/material.dart';

class CameraGridLines extends StatelessWidget {
  final bool showGrid;

  const CameraGridLines({super.key, required this.showGrid});

  @override
  Widget build(BuildContext context) {
    if (!showGrid) {
      return const SizedBox.shrink();
    }

    return CustomPaint(size: Size.infinite, painter: _GridPainter());
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint =
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

    // 计算网格线位置
    final width = size.width;
    final height = size.height;

    // 水平线
    final horizontalStep = height / 3;
    canvas.drawLine(
      Offset(0, horizontalStep),
      Offset(width, horizontalStep),
      paint,
    );
    canvas.drawLine(
      Offset(0, horizontalStep * 2),
      Offset(width, horizontalStep * 2),
      paint,
    );

    // 垂直线
    final verticalStep = width / 3;
    canvas.drawLine(
      Offset(verticalStep, 0),
      Offset(verticalStep, height),
      paint,
    );
    canvas.drawLine(
      Offset(verticalStep * 2, 0),
      Offset(verticalStep * 2, height),
      paint,
    );

    // 绘制交点圆圈
    final circlePaint =
        Paint()
          ..color = Colors.white.withOpacity(0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;

    // 左上交点
    canvas.drawCircle(Offset(verticalStep, horizontalStep), 5, circlePaint);
    // 中上交点
    canvas.drawCircle(Offset(verticalStep * 2, horizontalStep), 5, circlePaint);
    // 左中交点
    canvas.drawCircle(Offset(verticalStep, horizontalStep * 2), 5, circlePaint);
    // 右中交点
    canvas.drawCircle(
      Offset(verticalStep * 2, horizontalStep * 2),
      5,
      circlePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
