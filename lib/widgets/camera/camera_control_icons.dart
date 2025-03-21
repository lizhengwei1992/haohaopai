import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 相机控制按钮的通用样式
class CameraControlButton extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const CameraControlButton({
    Key? key,
    this.onTap,
    required this.child,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(child: child),
      ),
    );
  }
}

/// 闪光灯图标
class FlashIcon extends StatelessWidget {
  final bool isOn;

  const FlashIcon({
    super.key,
    this.isOn = false,
  });

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      isOn
          ? 'assets/icons/camera_flash_off.svg'
          : 'assets/icons/camera_flash_auto.svg',
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      ),
    );
  }
}

/// 曝光控制图标 - 重新设计的更美观的版本
class ExposureIcon extends StatelessWidget {
  const ExposureIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(22, 22),
      painter: ExposureIconPainter(),
    );
  }
}

/// 曝光图标绘制器
class ExposureIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 绘制一个圆
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3,
      paint,
    );

    // 绘制中心点
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 12,
      Paint()..color = Colors.white,
    );

    // 绘制四条辐射线
    // 上
    canvas.drawLine(
      Offset(size.width / 2, size.height / 6),
      Offset(size.width / 2, 0),
      paint,
    );
    // 下
    canvas.drawLine(
      Offset(size.width / 2, size.height * 5 / 6),
      Offset(size.width / 2, size.height),
      paint,
    );
    // 左
    canvas.drawLine(
      Offset(size.width / 6, size.height / 2),
      Offset(0, size.height / 2),
      paint,
    );
    // 右
    canvas.drawLine(
      Offset(size.width * 5 / 6, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

/// 画面比例图标
class AspectRatioIcon extends StatelessWidget {
  final String ratio;
  final bool isSelected;

  const AspectRatioIcon({
    Key? key,
    required this.ratio,
    this.isSelected = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      ratio,
      style: TextStyle(
        color: isSelected ? Colors.yellow : Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// 滤镜图标
class FilterIcon extends StatelessWidget {
  const FilterIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 添加调试信息
    debugPrint('尝试加载滤镜图标: assets/icons/camera_fliter.svg');

    try {
      return SvgPicture.asset(
        'assets/icons/camera_fliter.svg',
        width: 24,
        height: 24,
        colorFilter: const ColorFilter.mode(
          Colors.white,
          BlendMode.srcIn,
        ),
      );
    } catch (e) {
      // 如果加载失败，显示错误信息并返回一个基本图标
      debugPrint('滤镜图标加载失败: $e');
      return Icon(
        Icons.filter_vintage,
        color: Colors.white,
        size: 24,
      );
    }
  }
}

/// 相机反转图标
class CameraFlipIcon extends StatelessWidget {
  const CameraFlipIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/icons/camera_reverse.svg',
      width: 24,
      height: 24,
      colorFilter: const ColorFilter.mode(
        Colors.white,
        BlendMode.srcIn,
      ),
    );
  }
}

/// 个人中心图标 - 使用更美观的图标
class PersonIcon extends StatelessWidget {
  const PersonIcon({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Icon(
      Icons.account_circle_rounded,
      color: Colors.white,
      size: 28, // 稍微增大图标尺寸，使其在没有背景时更加明显
    );
  }
}
