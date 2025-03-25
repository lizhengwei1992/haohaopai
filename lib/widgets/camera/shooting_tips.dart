import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import '../../models/shooting_tip.dart';

class ShootingTips extends StatefulWidget {
  const ShootingTips({Key? key}) : super(key: key);

  @override
  State<ShootingTips> createState() => _ShootingTipsState();
}

class _ShootingTipsState extends State<ShootingTips>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  // 记录每个卡片的展开状态
  final Map<String, bool> _expandedStates = {
    '构图': false,
    '光线': false,
    '角度': false,
    '动作': false,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 100.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // 获取每种类型对应的渐变色
  List<Color> _getGradientColors(String type) {
    switch (type) {
      case '构图':
        return [
          const Color(0xFFE8F1FF),
          const Color(0xFFF3F7FF),
        ];
      case '光线':
        return [
          const Color(0xFFFFEEEE),
          const Color(0xFFFFF6F6),
        ];
      case '角度':
        return [
          const Color(0xFFFFF6E9),
          const Color(0xFFFFFBF6),
        ];
      case '动作':
        return [
          const Color(0xFFFFEEF6),
          const Color(0xFFFFF6FA),
        ];
      default:
        return [Colors.white, Colors.white];
    }
  }

  // 获取每种类型对应的英文标题
  String _getEnglishTitle(String type) {
    switch (type) {
      case '构图':
        return 'Composition';
      case '光线':
        return 'Lighting';
      case '角度':
        return 'Angle';
      case '动作':
        return 'Action';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  // 顶部标题和进度条
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      children: [
                        const Text(
                          'Teach me to take',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: 120,
                          height: 2,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(1),
                          ),
                          child: Consumer<CameraProvider>(
                            builder: (context, provider, child) {
                              return FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: provider.uploadProgress,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 拍摄建议卡片列表
                  Consumer<CameraProvider>(
                    builder: (context, provider, child) {
                      final tips = provider.tips;
                      return Column(
                        children: [
                          for (final type in ['构图', '光线', '角度', '动作'])
                            TipCard(
                              type: type,
                              englishTitle: _getEnglishTitle(type),
                              content: tips
                                  .firstWhere(
                                    (tip) => tip.type == type,
                                    orElse: () => ShootingTip(
                                      type: type,
                                      text: '',
                                      priority: 0,
                                    ),
                                  )
                                  .text,
                              gradientColors: _getGradientColors(type),
                              isExpanded: _expandedStates[type] ?? false,
                              onToggle: () {
                                setState(() {
                                  _expandedStates[type] =
                                      !(_expandedStates[type] ?? false);
                                });
                              },
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class TipCard extends StatelessWidget {
  final String type;
  final String englishTitle;
  final String content;
  final List<Color> gradientColors;
  final bool isExpanded;
  final VoidCallback onToggle;

  const TipCard({
    Key? key,
    required this.type,
    required this.englishTitle,
    required this.content,
    required this.gradientColors,
    required this.isExpanded,
    required this.onToggle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: gradientColors,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        englishTitle,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF333333),
                        ),
                      ),
                      Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.1),
                        ),
                        child: Center(
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 300),
                            turns: isExpanded ? 0.125 : 0,
                            child: const Icon(
                              Icons.add,
                              size: 18,
                              color: Color(0xFF666666),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isExpanded) ...[
                    const SizedBox(height: 12),
                    Text(
                      content,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF666666),
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
