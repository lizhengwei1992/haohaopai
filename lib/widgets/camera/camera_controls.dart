import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import 'dart:io';
import '../../widgets/camera/camera_filters.dart';
import '../../widgets/camera/camera_control_icons.dart';

class CameraControls extends StatefulWidget {
  final VoidCallback onTeachPress;
  final VoidCallback onCapturePress;
  final VoidCallback onGalleryPress;
  final VoidCallback onSwitchCameraPress;
  final VoidCallback onToggleFlash;
  final bool isFlashOn;
  final bool showingTips;
  final String currentAspectRatio;
  final Function(String) onAspectRatioChange;
  final Function(double) onExposureChange;
  final Function(String) onFilterChange;
  final FilterType currentFilter;
  final bool showFilterSelector;

  const CameraControls({
    super.key,
    required this.onTeachPress,
    required this.onCapturePress,
    required this.onGalleryPress,
    required this.onSwitchCameraPress,
    required this.onToggleFlash,
    required this.isFlashOn,
    this.showingTips = false,
    this.currentAspectRatio = '4:3',
    required this.onAspectRatioChange,
    required this.onExposureChange,
    required this.onFilterChange,
    this.currentFilter = FilterType.none,
    this.showFilterSelector = false,
  });

  @override
  State<CameraControls> createState() => CameraControlsState();
}

class CameraControlsState extends State<CameraControls> {
  late String _currentAspectRatio;
  double _currentExposure = 0.0;
  String _currentFilter = '无';

  // 控制面板展开状态
  String? _expandedControl;

  // 拍摄比例选项
  final List<String> _aspectRatioOptions = ['4:3', '1:1', '16:9'];

  // 滤镜选项
  final List<String> _filters = ['无', '自然', '鲜艳', '冷色', '暖色', '黑白'];

  @override
  void initState() {
    super.initState();
    _currentAspectRatio = widget.currentAspectRatio;
  }

  @override
  void didUpdateWidget(CameraControls oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果父组件传入的比例发生变化，更新当前比例
    if (widget.currentAspectRatio != oldWidget.currentAspectRatio) {
      debugPrint('父组件传入新的拍摄比例: ${widget.currentAspectRatio}');
      setState(() {
        _currentAspectRatio = widget.currentAspectRatio;
      });
    }
  }

  // 公共方法：关闭展开面板
  void closeExpandedPanel() {
    if (_expandedControl != null) {
      setState(() {
        _expandedControl = null;
      });
    }
  }

