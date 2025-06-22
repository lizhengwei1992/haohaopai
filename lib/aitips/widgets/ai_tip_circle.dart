import 'package:flutter/material.dart';
import '../models/ai_tip.dart';

/// AI拍摄建议圆圈组件
/// 用于显示单个拍摄建议的圆形图标
class AiTipCircle extends StatelessWidget {
  /// 拍摄建议
  final AiTip tip;

  /// 点击回调
  final VoidCallback onTap;

  /// 动画比例
  final double scale;

  const AiTipCircle({
    Key? key,
    required this.tip,
    required this.onTap,
    this.scale = 1.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: scale,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getTipColor(tip.type),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Text(
              tip.type,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 根据tip类型获取颜色
  Color _getTipColor(String type) {
    switch (type) {
      case '构图':
        return Colors.blue;
      case '光线':
        return Colors.orange;
      case '角度':
        return Colors.green;
      case '动作':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
