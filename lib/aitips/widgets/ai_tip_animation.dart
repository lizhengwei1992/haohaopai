import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../models/ai_tip.dart';

/// AI 拍摄建议展示组件 —— 赛博朋克旋转气泡
///
/// 状态驱动：
/// - 分析中（isAnalyzing=true）：4 个霓虹光圈绕画面中心旋转（跑马灯，3s/圈）
/// - 出结果：旋转减速停止、气泡停在四个斜对角，随后展开显示内容
/// - 点击气泡：弹出完整详情卡
class AiTipAnimation extends StatefulWidget {
  final List<AiTip> tips;
  final bool isAnalyzing;

  const AiTipAnimation({
    Key? key,
    required this.tips,
    required this.isAnalyzing,
  }) : super(key: key);

  @override
  State<AiTipAnimation> createState() => _AiTipAnimationState();
}

class _AiTipAnimationState extends State<AiTipAnimation>
    with TickerProviderStateMixin {
  // 旋转控制器（跑马灯速度，与预览页跑马灯一致）
  late final AnimationController _rotation;

  // 展开控制器（停止旋转后气泡展开内容）
  late final AnimationController _expand;

  // 当前选中展开详情的维度
  String? _selectedSlot;

  // 气泡斜对角布局配置（淡色系）
  static const List<Map<String, dynamic>> _slots = [
    {
      'type': '焦点',
      'angle': -135 * math.pi / 180, // 左下
      'color': Color(0xFF7FD4F0),
    },
    {
      'type': '构图',
      'angle': 135 * math.pi / 180, // 左上
      'color': Color(0xFFB0B8F5),
    },
    {
      'type': '色彩',
      'angle': 45 * math.pi / 180, // 右上
      'color': Color(0xFFFFD59E),
    },
    {
      'type': '光线',
      'angle': -45 * math.pi / 180, // 右下
      'color': Color(0xFFF5A9A9),
    },
  ];

  // 完整维度名 -> 简短显示名
  static const Map<String, String> _typeNameMap = {
    '构图与画面布局': '构图',
    '主体与焦点': '焦点',
    '光线与曝光': '光线',
    '色彩与对比': '色彩',
    '构图': '构图',
    '焦点': '焦点',
    '光线': '光线',
    '色彩': '色彩',
  };

  @override
  void initState() {
    super.initState();
    _rotation = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    _expand = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _syncState();
  }

  @override
  void didUpdateWidget(AiTipAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isAnalyzing != widget.isAnalyzing ||
        !_sameTips(oldWidget.tips, widget.tips)) {
      _syncState();
    }
  }

  @override
  void dispose() {
    _rotation.dispose();
    _expand.dispose();
    super.dispose();
  }

  bool _sameTips(List<AiTip> a, List<AiTip> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i].type != b[i].type || a[i].text != b[i].text) return false;
    }
    return true;
  }

  /// 根据当前状态驱动旋转/展开动画
  void _syncState() {
    if (widget.isAnalyzing) {
      _selectedSlot = null;
      _expand.value = 0;
      if (!_rotation.isAnimating) {
        _rotation.repeat();
      }
    } else if (widget.tips.isNotEmpty) {
      // 出结果：减速停到最近整圈（视觉回到斜对角位），然后展开
      _rotation.stop();
      final target = _rotation.value.round().toDouble();
      _rotation
          .animateTo(
            target,
            duration: const Duration(milliseconds: 450),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
        if (mounted) _expand.forward();
      });
    } else {
      _rotation.stop();
      _rotation.value = 0;
      _expand.value = 0;
    }
  }

  String _displayName(String t) => _typeNameMap[t] ?? t;

  // 线性插值（替代 lerpDouble）
  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// 找到某维度槽位对应的建议
  AiTip? _tipForSlot(String slotType) {
    for (final t in widget.tips) {
      if (_displayName(t.type) == slotType) return t;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isAnalyzing && widget.tips.isEmpty) {
      return const SizedBox.shrink();
    }

    final size = MediaQuery.of(context).size;
    final screenWidth = size.width;
    final screenHeight = size.height;

    return Stack(
      children: [
        // 旋转气泡层
        AnimatedBuilder(
          animation: Listenable.merge([_rotation, _expand]),
          builder: (context, _) {
            // 气泡轨道半径
            final distance = screenWidth * 0.32;
            return Transform.rotate(
              angle: _rotation.value * 2 * math.pi,
              child: Stack(
                children: [
                  // 跑马灯光环（随气泡一起旋转，展开后淡出）
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _MarqueeRingPainter(
                          radius: distance,
                          opacity: 1 - _expand.value,
                        ),
                      ),
                    ),
                  ),
                  // 4 个斜对角气泡
                  ...List.generate(_slots.length, (index) {
                    final slot = _slots[index];
                    final angle = slot['angle'] as double;
                    final color = slot['color'] as Color;
                    final slotType = slot['type'] as String;
                    final tip = _tipForSlot(slotType);

                    final dx = math.cos(angle) * distance;
                    final dy = math.sin(angle) * distance;

                    // 气泡从光圈尺寸展开到卡片尺寸（加大）
                    final bubbleSize = _lerp(80.0, 160.0, _expand.value);

                    return Positioned(
                      left: screenWidth / 2 + dx - bubbleSize / 2,
                      top: screenHeight / 2 + dy - bubbleSize / 2,
                      child: _buildBubble(
                        slotType: slotType,
                        color: color,
                        tip: tip,
                        bubbleSize: bubbleSize,
                        progress: _expand.value,
                      ),
                    );
                  }),
                ],
              ),
            );
          },
        ),

        // 详情卡（不随气泡旋转）
        if (_selectedSlot != null)
          _buildDetailCard(_selectedSlot!, screenWidth),
      ],
    );
  }

  /// 单个气泡：分析中是霓虹光圈，出结果展开为内容卡
  Widget _buildBubble({
    required String slotType,
    required Color color,
    required AiTip? tip,
    required double bubbleSize,
    required double progress,
  }) {
    final borderRadius = BorderRadius.circular(_lerp(28.0, 20.0, progress));

    // 内容只在气泡展开到足够大后才布局，避免小气泡里 RenderFlex 溢出
    final showContent = tip != null && progress > 0.4;

    return GestureDetector(
      onTap: showContent ? () => _toggleDetail(slotType) : null,
      child: Container(
        width: bubbleSize,
        height: bubbleSize,
        decoration: BoxDecoration(
          color: const Color(0xFF0D0F1A).withValues(alpha: 0.45),
          borderRadius: borderRadius,
          border: Border.all(
            color: color.withValues(alpha: 0.7),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 18,
              spreadRadius: 1,
            ),
          ],
        ),
        child: !showContent
            // 分析中/未展开：中心光点
            ? Center(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.9),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.7),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              )
            // 出结果：展开显示内容
            : Opacity(
                opacity: ((progress - 0.4) / 0.6).clamp(0.0, 1.0),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        slotType,
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tip.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  /// 展开/收起详情卡
  void _toggleDetail(String slotType) {
    setState(() {
      _selectedSlot = _selectedSlot == slotType ? null : slotType;
    });
  }

  /// 赛博朋克详情卡
  Widget _buildDetailCard(String slotType, double screenWidth) {
    final tip = _tipForSlot(slotType);
    if (tip == null) return const SizedBox.shrink();

    final slot = _slots.firstWhere((s) => s['type'] == slotType);
    final color = slot['color'] as Color;

    return Positioned.fill(
      child: GestureDetector(
        onTap: () => _toggleDetail(slotType),
        child: Container(
          color: Colors.black.withValues(alpha: 0.55),
          alignment: Alignment.center,
          child: Container(
            width: screenWidth * 0.8,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0D0F1A),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: color.withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _displayName(tip.type),
                  style: TextStyle(
                    color: color,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tip.text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '点击任意处关闭',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 跑马灯光环画笔：在气泡轨道上画一圈旋转的光弧（SweepGradient 拖尾）
class _MarqueeRingPainter extends CustomPainter {
  final double radius;
  final double opacity;

  _MarqueeRingPainter({required this.radius, required this.opacity});

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..shader = SweepGradient(
        colors: [
          Colors.transparent,
          Colors.cyan.withValues(alpha: 0.7 * opacity),
          Colors.white.withValues(alpha: 0.9 * opacity),
          Colors.purpleAccent.withValues(alpha: 0.7 * opacity),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawCircle(center, radius, paint);
  }

  @override
  bool shouldRepaint(covariant _MarqueeRingPainter oldDelegate) =>
      oldDelegate.radius != radius || oldDelegate.opacity != opacity;
}
