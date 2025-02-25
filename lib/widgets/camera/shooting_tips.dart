import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import '../../services/image_analysis_service.dart';

class ShootingTips extends StatelessWidget {
  const ShootingTips({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, provider, child) {
        final tips = provider.tips;

        if (tips.isEmpty) {
          return const SizedBox.shrink();
        }

        // 使用Stack布局，让气泡可以浮动在屏幕上
        return Stack(
          children: [
            for (int i = 0; i < tips.length; i++)
              _FloatingTipBubble(
                tip: tips[i],
                index: i,
                totalTips: tips.length,
              ),
          ],
        );
      },
    );
  }
}

class _FloatingTipBubble extends StatefulWidget {
  final ShootingTip tip;
  final int index;
  final int totalTips;

  const _FloatingTipBubble({
    required this.tip,
    required this.index,
    required this.totalTips,
  });

  @override
  State<_FloatingTipBubble> createState() => _FloatingTipBubbleState();
}

class _FloatingTipBubbleState extends State<_FloatingTipBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _opacityAnimation;
  late final Animation<Offset> _floatAnimation;

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 缩放动画
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.elasticOut,
    );

    // 透明度动画
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 0.9,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    ));

    // 浮动动画
    _floatAnimation = Tween<Offset>(
      begin: const Offset(0, 0),
      end: const Offset(0, -0.1),
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // 延迟启动动画，错开每个气泡的出现时间
    Future.delayed(Duration(milliseconds: 150 * widget.index), () {
      _controller.forward();
    });

    // 添加重复浮动效果
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 根据索引计算气泡位置
    final screenSize = MediaQuery.of(context).size;
    final bubbleSize = 180.0;

    // 计算气泡位置，使其分布在屏幕不同位置
    double left;
    double top;

    // 根据索引确定气泡位置
    switch (widget.index % 4) {
      case 0:
        left = screenSize.width * 0.1;
        top = screenSize.height * 0.25;
        break;
      case 1:
        left = screenSize.width * 0.6;
        top = screenSize.height * 0.2;
        break;
      case 2:
        left = screenSize.width * 0.15;
        top = screenSize.height * 0.5;
        break;
      case 3:
        left = screenSize.width * 0.55;
        top = screenSize.height * 0.45;
        break;
      default:
        left = screenSize.width * 0.3;
        top = screenSize.height * 0.3;
    }

    return Positioned(
      left: left,
      top: top,
      child: SlideTransition(
        position: _floatAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: FadeTransition(
            opacity: _opacityAnimation,
            child: Container(
              width: bubbleSize,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xCC8BC34A), // 透明淡绿色
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 提示类型标签
                  Row(
                    children: [
                      Icon(
                        _getIconForType(widget.tip.type),
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        widget.tip.type,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 提示内容
                  Text(
                    widget.tip.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case '构图':
        return Icons.grid_on;
      case '光线':
        return Icons.wb_sunny;
      case '角度':
        return Icons.rotate_right;
      case '焦点':
        return Icons.center_focus_strong;
      case '动作':
        return Icons.directions_run;
      default:
        return Icons.photo_camera;
    }
  }
}
