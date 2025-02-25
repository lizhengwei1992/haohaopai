import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../services/image_analysis_service.dart';

class ShootingTips extends StatelessWidget {
  const ShootingTips({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CameraProvider>(
      builder: (context, provider, child) {
        final tips = provider.tips;

        return Positioned(
          top: MediaQuery.of(context).padding.top + 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              // 提示标题
              const Padding(
                padding: EdgeInsets.only(bottom: 16.0),
                child: Text(
                  '拍摄建议',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black45,
                      ),
                    ],
                  ),
                ),
              ),
              // 提示列表
              SizedBox(
                height: 200,
                child: PageView.builder(
                  itemCount: tips.length,
                  controller: PageController(viewportFraction: 0.9),
                  itemBuilder: (context, index) {
                    return _TipCard(tip: tips[index]);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TipCard extends StatefulWidget {
  final ShootingTip tip;

  const _TipCard({required this.tip});

  @override
  State<_TipCard> createState() => _TipCardState();
}

class _TipCardState extends State<_TipCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutBack,
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.3),
          end: Offset.zero,
        ).animate(_animation),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: Colors.black.withOpacity(0.7),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 提示类型标签
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _getGradientColors(widget.tip.type),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 提示内容
                  Text(
                    widget.tip.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  // 底部提示
                  const Center(
                    child: Text(
                      '左右滑动查看更多建议',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
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

  List<Color> _getGradientColors(String type) {
    switch (type) {
      case '构图':
        return [Colors.blue, Colors.lightBlue];
      case '光线':
        return [Colors.orange, Colors.amber];
      case '角度':
        return [Colors.purple, Colors.deepPurple];
      case '焦点':
        return [Colors.green, Colors.lightGreen];
      case '动作':
        return [Colors.red, Colors.redAccent];
      default:
        return [Colors.blueGrey, Colors.grey];
    }
  }
}
