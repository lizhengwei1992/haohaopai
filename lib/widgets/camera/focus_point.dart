import 'package:flutter/material.dart';

/// 相机对焦框组件
/// 显示在用户点击的位置，提供视觉反馈
class FocusPoint extends StatefulWidget {
  final Offset position;
  final Color color;
  final double size;
  final bool focusSuccess;

  const FocusPoint({
    Key? key,
    required this.position,
    this.color = Colors.yellow,
    this.size = 70.0,
    this.focusSuccess = false,
  }) : super(key: key);

  @override
  State<FocusPoint> createState() => _FocusPointState();
}

class _FocusPointState extends State<FocusPoint>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // 创建缩放动画，从1.2到0.9
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.2, end: 0.95)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.95, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 20,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 30,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.9)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_controller);

    // 创建透明度动画
    _opacityAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 70,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 20,
      ),
    ]).animate(_controller);

    // 创建脉冲动画，用于对焦成功后的视觉反馈
    _pulseAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 40,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.15)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.15, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 10,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.0)
            .chain(CurveTween(curve: Curves.linear)),
        weight: 40,
      ),
    ]).animate(_controller);

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
    return Positioned(
      left: widget.position.dx - (widget.size / 2),
      top: widget.position.dy - (widget.size / 2),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          // 根据对焦是否成功选择颜色
          final Color currentColor =
              widget.focusSuccess ? Colors.green : widget.color;

          // 应用脉冲动画，如果对焦成功
          final double scale = widget.focusSuccess
              ? _scaleAnimation.value * _pulseAnimation.value
              : _scaleAnimation.value;

          return Opacity(
            opacity: _opacityAnimation.value,
            child: Transform.scale(
              scale: scale,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: currentColor,
                    width: 1.5,
                  ),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: Stack(
                  children: [
                    // 左上角
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _buildCorner(currentColor),
                    ),
                    // 右上角
                    Positioned(
                      right: 0,
                      top: 0,
                      child: _buildCorner(currentColor),
                    ),
                    // 左下角
                    Positioned(
                      left: 0,
                      bottom: 0,
                      child: _buildCorner(currentColor),
                    ),
                    // 右下角
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: _buildCorner(currentColor),
                    ),
                    // 中心点
                    if (widget.focusSuccess)
                      Center(
                        child: Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: currentColor.withOpacity(0.7),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // 构建对焦框四角的小方块
  Widget _buildCorner(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: Colors.transparent,
        border: Border.all(
          color: color,
          width: 1.5,
        ),
      ),
    );
  }
}
