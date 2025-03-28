import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_animate/flutter_animate.dart';
import '../../models/shooting_tip.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class ShootingTipsAnimation extends StatefulWidget {
  final List<ShootingTip> tips;
  final bool isAnalyzing;
  final double uploadProgress;
  final Function(bool) onTipsVisibilityChanged;

  const ShootingTipsAnimation({
    Key? key,
    required this.tips,
    required this.isAnalyzing,
    required this.uploadProgress,
    required this.onTipsVisibilityChanged,
  }) : super(key: key);

  @override
  State<ShootingTipsAnimation> createState() => _ShootingTipsAnimationState();
}

class _ShootingTipsAnimationState extends State<ShootingTipsAnimation>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 动画控制器
  late AnimationController _rotationController;
  late AnimationController _tipsRevealController;

  // 记录上一次的分析状态，用于检测状态变化
  bool _lastIsAnalyzing = false;

  // 记录上一次的tips内容，用于检测内容变化
  List<ShootingTip> _lastTips = [];

  // 追踪渲染阶段
  bool _hasTips = false;
  bool _tipsCirclesRendered = false;

  // 添加放大的tip相关状态
  String? _selectedTipType;
  bool _isTipExpanded = false;
  late AnimationController _expandController;
  late Animation<double> _expandAnimation;

  // 添加控制tips显示的状态
  bool _areTipsVisible = true;
  late AnimationController _tipsVisibilityController;
  late Animation<double> _tipsVisibilityAnimation;

  // 添加拖动相关状态
  Offset _dragPosition = Offset.zero;
  bool _isDragging = false;

  // 判断是否是从后台恢复
  bool _isRestoringState = false;

  // tips配置
  final List<Map<String, dynamic>> _tipsConfig = const [
    {'type': '构图', 'quadrant': '左上', 'angle': 135 * math.pi / 180},
    {'type': '光线', 'quadrant': '右上', 'angle': 45 * math.pi / 180},
    {'type': '动作', 'quadrant': '右下', 'angle': -45 * math.pi / 180},
    {'type': '角度', 'quadrant': '左下', 'angle': -135 * math.pi / 180},
  ];

  @override
  void initState() {
    super.initState();

    // 添加应用生命周期观察者
    WidgetsBinding.instance.addObserver(this);

    // 初始化旋转动画控制器 - 设置为4秒，确保4个tips均匀渲染
    _rotationController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    );

    // 初始化tips显示动画控制器
    _tipsRevealController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          setState(() {
            _tipsCirclesRendered = true;
          });
        }
      });

    // 初始化放大动画控制器
    _expandController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeOutCubic,
    );

    // 初始化tips显示/隐藏动画控制器
    _tipsVisibilityController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _tipsVisibilityAnimation = CurvedAnimation(
      parent: _tipsVisibilityController,
      curve: Curves.easeInOut,
    );

    // 检查应用是否是从后台恢复
    _checkIfRestoringFromBackground();

    // 延迟检查初始状态，避免在构建过程中调用setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndUpdateState();
    });
  }

  // 监听应用生命周期变化
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // 应用进入后台，保存当前状态
      debugPrint('应用进入后台，保存当前状态');
      _saveState();
    } else if (state == AppLifecycleState.resumed) {
      // 应用从后台恢复，标记为正在恢复状态
      debugPrint('应用从后台恢复');
      _isRestoringState = true;
      _loadSavedState();
    }
  }

  // 检查应用是否是从后台恢复
  Future<void> _checkIfRestoringFromBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 检查是否存在保存的状态
      final hasSavedState = prefs.getBool('tips_was_in_background') ?? false;

      if (hasSavedState) {
        // 如果有保存的状态，则加载状态
        _isRestoringState = true;
        await _loadSavedState();
        // 加载完后重置标记
        await prefs.setBool('tips_was_in_background', false);
      } else {
        _isRestoringState = false;
      }
    } catch (e) {
      debugPrint('检查是否从后台恢复出错: $e');
    }
  }

  @override
  void didUpdateWidget(ShootingTipsAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 只有当没有在恢复状态的时候，才正常更新状态
    if (!_isRestoringState) {
      _checkAndUpdateState();
    } else {
      // 恢复完成后，重置标记
      _isRestoringState = false;
    }
  }

  // 从SharedPreferences加载保存的状态
  Future<void> _loadSavedState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 加载有无tips状态
      final hasTips = prefs.getBool('tips_hasTips') ?? false;

      // 只有在有tips的情况下才恢复其他状态
      if (hasTips) {
        setState(() {
          _hasTips = hasTips;

          // 加载tips显示/隐藏状态
          _areTipsVisible = prefs.getBool('tips_areTipsVisible') ?? true;

          // 加载tips位置
          final dragX = prefs.getDouble('tips_dragPositionX') ?? 0.0;
          final dragY = prefs.getDouble('tips_dragPositionY') ?? 0.0;
          if (dragX != 0.0 || dragY != 0.0) {
            _dragPosition = Offset(dragX, dragY);
          }

          // 根据加载的状态设置动画控制器
          if (!_areTipsVisible) {
            _tipsVisibilityController.value = 1.0; // 如果tips是隐藏状态，设置动画值为终点
          }
        });

        debugPrint(
            '已加载tips状态: hasTips=$_hasTips, visible=$_areTipsVisible, position=$_dragPosition');
      }
    } catch (e) {
      debugPrint('加载tips状态失败: $e');
    }
  }

  // 保存当前状态到SharedPreferences
  Future<void> _saveState() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 标记应用处于后台
      await prefs.setBool('tips_was_in_background', true);

      // 保存有无tips状态
      await prefs.setBool('tips_hasTips', _hasTips);

      // 只有在有tips的情况下才保存其他状态
      if (_hasTips) {
        // 保存tips显示/隐藏状态
        await prefs.setBool('tips_areTipsVisible', _areTipsVisible);

        // 保存tips位置
        await prefs.setDouble('tips_dragPositionX', _dragPosition.dx);
        await prefs.setDouble('tips_dragPositionY', _dragPosition.dy);

        // 如果需要，可以保存选中的tip
        if (_selectedTipType != null) {
          await prefs.setString('tips_selectedType', _selectedTipType!);
        } else {
          await prefs.remove('tips_selectedType');
        }

        debugPrint(
            '已保存tips状态: hasTips=$_hasTips, visible=$_areTipsVisible, position=$_dragPosition');
      }
    } catch (e) {
      debugPrint('保存tips状态失败: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rotationController.dispose();
    _tipsRevealController.dispose();
    _expandController.dispose();
    _tipsVisibilityController.dispose();
    super.dispose();
  }

  Color _getColorForType(String type) {
    switch (type) {
      case '构图':
        return const Color(0xFF417EC0); // 蓝色
      case '光线':
        return const Color(0xFFF25B5B); // 红色
      case '角度':
        return const Color(0xFF9747FF); // 紫色
      case '动作':
        return const Color(0xFF4FD5A5); // 绿色
      default:
        return Colors.white;
    }
  }

  // 处理Tip被点击
  void _handleTipSelected(String tipType) {
    setState(() {
      _selectedTipType = tipType;
      _isTipExpanded = true;
    });
    _expandController.forward();
  }

  // 重置Tip扩展状态
  void _resetExpandedTip() {
    _expandController.reverse().then((_) {
      setState(() {
        _selectedTipType = null;
        _isTipExpanded = false;
      });
    });
  }

  // 处理中心区域点击，收起/显示tips
  void _toggleTipsVisibility() {
    debugPrint('执行_toggleTipsVisibility方法');
    final oldVisibility = _areTipsVisible;
    setState(() {
      _areTipsVisible = !_areTipsVisible;
    });
    debugPrint('tips可见性变化: $oldVisibility -> $_areTipsVisible');

    // 通知父组件tips可见性变化
    widget.onTipsVisibilityChanged(_areTipsVisible);
    debugPrint('通知父组件tips可见性变化: $_areTipsVisible');

    if (_areTipsVisible) {
      debugPrint('显示tips，反向动画');
      _tipsVisibilityController.reverse();
    } else {
      debugPrint('隐藏tips，正向动画');
      _tipsVisibilityController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    // 计算中心区域最终位置 - 考虑拖动位置
    final screenSize = MediaQuery.of(context).size;
    final defaultCenterY = screenSize.height / 2 - 200 - 30; // 默认位置

    // 当tips隐藏且有拖动时使用拖动位置，否则使用默认位置
    final useCustomPosition =
        _hasTips && !_areTipsVisible && _dragPosition != Offset.zero;

    // 当tips被收起且已经有提示内容时，只显示中心点，不占用全屏
    if (_hasTips && !_areTipsVisible) {
      return Stack(
        children: [
          if (useCustomPosition)
            Positioned(
              left: _dragPosition.dx - 40, // 中心点宽度的一半
              top: _dragPosition.dy - 40, // 中心点高度的一半
              child: _buildCenterWithColorCircle(),
            )
          else
            Positioned(
              left: 0,
              right: 0,
              top: defaultCenterY,
              child: SizedBox(
                height: 400,
                width: screenSize.width,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 中心点和彩色圆环
                    _buildCenterWithColorCircle(),
                  ],
                ),
              ),
            ),
        ],
      );
    }

    // 原有的全屏显示代码 - 只在tips可见时使用
    return Stack(
      children: [
        // 移除磨砂背景，使用透明背景
        Container(
          color: Colors.transparent,
          width: screenSize.width,
          height: screenSize.height,
          child: CustomPaint(
            size: Size(screenSize.width, screenSize.height),
            painter: BackgroundDetailPainter(),
          ),
        ),

        // 如果有选中的tip，显示放大版本
        if (_isTipExpanded && _selectedTipType != null)
          FadeTransition(
            opacity: _expandAnimation,
            child: Center(
              child: GestureDetector(
                onTap: _resetExpandedTip,
                child: _buildExpandedTip(),
              ),
            ),
          )
        else
          // 当tips隐藏且已有拖动位置时，使用绝对位置
          useCustomPosition
              ? Positioned(
                  left: _dragPosition.dx - 40, // 中心点宽度的一半
                  top: _dragPosition.dy - 40, // 中心点高度的一半
                  child: _buildCenterWithColorCircle(),
                )
              : // 否则使用原来的布局方式
              Positioned(
                  left: 0,
                  right: 0,
                  top: defaultCenterY,
                  child: SizedBox(
                    height: 400,
                    width: screenSize.width,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // 外圈白色圆环 - 只在初始状态显示，点击中心恢复tips不显示
                        if ((_areTipsVisible && !_hasTips) ||
                            (!_areTipsVisible && !_hasTips))
                          Container(
                            width: 300,
                            height: 300,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.15),
                                width: 1.5,
                              ),
                            ),
                          ),

                        // 第二圈白色圆环 - 只在初始状态显示，点击中心恢复tips不显示
                        if ((_areTipsVisible && !_hasTips) ||
                            (!_areTipsVisible && !_hasTips))
                          Container(
                            width: 220,
                            height: 220,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withOpacity(0.1),
                                width: 1,
                              ),
                            ),
                          ),

                        // 星星点缀层 - 只在初始状态显示，点击中心恢复tips不显示
                        if ((_areTipsVisible && !_hasTips) ||
                            (!_areTipsVisible && !_hasTips))
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              return CustomPaint(
                                size: const Size(280, 280),
                                painter: StarfieldPainter(
                                  animationValue:
                                      _rotationController.value * math.pi * 2,
                                ),
                              );
                            },
                          ),

                        // 动态虚线圆环 - 只在初始状态显示，点击中心恢复tips不显示
                        if ((_areTipsVisible && !_hasTips) ||
                            (!_areTipsVisible && !_hasTips))
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              return Transform.rotate(
                                angle: _rotationController.value * 2 * math.pi,
                                child: SizedBox(
                                  width: 270,
                                  height: 270,
                                  child: CustomPaint(
                                    painter: DashedCirclePainter(),
                                  ),
                                ),
                              );
                            },
                          ),

                        // 中心点和彩色圆环
                        _buildCenterWithColorCircle(),

                        // 旋转的Tips圈 - 在初始状态或tips需要显示时显示
                        if (_areTipsVisible || !_hasTips)
                          AnimatedBuilder(
                            animation: _rotationController,
                            builder: (context, child) {
                              final screenCenterX = screenSize.width / 2;
                              return _buildTipsWithRotation(screenCenterX);
                            },
                          ),
                      ],
                    ),
                  ),
                ),
      ],
    );
  }

  // 构建放大的Tip
  Widget _buildExpandedTip() {
    if (_selectedTipType == null) return const SizedBox();

    final tip = widget.tips.firstWhere(
      (tip) => tip.type == _selectedTipType,
      orElse: () => ShootingTip(type: _selectedTipType!, text: '', priority: 0),
    );

    final color = _getColorForType(_selectedTipType!);

    return Container(
      width: 300,
      height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF13131A),
        border: Border.all(
          color: color.withOpacity(0.8),
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 20,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _selectedTipType!,
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 1,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _getEnglishTitle(_selectedTipType!),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
              ),
            ),
            const SizedBox(height: 25),
            Text(
              tip.text,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                color: Colors.white,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
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

  Widget _buildTipsWithRotation(double screenCenterX) {
    // 固定中心点坐标
    final containerCenterX = screenCenterX;
    final containerCenterY = 200.0;

    return Stack(
      alignment: Alignment.center,
      children: List.generate(_tipsConfig.length, (index) {
        final config = _tipsConfig[index];
        final tipType = config['type'] as String;
        final angle = config['angle'] as double;

        final tip = widget.tips.firstWhere(
          (tip) => tip.type == tipType,
          orElse: () => ShootingTip(type: tipType, text: '', priority: 0),
        );

        // 计算tip圈在中心圆环四个象限的位置
        final circleSize = 140.0;
        const centerRadius = 170.0;

        // 固定位置
        double x, y;
        switch (config['quadrant']) {
          case '左上':
            x = containerCenterX - centerRadius / math.sqrt(2);
            y = containerCenterY - centerRadius / math.sqrt(2);
            break;
          case '右上':
            x = containerCenterX + centerRadius / math.sqrt(2);
            y = containerCenterY - centerRadius / math.sqrt(2);
            break;
          case '右下':
            x = containerCenterX + centerRadius / math.sqrt(2);
            y = containerCenterY + centerRadius / math.sqrt(2);
            break;
          case '左下':
            x = containerCenterX - centerRadius / math.sqrt(2);
            y = containerCenterY + centerRadius / math.sqrt(2);
            break;
          default:
            x = containerCenterX + centerRadius * math.cos(angle);
            y = containerCenterY + centerRadius * math.sin(angle);
        }

        // 计算透明度 - 精确控制每个tip的出现时间
        double opacity = 0.0;

        if (_hasTips) {
          // 1. 已收到tips内容 - 完全显示
          opacity = 1.0;
        } else if (!_tipsCirclesRendered) {
          // 2. 首次渲染中 - 均匀渲染
          final rotationProgress = _rotationController.value;

          // 计算每个tip的出现阈值，均匀分布在0-1之间
          final appearThreshold = index / _tipsConfig.length;

          // 计算出现持续时间占总时间的比例，确保均匀分布
          final appearDuration = 1.0 / _tipsConfig.length;

          if (rotationProgress >= appearThreshold) {
            // 计算当前tip渲染的进度
            final progress = math.min(
                1.0, (rotationProgress - appearThreshold) / appearDuration);

            // 使用缓动函数使过渡更平滑
            opacity = Curves.easeOut.transform(progress);
          }
        } else {
          // 3. 渲染完成但无内容 - 保持显示
          opacity = 1.0;
        }

        final clampedOpacity = opacity.clamp(0.0, 1.0);

        // 添加显示/隐藏动画
        return AnimatedBuilder(
          animation: _tipsVisibilityAnimation,
          builder: (context, child) {
            // 当收起时，将 tips 向中心收缩
            final animatedPosition = _hasTips && !_areTipsVisible
                ? Offset(
                    containerCenterX,
                    containerCenterY,
                  )
                : Offset(x, y);

            // 当收起时，降低透明度
            final animatedOpacity = _hasTips && !_areTipsVisible
                ? (1.0 - _tipsVisibilityAnimation.value) * clampedOpacity
                : clampedOpacity;

            // 当收起时，缩小尺寸
            final animatedScale = _hasTips && !_areTipsVisible
                ? 1.0 - _tipsVisibilityAnimation.value
                : 1.0;

            return Positioned(
              left: x * (1 - _tipsVisibilityAnimation.value) +
                  containerCenterX * _tipsVisibilityAnimation.value -
                  (circleSize * animatedScale) / 2,
              top: y * (1 - _tipsVisibilityAnimation.value) +
                  containerCenterY * _tipsVisibilityAnimation.value -
                  (circleSize * animatedScale) / 2,
              child: Opacity(
                opacity: animatedOpacity,
                child: Transform.scale(
                  scale: animatedScale,
                  child: TipBubble(
                    type: tipType,
                    content: _hasTips ? tip.text : '',
                    color: _getColorForType(tipType),
                    index: index,
                    pulsate: !_hasTips && _tipsCirclesRendered,
                    onTap: _hasTips ? () => _handleTipSelected(tipType) : null,
                  ),
                ),
              ),
            );
          },
        );
      }),
    );
  }

  // 新方法：构建中心点和彩色圆环，带有拖动功能
  Widget _buildCenterWithColorCircle() {
    // 根据tips是否显示决定圆环大小
    final circleSize = _hasTips && !_areTipsVisible ? 80.0 : 120.0;

    return GestureDetector(
      // 点击处理
      onTap: () {
        if (_hasTips) {
          debugPrint('中心区域被点击：$_hasTips, $_areTipsVisible');
          _toggleTipsVisibility();
        }
      },
      // 长按开始拖动，改为普通拖动，不需要长按
      onPanStart: (details) {
        if (_hasTips && !_areTipsVisible) {
          setState(() {
            _isDragging = true;

            // 如果是第一次拖动，初始化拖动位置为当前位置
            if (_dragPosition == Offset.zero) {
              // 使用当前组件在屏幕上的位置作为初始拖动位置
              final screenSize = MediaQuery.of(context).size;
              final defaultCenterY = screenSize.height / 2 - 200 - 30;
              final screenCenterX = screenSize.width / 2;

              // 使用当前视图中心位置
              _dragPosition = Offset(screenCenterX, defaultCenterY + 200);
            }
          });
        }
      },

      // 拖动更新位置
      onPanUpdate: (details) {
        if (_hasTips && !_areTipsVisible && _isDragging) {
          setState(() {
            // 获取屏幕尺寸，用于限制拖动范围
            final screenSize = MediaQuery.of(context).size;

            // 设置安全区域 - 更严格的限制
            final topLimit = screenSize.height * 0.10; // 顶部安全区域 - 刘海下方
            final bottomLimit = screenSize.height * 0.80; // 底部安全区域 - 相机控制按钮的上边缘

            // 计算新位置
            double newX = _dragPosition.dx + details.delta.dx;
            double newY = _dragPosition.dy + details.delta.dy;

            // 限制位置在安全区域内
            // 考虑到中心点的半径约为25px，边缘额外加10px缓冲
            newX = newX.clamp(35.0, screenSize.width - 35.0);
            newY = newY.clamp(topLimit, bottomLimit);

            // 更新拖动位置
            _dragPosition = Offset(newX, newY);
          });
        }
      },
      // 拖动结束
      onPanEnd: (_) {
        if (_isDragging) {
          setState(() {
            _isDragging = false;
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300), // 添加尺寸变化的动画
        width: circleSize, // 根据状态使用不同尺寸
        height: circleSize, // 根据状态使用不同尺寸
        child: Stack(
          alignment: Alignment.center,
          children: [
            // 动态内圈彩色圆环 - 修改为顺时针旋转 (去掉负号)
            AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return Transform.rotate(
                  angle: _rotationController.value * 2 * math.pi, // 去掉负号，改为顺时针
                  child: SizedBox(
                    width: circleSize,
                    height: circleSize,
                    child: CustomPaint(
                      painter: ColoredCirclePainter(),
                    ),
                  ),
                );
              },
            ),

            // 恢复原来的中心点设计，去掉图标
            Container(
              width: 50, // 中心圆点尺寸
              height: 50, // 中心圆点尺寸
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    Colors.white,
                    Colors.white.withOpacity(0.8),
                  ],
                  stops: const [0.3, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withOpacity(0.5),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
              ),
            ),

            // 中心小圆点
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black,
                border: Border.all(
                  color: Colors.white.withOpacity(0.8),
                  width: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 核心方法：检查状态变化并更新动画
  void _checkAndUpdateState() {
    // 检测"教我拍"按钮点击状态变化
    if (widget.isAnalyzing != _lastIsAnalyzing) {
      if (widget.isAnalyzing) {
        // 开始新的分析 - 重置所有状态
        _startNewAnalysis();
      } else {
        // 分析结束
        _endAnalysis();
      }
      _lastIsAnalyzing = widget.isAnalyzing;
    }

    // 即使uploadState没有变化，但如果isAnalyzing为true，也确保动画正常运行
    if (widget.isAnalyzing && !_rotationController.isAnimating) {
      _rotationController.repeat();

      // 如果tips显示动画未完成，确保它继续运行
      if (!_tipsRevealController.isCompleted &&
          !_tipsRevealController.isAnimating) {
        _tipsRevealController.forward();
      }
    }

    // 检测tips内容变化
    bool tipsChanged = false;
    if (widget.tips.length != _lastTips.length) {
      tipsChanged = true;
    } else {
      for (int i = 0; i < widget.tips.length; i++) {
        if (widget.tips[i].text != _lastTips[i].text) {
          tipsChanged = true;
          break;
        }
      }
    }

    // 如果tips内容有变化且非空
    if (tipsChanged &&
        widget.tips.isNotEmpty &&
        widget.tips.any((tip) => tip.text.isNotEmpty)) {
      setState(() {
        _hasTips = true;
        _lastTips = List.from(widget.tips);
      });

      // 停止旋转动画
      _rotationController.stop();

      // 确保所有tips圈显示完成 - 使用更短的动画时间，加快渲染
      if (!_tipsRevealController.isCompleted) {
        _tipsRevealController.animateTo(1.0,
            duration: const Duration(milliseconds: 200));
      }
    }
  }

  // 开始新的分析流程
  void _startNewAnalysis() {
    debugPrint('开始新的分析流程');
    // 完全重置所有状态
    setState(() {
      _hasTips = false;
      _tipsCirclesRendered = false;
      _lastTips = [];
      // 重要：确保tips始终处于可见状态
      _areTipsVisible = true;
      // 重置拖动位置
      _dragPosition = Offset.zero;
    });

    // 重置tips显示/隐藏控制器
    _tipsVisibilityController.value = 0.0;

    // 延迟通知父组件状态变化，避免在构建过程中调用setState
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // 通知父组件tips变为可见状态
      widget.onTipsVisibilityChanged(true);
      debugPrint('通知父组件重置tips可见性为: true');
    });

    // 停止并重置所有动画，确保从头开始
    _rotationController.stop();
    _rotationController.reset();

    _tipsRevealController.stop();
    _tipsRevealController.reset();

    // 使用短延迟确保状态已重置后再启动动画
    Future.microtask(() {
      if (mounted) {
        _rotationController.repeat(); // 开始旋转
        _tipsRevealController.forward(); // 开始显示tips圈
      }
    });
  }

  // 结束分析流程
  void _endAnalysis() {
    // 如果没有收到tips内容，则停止旋转
    if (!_hasTips) {
      _rotationController.stop();
    }
  }
}

class TipBubble extends StatelessWidget {
  final String type;
  final String content;
  final Color color;
  final int index;
  final bool pulsate;
  final VoidCallback? onTap; // 添加点击回调

  const TipBubble({
    Key? key,
    required this.type,
    required this.content,
    required this.color,
    required this.index,
    required this.pulsate,
    this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bubbleContent = Container(
      width: 140, // 增大尺寸
      height: 140, // 增大尺寸
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: const Color(0xFF13131A),
        border: Border.all(
          color: color.withOpacity(0.8),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(15), // 增加内边距
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              type, // 直接使用中文类型
              style: TextStyle(
                fontSize: 20, // 增大字体
                fontWeight: FontWeight.w600,
                color: Colors.white,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: color.withOpacity(0.7),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10), // 调整间距
            // 移除reset按钮，直接显示内容
            if (content.isNotEmpty)
              Expanded(
                child: Text(
                  content,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.8),
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );

    // 添加发光边缘效果并根据状态决定是否应用脉动动画
    Widget result = Container(
      width: 145, // 调整外圈尺寸
      height: 145, // 调整外圈尺寸
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: bubbleContent,
    );

    // 应用缩放动画
    result = result.animate().scale(
          begin: const Offset(0.7, 0.7),
          end: const Offset(1.0, 1.0),
          curve: Curves.easeOutBack,
          duration: 600.ms,
        );

    // 如果在等待中，添加边缘发光的呼吸效果
    if (pulsate) {
      result = result
          .animate(
            onPlay: (controller) => controller.repeat(reverse: true),
          )
          .custom(
            duration: 1500.ms,
            builder: (context, value, child) {
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: color.withOpacity(0.3 + value * 0.4),
                      blurRadius: 15 + value * 10,
                      spreadRadius: 1 + value * 2,
                    ),
                  ],
                ),
                child: child,
              );
            },
          );
    }

    // 添加点击手势
    if (onTap != null) {
      result = GestureDetector(
        onTap: onTap,
        child: result,
      );
    }

    return result;
  }
}

class StarfieldPainter extends CustomPainter {
  // 添加一个变量来控制画面随时间变化
  final double animationValue;

  // 构造函数接收动画值
  StarfieldPainter({this.animationValue = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = size.width / 6;

    final random = math.Random(42);
    final starPaint = Paint()..style = PaintingStyle.fill;

    // 预定义一些彩色星星的颜色
    final starColors = [
      Colors.white,
      const Color(0xFF88C0FF), // 淡蓝色
      const Color(0xFFFFB1B1), // 淡红色
      const Color(0xFFD0B3FF), // 淡紫色
      const Color(0xFFA7FFD6), // 淡绿色
    ];

    // 减少星星数量从120个到60个，减轻渲染负担
    for (int i = 0; i < 60; i++) {
      final angle = random.nextDouble() * math.pi * 2;
      final distance =
          minRadius + random.nextDouble() * (maxRadius - minRadius);
      final x = center.dx + math.cos(angle) * distance;
      final y = center.dy + math.sin(angle) * distance;

      // 使用随机数加上动画值，创造出随机闪烁的效果
      // 降低闪烁频率，从0.5改为0.25
      final timeOffset = random.nextDouble() * math.pi * 2;
      final flickerValue =
          (math.sin(animationValue * 0.25 + timeOffset) + 1) / 2; // 0到1的值

      final brightness =
          0.2 + random.nextDouble() * 0.8 * (0.7 + flickerValue * 0.3);
      final starSize = 0.5 + random.nextDouble() * 2.0;

      // 随机选择一种颜色，并且根据闪烁值选择性地应用彩色效果
      Color starColor;

      if (random.nextDouble() > 0.7 && flickerValue > 0.6) {
        // 30%的星星会显示彩色，而且只在亮度高的时候
        final colorIndex = random.nextInt(starColors.length);
        starColor = starColors[colorIndex];
      } else {
        // 大多数星星保持白色
        starColor = Colors.white;
      }

      starPaint.color = starColor.withOpacity(brightness);
      canvas.drawCircle(Offset(x, y), starSize, starPaint);

      // 减少光晕星星的数量，从20%到10%
      if (random.nextDouble() > 0.9) {
        canvas.drawCircle(
            Offset(x, y),
            starSize * 2 * (0.8 + flickerValue * 0.4),
            Paint()
              ..color = starColor.withOpacity(brightness * 0.3 * flickerValue));
      }
    }
  }

  @override
  bool shouldRepaint(covariant StarfieldPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}

class BackgroundDetailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.15)
      ..style = PaintingStyle.fill;

    // 减少背景点数量从200到100
    final random = math.Random(42);
    for (int i = 0; i < 100; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final radius = random.nextDouble() * 1.5;

      canvas.drawCircle(
        Offset(x, y),
        radius,
        dotPaint
          ..color = Colors.white.withOpacity(0.05 + random.nextDouble() * 0.15),
      );
    }

    // 添加光晕
    final center = Offset(size.width / 2, size.height / 2);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withOpacity(0.1),
          Colors.transparent,
        ],
        stops: const [0.2, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: size.width * 0.6));

    canvas.drawCircle(center, size.width * 0.6, glowPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 外圈虚线
    final outerPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // 减少虚线点的数量从100到60
    final dashCount = 60;
    for (var i = 0; i < dashCount; i++) {
      final startAngle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        math.pi / (dashCount * 1.8),
        false,
        outerPaint,
      );
    }

    // 减少内圈虚线点数量
    for (var i = 0; i < dashCount; i += 4) {
      // 从i+=3改为i+=4
      final startAngle = (i * 2 * math.pi) / dashCount;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.6),
        startAngle,
        math.pi / (dashCount * 1.5),
        false,
        outerPaint..color = Colors.white.withOpacity(0.2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class ColoredCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 绘制彩色弧形
    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    const int segmentCount = 4;
    final colors = [
      const Color(0xFF417EC0), // 蓝色
      const Color(0xFFF25B5B), // 红色
      const Color(0xFF9747FF), // 紫色
      const Color(0xFF4FD5A5), // 绿色
    ];

    for (int i = 0; i < segmentCount; i++) {
      final startAngle = i * (2 * math.pi / segmentCount);
      final sweepAngle = (2 * math.pi / segmentCount) * 0.7;

      progressPaint.color = colors[i];
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
