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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _expandController;
  late final Animation<Offset> _floatAnimation;
  late final Animation<double> _expandAnimation;
  late final Animation<double> _scaleAnimation;
  bool _isExpanded = false;
  Offset? _originalPosition;

  @override
  void initState() {
    super.initState();

    // 初始化浮动动画控制器
    _controller = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );

    // 初始化展开动画控制器
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    // 配置浮动动画
    final random = Random(widget.index);
    final startX = random.nextDouble() * 0.1 - 0.05;
    final startY = random.nextDouble() * 0.1 - 0.05;
    final endX = random.nextDouble() * 0.1 - 0.05;
    final endY = random.nextDouble() * 0.1 - 0.05;

    _floatAnimation = Tween<Offset>(
      begin: Offset(startX, startY),
      end: Offset(endX, endY),
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutQuad,
      ),
    );

    // 配置展开动画
    _expandAnimation = Tween<double>(begin: 1.0, end: 1.8).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: Curves.easeInOutQuad,
      ),
    );

    // 配置缩放动画
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _expandController,
        curve: Curves.easeInOutQuad,
      ),
    );

    _controller.forward();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _controller.forward();
      }
    });
  }

  void _toggleExpand() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _expandController.forward();
      } else {
        _expandController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
    _originalPosition ??= position;

    // 气泡颜色
    final colors = [
      const Color(0xAAFF6F61),
      const Color(0xAA6B5B95),
      const Color(0xAA88B04B),
      const Color(0xAAF7CAC9),
    ];
    final color = colors[widget.index % colors.length];

    return Stack(
      children: [
        if (_isExpanded)
          GestureDetector(
            onTap: _toggleExpand,
            behavior: HitTestBehavior.opaque,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        Positioned(
          left: _isExpanded
              ? screenSize.width / 2 - bubbleSize * 0.9
              : _originalPosition!.dx,
          top: _isExpanded
              ? screenSize.height / 2 - bubbleSize * 0.9
              : _originalPosition!.dy,
          child: GestureDetector(
            onTap: _toggleExpand,
            child: AnimatedBuilder(
              animation: Listenable.merge([_expandController, _controller]),
              builder: (context, child) {
                return Transform.scale(
                  scale: _scaleAnimation.value,
                  child: SlideTransition(
                    position: _isExpanded
                        ? AlwaysStoppedAnimation(Offset.zero)
                        : _floatAnimation,
                    child: Container(
                      width: bubbleSize * _expandAnimation.value,
                      height: bubbleSize * _expandAnimation.value,
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
                              Flexible(
                                child: Icon(
                                  _getIconForType(widget.tip.type),
                                  color: Colors.white,
                                  size: 24 * (_isExpanded ? 1.2 : 1.0),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Flexible(
                                flex: 2,
                                child: SingleChildScrollView(
                                  padding: EdgeInsets.zero,
                                  child: Text(
                                    widget.tip.text,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12 * (_isExpanded ? 1.2 : 1.0),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: _isExpanded ? 6 : 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _expandController.dispose();
    super.dispose();
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
