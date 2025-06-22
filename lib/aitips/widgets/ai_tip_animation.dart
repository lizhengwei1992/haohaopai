import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/ai_tip.dart';

/// AI拍摄建议显示组件
/// 简化版本，只显示tips结果，无分析动画
class AiTipAnimation extends StatefulWidget {
  /// 拍摄建议列表
  final List<AiTip> tips;

  /// 是否正在分析
  final bool isAnalyzing;

  /// 当提示可见性变化时的回调
  final Function(bool) onTipsVisibilityChanged;

  const AiTipAnimation({
    Key? key,
    required this.tips,
    required this.isAnalyzing,
    required this.onTipsVisibilityChanged,
  }) : super(key: key);

  @override
  State<AiTipAnimation> createState() => _AiTipAnimationState();
}

class _AiTipAnimationState extends State<AiTipAnimation>
    with SingleTickerProviderStateMixin {
  // 只保留展开动画控制器
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // 状态跟踪
  String? _selectedTipType;
  bool _isTipExpanded = false;

  // 跟踪每个tip类型是否被查看过
  final Set<String> _viewedTipTypes = <String>{};

  // 是否所有tips都已被查看过
  bool get _allTipsViewed =>
      _viewedTipTypes.length >= math.min(4, widget.tips.length) &&
      widget.tips.isNotEmpty;

  // tips配置 - 按顺时针顺序排列：角度 -> 动作 -> 构图 -> 光线
  final List<Map<String, dynamic>> _tipsConfig = const [
    {
      'type': '角度',
      'quadrant': '左下',
      'angle': -135 * math.pi / 180,
      'color': Color(0xFF29B6F6), // 蓝色
      'gradientStart': Color(0xFF4FC3F7),
      'gradientEnd': Color(0xFF29B6F6),
    },
    {
      'type': '动作',
      'quadrant': '右下',
      'angle': -45 * math.pi / 180,
      'color': Color(0xFF66BB6A), // 绿色
      'gradientStart': Color(0xFF81C784),
      'gradientEnd': Color(0xFF66BB6A),
    },
    {
      'type': '构图',
      'quadrant': '左上',
      'angle': 135 * math.pi / 180,
      'color': Color(0xFF5C6BC0), // 紫蓝色
      'gradientStart': Color(0xFF9575CD),
      'gradientEnd': Color(0xFF5C6BC0),
    },
    {
      'type': '光线',
      'quadrant': '右上',
      'angle': 45 * math.pi / 180,
      'color': Color(0xFFEF5350), // 红色
      'gradientStart': Color(0xFFE57373),
      'gradientEnd': Color(0xFFEF5350),
    },
  ];

  // 存储点击区域
  final List<Rect> _hitTestRects = [];

  @override
  void initState() {
    super.initState();

    // 只初始化展开动画控制器
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // 初始化展开动画
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void didUpdateWidget(AiTipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 检测tips内容变化
    if (widget.tips != oldWidget.tips) {
      // 如果tips被清空（比如状态重置），重置所有内部状态
      if (widget.tips.isEmpty) {
        setState(() {
          _selectedTipType = null;
          _isTipExpanded = false;
          _viewedTipTypes.clear();
        });

        // 停止展开动画并重置
        _expandController.stop();
        _expandController.reset();

        debugPrint('📸 检测到tips被清空，重置AiTipAnimation内部状态');
      }
    }
  }

  @override
  void dispose() {
    _expandController.dispose();
    super.dispose();
  }

  // 展开/收起tip详情
  void _toggleTipExpand(String tipType) {
    if (_selectedTipType == tipType && _isTipExpanded) {
      // 收起当前选中的tip，并标记为已查看
      _expandController.reverse().then((_) {
        setState(() {
          _isTipExpanded = false;
          _selectedTipType = null;
          _viewedTipTypes.add(tipType); // 标记为已查看
        });
        // 通知父组件状态变化
        widget.onTipsVisibilityChanged(!_allTipsViewed);
      });
    } else {
      // 展开新选中的tip
      setState(() {
        _selectedTipType = tipType;
        _isTipExpanded = true;
      });
      _expandController.forward(from: 0.0);
      // 通知父组件状态变化
      widget.onTipsVisibilityChanged(true);
    }
  }

  // 检查点是否在可点击区域内
  bool _isInHitTestAreas(Offset position) {
    // 如果详情卡片已展开，任何地方的点击都拦截
    if (_isTipExpanded) return true;

    // 检查四个tip区域
    for (final rect in _hitTestRects) {
      if (rect.contains(position)) return true;
    }

    // 不在任何可点击区域内
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // 如果正在分析中或没有tips，不显示任何内容
    if (widget.isAnalyzing || widget.tips.isEmpty) {
      return const SizedBox.shrink();
    }

    // 获取屏幕尺寸
    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    // 清空当前的hit test区域
    _hitTestRects.clear();

    return Listener(
      // 拦截所有点击事件
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (!_isInHitTestAreas(event.position)) {
          debugPrint('点击未命中AiTipAnimation组件的可点击区域: ${event.position}');
        } else {
          debugPrint('点击命中AiTipAnimation组件的可点击区域: ${event.position}');
        }
      },
      child: Stack(
        children: [
          // 半透明背景
          if (_isTipExpanded)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  // 点击背景时收起详情卡片
                  _toggleTipExpand(_selectedTipType!);
                },
                child: AnimatedOpacity(
                  opacity: _isTipExpanded ? 0.7 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(color: Colors.black),
                ),
              ),
            ),

          // 显示tips圆圈
          ...List.generate(math.min(4, widget.tips.length), (index) {
            if (index >= _tipsConfig.length) return const SizedBox.shrink();

            final config = _tipsConfig[index];
            final String tipType = config['type'] as String;

            // 查找对应类型的tip
            final tip = widget.tips.firstWhere(
              (t) => t.type == tipType,
              orElse: () => widget.tips[index],
            );

            // 计算位置
            final angle = config['angle'] as double;
            final distance = screenWidth * 0.3;
            final x = math.cos(angle) * distance;
            final y = math.sin(angle) * distance;

            final visibleSize = 120.0;
            final tipLeft = screenWidth / 2 + x - visibleSize / 2;
            final tipTop = screenHeight / 2 + y - visibleSize / 2;

            // 添加到点击区域
            _hitTestRects.add(
              Rect.fromLTWH(tipLeft, tipTop, visibleSize, visibleSize),
            );

            return Positioned(
              top: tipTop,
              left: tipLeft,
              child: GestureDetector(
                onTap: () => _toggleTipExpand(tipType),
                child: Container(
                  width: visibleSize,
                  height: visibleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        config['gradientStart'] as Color,
                        config['gradientEnd'] as Color,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          tipType,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          tip.text.length > 10
                              ? '${tip.text.substring(0, 10)}...'
                              : tip.text,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          // 展开的详情卡片
          if (_isTipExpanded && _selectedTipType != null)
            Center(
              child: AnimatedBuilder(
                animation: _expandAnimation,
                builder: (context, child) {
                  final selectedTip = widget.tips.firstWhere(
                    (t) => t.type == _selectedTipType,
                    orElse: () => widget.tips.first,
                  );

                  final config = _tipsConfig.firstWhere(
                    (c) => c['type'] == _selectedTipType,
                    orElse: () => _tipsConfig.first,
                  );

                  return Transform.scale(
                    scale: _expandAnimation.value,
                    child: Opacity(
                      opacity: _expandAnimation.value,
                      child: Container(
                        width: screenWidth * 0.8,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              config['gradientStart'] as Color,
                              config['gradientEnd'] as Color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              selectedTip.type,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              selectedTip.text,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                height: 1.5,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => _toggleTipExpand(_selectedTipType!),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Text(
                                  '收起',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            ),
        ],
      ),
    );
  }
}