  // 设置当前比例并更新UI
  void _setAspectRatio(String ratio) {
    debugPrint('正在设置拍摄比例: $ratio，当前比例: $_currentAspectRatio');

    // 无论是否相同，都强制更新，以确保数据同步
    setState(() {
      _currentAspectRatio = ratio;
    });

    // 通知父组件
    widget.onAspectRatioChange(ratio);

    debugPrint('拍摄比例已更新为: $ratio');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      // 移除SafeArea，使用Padding代替，允许按钮下移
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end, // 确保内容靠近底部
        mainAxisSize: MainAxisSize.min,
        children: [
          // 控制按钮行 - 包含展开的控制面板
          Padding(
            padding:
                const EdgeInsets.only(bottom: 45.0), // 增加底部间距从35改为45，使按钮上移10px
            child: Center(
              // 添加Center包装，确保容器居中
              child: GestureDetector(
                // 添加手势检测器，捕获面板上的点击事件，阻止事件冒泡
                onTap: () {
                  // 点击事件被消费，不会传递到外层
                  debugPrint('点击控制面板内部区域');
                },
                child: _expandedControl != null
                    ? _buildExpandedRow() // 展开状态显示扩展行
                    : _buildControlButtonsRow(), // 正常状态显示四个按钮
              ),
            ),
          ),

          // 拍摄按钮行
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0), // 保持底部间距
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 左侧预览相册按钮
                Consumer<CameraProvider>(
                  builder: (context, provider, child) {
                    final hasRecentPhotos = provider.recentPhotos.isNotEmpty;

                    return GestureDetector(
                      onTap: widget.onGalleryPress,
                      child: Container(
                        width: 38, // 将宽度从40缩小到38
                        height: 38, // 将高度从40缩小到38
                        margin:
                            const EdgeInsets.only(right: 28), // 调整右边距从30改为28
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: hasRecentPhotos
                            ? ClipOval(
                                child: Image.file(
                                  File(provider.recentPhotos.first.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.photo_library,
                                      color: Colors.white,
                                      size: 18, // 将尺寸从20缩小到18
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 18, // 将尺寸从20缩小到18
                              ),
                      ),
                    );
                  },
                ),

                // 中间拍摄按钮
                _buildCaptureButton(),

                // 为了保持布局平衡，添加一个空的占位容器，宽度与左侧按钮相同
                Container(
                  width: 38, // 将宽度从40缩小到38
                  height: 38, // 将高度从40缩小到38
                  margin: const EdgeInsets.only(left: 28), // 调整左边距从30改为28
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建正常状态下的四个控制按钮行
  Widget _buildControlButtonsRow() {
    // 如果滤镜选择器已打开，不显示任何控制按钮
    if (widget.showFilterSelector) {
      return const SizedBox.shrink(); // 返回一个空的小部件
    }

    // 正常状态下显示所有按钮（使用简洁的样式）
    return Container(
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 闪光灯按钮
          CameraControlButton(
            onTap: widget.onToggleFlash, // 实现闪光灯按钮点击效果
            child: FlashIcon(isOn: widget.isFlashOn),
          ),

          // 曝光按钮
          CameraControlButton(
            onTap: () {
              setState(() {
                _expandedControl = 'exposure';
              });
            },
            child: const ExposureIcon(),
          ),

          // 画面比例按钮
          CameraControlButton(
            onTap: () {
              setState(() {
                _expandedControl = 'aspectRatio';
              });
            },
            child: AspectRatioIcon(
              ratio: _currentAspectRatio,
              isSelected: true, // 控制按钮中的比例图标始终显示为选中状态
            ),
          ),

          // 滤镜按钮
          CameraControlButton(
            onTap: () {
              widget.onFilterChange('toggle'); // 使用特殊值'toggle'来表示切换滤镜选择器
            },
            child: const FilterIcon(),
          ),
        ],
      ),
    );
  }

  // 构建展开状态下的行
  Widget _buildExpandedRow() {
    // 滤镜模式下不显示展开行
    if (widget.showFilterSelector) {
      return _buildControlButtonsRow();
    }

    if (_expandedControl == 'aspectRatio') {
      return Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.8, // 设置为屏幕宽度的80%
          height: 50, // 固定高度为50
          decoration: BoxDecoration(
            color: Color.fromRGBO(120, 120, 120, 0.6), // 灰色半透明背景
            borderRadius: BorderRadius.circular(25), // 圆角矩形
          ),
          child: Row(
            children: [
              // 左侧当前选中项，普通文本
              Container(
                width: 60,
                margin: EdgeInsets.symmetric(horizontal: 12),
                child: Center(
                  child: Text(
                    _currentAspectRatio,
                    style: TextStyle(
                      color: Colors.yellow, // 左侧当前选中项始终显示为黄色
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // 分隔线
              Container(
                width: 1,
                height: 30,
                color: Colors.white.withOpacity(0.3),
              ),

              // 右侧所有选项
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _aspectRatioOptions.map((ratio) {
                    final bool isSelected = ratio == _currentAspectRatio;

                    return GestureDetector(
                      onTap: () {
                        debugPrint('点击了比例选项: $ratio');
                        // 更新比例
                        _setAspectRatio(ratio);
                        // 关闭面板
                        setState(() {
                          _expandedControl = null;
                        });
                        debugPrint('面板已关闭，当前比例: $_currentAspectRatio');
                      },
                      child: Container(
                        width: 38,
                        height: 38,
                        margin: EdgeInsets.symmetric(horizontal: 4),
                        child: Center(
                          child: AspectRatioIcon(
                            ratio: ratio,
                            isSelected: isSelected,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (_expandedControl == 'exposure') {
      return GestureDetector(
        // 添加手势检测器，捕获曝光面板上的点击事件，阻止事件冒泡
        onTap: () {
          // 点击事件被消费，不会传递到外层
          debugPrint('点击曝光控制面板内部区域');
        },
        child: Container(
          width: MediaQuery.of(context).size.width,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 曝光值指示器
              Container(
                width: double.infinity,
                height: 24,
                alignment: Alignment.center,
                child: Text(
                  _currentExposure.toStringAsFixed(1),
                  style: TextStyle(
                    color: Colors.yellow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // 自定义曝光控制器 - 居中显示并设置为屏幕宽度的80%
              Center(
                child: Container(
                  width: MediaQuery.of(context).size.width * 0.8, // 设置为屏幕宽度的80%
                  child: ExposureControl(
                    value: _currentExposure,
                    onChanged: (value) {
                      setState(() {
                        _currentExposure = value;
                      });
                      widget.onExposureChange(value);
                    },
                    onChangeEnd: () {
                      // 移除自动关闭功能，允许用户继续调整而不会自动关闭
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 默认返回普通控制按钮行
    return _buildControlButtonsRow();
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: widget.showingTips ? widget.onCapturePress : widget.onTeachPress,
      child: Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// 自定义曝光控制组件
class ExposureControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  const ExposureControl({
    Key? key,
    required this.value,
    required this.onChanged,
    required this.onChangeEnd,
  }) : super(key: key);

  @override
  State<ExposureControl> createState() => _ExposureControlState();
}

class _ExposureControlState extends State<ExposureControl> {
  late double _startDragX;
  late double _currentValue;
  bool _isDragging = false;
  double _lastProcessedValue = 0.0;
  static const _minDragThreshold = 3.0; // 最小拖动阈值，低于此值不响应

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _lastProcessedValue = widget.value;
  }

  // 将值四舍五入到最近的刻度线
  double _roundToNearestTick(double value) {
    // 刻度间隔为0.2（从-2.0到2.0，总共21个刻度）
    const double tickInterval = 0.2;
    return (value / tickInterval).round() * tickInterval;
  }

  void _updateValue(double dx) {
    // 计算拖动的相对距离，转换为曝光值变化
    final double controlWidth =
        MediaQuery.of(context).size.width * 0.8; // 控件宽度为屏幕宽度的80%
    final double dragDistance = dx - _startDragX;

    // 如果拖动距离太小，忽略这次更新
    if (dragDistance.abs() < _minDragThreshold) {
      return;
    }

    // 将拖动距离映射到曝光值变化
    // 进一步降低灵敏度：控件宽度的1/2对应1.0的曝光值变化
    final double valueChange = dragDistance / (controlWidth / 2);

    // 计算新的曝光值
    double newValue = _currentValue + valueChange;

    // 限制在-2.0到2.0范围内
    newValue = newValue.clamp(-2.0, 2.0);

    // 如果值变化不大，不更新
    if ((newValue - _lastProcessedValue).abs() < 0.05) {
      return;
    }

    // 更新上次处理的值
    _lastProcessedValue = newValue;

    // 更新UI并调用回调，但不四舍五入，拖动过程中平滑变化
    setState(() {
      _currentValue = newValue;
    });
    widget.onChanged(newValue);

    // 重新设置起始位置，防止连续的小移动累积成大变化
    _startDragX = dx;
  }

  // 拖动结束时四舍五入到最近的刻度
  void _finalizeValue() {
    // 将当前值四舍五入到最近的刻度值
    final double roundedValue = _roundToNearestTick(_currentValue);

    // 如果四舍五入后的值与当前值不同，更新并通知
    if (roundedValue != _currentValue) {
      setState(() {
        _currentValue = roundedValue;
        _lastProcessedValue = roundedValue;
      });
      widget.onChanged(roundedValue);
    }
  }

  // 根据点击位置计算相应的曝光值
  double _getValueFromPosition(double x) {
    final double width =
        MediaQuery.of(context).size.width * 0.8; // 控件宽度为屏幕宽度的80%

    // 计算刻度线位置
    final int tickCount = 21; // 总共21个刻度(中间±10)
    final double tickSpacing = width / (tickCount - 1);

    // 找到最近的刻度线索引
    int nearestTickIndex = ((x / tickSpacing).round()).clamp(0, tickCount - 1);

    // 计算对应的曝光值 (-2.0到2.0)
    return ((nearestTickIndex - (tickCount ~/ 2)) * 0.2).clamp(-2.0, 2.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: (details) {
        _startDragX = details.localPosition.dx;
        _currentValue = widget.value;
        _lastProcessedValue = widget.value;
        setState(() {
          _isDragging = true;
        });
      },
      onHorizontalDragUpdate: (details) {
        _updateValue(details.localPosition.dx);
      },
      onHorizontalDragEnd: (details) {
        // 结束拖动时四舍五入到最近的刻度
        _finalizeValue();

        setState(() {
          _isDragging = false;
        });
        widget.onChangeEnd();
      },
      onTapDown: (details) {
        final double clickPosition = details.localPosition.dx;

        // 直接点击刻度线设置曝光值
        final double newValue = _getValueFromPosition(clickPosition);

        // 更新UI并调用回调
        setState(() {
          _currentValue = newValue;
          _lastProcessedValue = newValue;
        });
        widget.onChanged(newValue);
      },
      onTapUp: (details) {
        widget.onChangeEnd();
      },
      child: Container(
        width: double.infinity,
        height: 60,
        color: Colors.transparent,
        child: CustomPaint(
          painter: ExposureControlPainter(
            value: widget.value,
            isDragging: _isDragging,
          ),
        ),
      ),
    );
  }
}

// 自定义绘制曝光控制器UI
class ExposureControlPainter extends CustomPainter {
  final double value;
  final bool isDragging;

  ExposureControlPainter({
    required this.value,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;
    final double center = width / 2;

    // 刻度线基本设置
    final int tickCount = 21; // 总共21个刻度(中间±10)
    final double tickSpacing = width / (tickCount - 1);

    // 计算当前值对应的刻度索引
    final double valueInTicks = value / 0.2 + tickCount ~/ 2; // 0.2是刻度间隔
    final int currentTickIndex = valueInTicks.round().clamp(0, tickCount - 1);

    // 画笔设置
    final Paint linePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final Paint highlightPaint = Paint()
      ..color = Colors.yellow
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    // 绘制刻度线
    for (int i = 0; i < tickCount; i++) {
      final double x = i * tickSpacing;
      final bool isCenter = i == tickCount ~/ 2;
      final bool isCurrentValue = i == currentTickIndex;

      double tickHeight;
      if (isCenter) {
        // 中间刻度线高度为控件高度的60%
        tickHeight = height * 0.6;
      } else {
        // 两侧刻度线高度为中间刻度线的1/3，大约20%的控件高度
        tickHeight = height * 0.2;
      }

      final double startY = (height - tickHeight) / 2;
      final double endY = startY + tickHeight;

      // 决定使用哪种画笔
      Paint currentPaint;
      if (isCurrentValue && !isCenter) {
        // 当前值对应的刻度线使用黄色
        currentPaint = highlightPaint;
      } else if (isCenter && value.abs() < 0.05) {
        // 只有当值接近0时，中心刻度线才使用黄色
        currentPaint = highlightPaint;
      } else {
        // 其他刻度线使用白色
        currentPaint = linePaint;
      }

      // 绘制刻度线
      canvas.drawLine(
        Offset(x, startY),
        Offset(x, endY),
        currentPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant ExposureControlPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDragging != isDragging;
  }
}
