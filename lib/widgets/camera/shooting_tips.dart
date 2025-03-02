import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import '../../services/image_analysis_service.dart';
import 'dart:math';

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
  late final Animation<Offset> _floatAnimation;
  bool _isPopped = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 5000), // 更长的动画时间
      vsync: this,
    );

    // 随机生成起始和结束位置
    final random = Random(widget.index);
    final startX = random.nextDouble() * 0.1 - 0.05; // -0.05到0.05之间
    final startY = random.nextDouble() * 0.1 - 0.05;
    final endX = random.nextDouble() * 0.1 - 0.05;
    final endY = random.nextDouble() * 0.1 - 0.05;

    // 无规则移动动画
    _floatAnimation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset(endX, endY),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );

    // 启动动画
    _controller.forward();

    // 添加循环动画
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  void _popBubble() {
    if (_isPopped) return;
    _isPopped = true;

    // 爆炸动画
    _controller
      ..removeStatusListener((status) {})
      ..animateTo(1.5, duration: const Duration(milliseconds: 300)).then((_) {
        if (mounted) {
          setState(() {});
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_isPopped) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;
    final bubbleSize = 140.0;

    // 计算气泡位置
    final positions = [
      Offset(screenSize.width * 0.2, screenSize.height * 0.2),
      Offset(screenSize.width * 0.7, screenSize.height * 0.15),
      Offset(screenSize.width * 0.1, screenSize.height * 0.5),
      Offset(screenSize.width * 0.65, screenSize.height * 0.45),
    ];
    final position = positions[widget.index % positions.length];

    // 气泡颜色
    final colors = [
      const Color(0xAAFF6F61),
      const Color(0xAA6B5B95),
      const Color(0xAA88B04B),
      const Color(0xAAF7CAC9),
    ];
    final color = colors[widget.index % colors.length];

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: GestureDetector(
        onTap: _popBubble,
        child: SlideTransition(
          position: _floatAnimation,
          child: Container(
            width: bubbleSize,
            height: bubbleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              gradient: RadialGradient(
                colors: [
                  color.withOpacity(0.9),
                  color.withOpacity(0.6),
                ],
                stops: const [0.5, 1.0],
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withOpacity(0.3),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _getIconForType(widget.tip.type),
                      color: Colors.white,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.tip.text,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
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
