import 'package:flutter/material.dart';

class CameraFocusPoint extends StatefulWidget {
  final double size;
  final bool focusSuccess;
  final Color successColor;
  final Color defaultColor;
  final Color failureColor;

  const CameraFocusPoint({
    Key? key,
    required this.size,
    required this.focusSuccess,
    this.successColor = Colors.green,
    this.defaultColor = Colors.white,
    this.failureColor = Colors.red,
  }) : super(key: key);

  @override
  State<CameraFocusPoint> createState() => _CameraFocusPointState();
}

class _CameraFocusPointState extends State<CameraFocusPoint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.2, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutQuad,
      ),
    );

    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.6, 1.0, curve: Curves.easeOut),
      ),
    );

    // 启动动画
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 获取焦点框的颜色
    final Color focusColor = widget.focusSuccess
        ? widget.successColor
        : (widget.focusSuccess == null
            ? widget.defaultColor
            : widget.failureColor);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Opacity(
          opacity: _opacityAnimation.value,
          child: Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                border: Border.all(
                  color: focusColor,
                  width: 1.5,
                ),
              ),
              child: Stack(
                children: [
                  // 焦点中心十字线
                  Positioned.fill(
                    child: CustomPaint(
                      painter: FocusCrossPainter(color: focusColor),
                    ),
                  ),
                  // 四角标记
                  Positioned(
                    top: 0,
                    left: 0,
                    child: _buildCorner(
                      color: focusColor,
                      top: true,
                      left: true,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: _buildCorner(
                      color: focusColor,
                      top: true,
                      left: false,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: _buildCorner(
                      color: focusColor,
                      top: false,
                      left: true,
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: _buildCorner(
                      color: focusColor,
                      top: false,
                      left: false,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCorner({
    required Color color,
    required bool top,
    required bool left,
  }) {
    const double cornerLength = 10.0; // 角标长度
    const double cornerThickness = 2.0; // 角标粗细

    return SizedBox(
      width: cornerLength,
      height: cornerLength,
      child: CustomPaint(
        painter: CornerPainter(
          color: color,
          top: top,
          left: left,
          thickness: cornerThickness,
        ),
      ),
    );
  }
}

// 角标绘制器
class CornerPainter extends CustomPainter {
  final Color color;
  final bool top;
  final bool left;
  final double thickness;

  CornerPainter({
    required this.color,
    required this.top,
    required this.left,
    this.thickness = 2.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double x = left ? 0 : size.width;
    final double y = top ? 0 : size.height;

    // 水平线
    canvas.drawLine(
      Offset(x, y),
      Offset(left ? x + size.width : x - size.width, y),
      paint,
    );

    // 垂直线
    canvas.drawLine(
      Offset(x, y),
      Offset(x, top ? y + size.height : y - size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// 焦点中心十字线绘制器
class FocusCrossPainter extends CustomPainter {
  final Color color;
  final double thickness;

  FocusCrossPainter({
    required this.color,
    this.thickness = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round;

    // 十字线尺寸 (20%的框大小)
    final double crossSize = size.width * 0.2;
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;

    // 水平线
    canvas.drawLine(
      Offset(centerX - crossSize / 2, centerY),
      Offset(centerX + crossSize / 2, centerY),
      paint,
    );

    // 垂直线
    canvas.drawLine(
      Offset(centerX, centerY - crossSize / 2),
      Offset(centerX, centerY + crossSize / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
