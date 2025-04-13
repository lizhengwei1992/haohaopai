import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';

/// 曝光控制组件
class ExposureControl extends StatefulWidget {
  const ExposureControl({Key? key}) : super(key: key);

  @override
  State<ExposureControl> createState() => _ExposureControlState();
}

class _ExposureControlState extends State<ExposureControl> {
  // 切换展开面板状态
  void _toggleExpanded() {
    final cameraState = CameraStateManager.instance;

    // 切换展开状态
    cameraState.isExposureControlExpanded =
        !cameraState.isExposureControlExpanded;

    // 如果开启了面板，监听屏幕点击事件以便关闭面板
    if (cameraState.isExposureControlExpanded) {
      // 使用Future.delayed以确保展开面板已经显示出来
      Future.delayed(Duration.zero, () {
        // 监听全局点击，直到下一个帧渲染前
        GestureBinding.instance.pointerRouter
            .addGlobalRoute((PointerEvent event) {
          // 如果是点击事件（抬起手指时），关闭面板
          if (event is PointerUpEvent) {
            // 移除监听器，避免重复触发
            GestureBinding.instance.pointerRouter
                .removeGlobalRoute((PointerEvent event) {});

            // 确保面板仍然展开时才关闭
            if (cameraState.isExposureControlExpanded) {
              // 使用Future.microtask确保在UI渲染后执行
              Future.microtask(() {
                cameraState.isExposureControlExpanded = false;
              });
            }
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    return AnimatedBuilder(
      animation: cameraState,
      builder: (context, child) {
        return cameraState.isExposureControlExpanded
            ? _buildExpandedPanel(context, cameraState.currentExposureValue)
            : _buildExposureButton();
      },
    );
  }

  // 构建曝光按钮（未展开状态）
  Widget _buildExposureButton() {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/exposure.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }

  // 构建展开的曝光控制面板
  Widget _buildExpandedPanel(BuildContext context, double currentValue) {
    return GestureDetector(
      // 捕获面板上的点击事件，阻止事件冒泡
      onTap: () {
        debugPrint('点击曝光控制面板内部区域');
      },
      child: Container(
        width: MediaQuery.of(context).size.width,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        height: 40,
        child: Stack(
          children: [
            // 曝光控制器 - 居中显示
            Center(
              child: Container(
                width: MediaQuery.of(context).size.width * 0.55,
                height: 40,
                child: _ExposureSlider(
                  value: currentValue,
                  onChanged: (value) {
                    // 更新曝光值
                    CameraStateManager.instance.setExposure(value);
                  },
                ),
              ),
            ),

            // 曝光值指示器 - 右侧显示
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    currentValue.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.yellow,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自定义曝光滑动控制组件
class _ExposureSlider extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _ExposureSlider({
    Key? key,
    required this.value,
    required this.onChanged,
  }) : super(key: key);

  @override
  _ExposureSliderState createState() => _ExposureSliderState();
}

class _ExposureSliderState extends State<_ExposureSlider> {
  late double _startDragX;
  late double _currentValue;
  bool _isDragging = false;
  double _lastProcessedValue = 0.0;
  static const _minDragThreshold = 3.0; // 最小拖动阈值

  @override
  void initState() {
    super.initState();
    _currentValue = widget.value;
    _lastProcessedValue = widget.value;
  }

  // 将值四舍五入到最近的刻度线
  double _roundToNearestTick(double value) {
    const double tickInterval = 4.0 / 18; // 总共19个刻度(-2.0到2.0)
    return (value / tickInterval).round() * tickInterval;
  }

  // 更新曝光值
  void _updateValue(double dx) {
    // 计算拖动的相对距离，转换为曝光值变化
    final double controlWidth = MediaQuery.of(context).size.width * 0.55;
    final double dragDistance = dx - _startDragX;

    // 如果拖动距离太小，忽略这次更新
    if (dragDistance.abs() < _minDragThreshold) {
      return;
    }

    // 将拖动距离映射到曝光值变化
    final double valueChange = dragDistance / (controlWidth * 2 / 3);

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

    // 更新UI并调用回调
    setState(() {
      _currentValue = newValue;
    });
    widget.onChanged(newValue);

    // 重新设置起始位置，防止连续的小移动累积成大变化
    _startDragX = dx;
  }

  // 拖动结束时四舍五入到最近的刻度
  void _finalizeValue() {
    final double roundedValue = _roundToNearestTick(_currentValue);

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
    final double width = MediaQuery.of(context).size.width * 0.55;

    // 计算刻度线位置
    final int tickCount = 19; // 总共19个刻度(中间±9)
    final double tickSpacing = width / (tickCount - 1);

    // 找到最近的刻度线索引
    int nearestTickIndex = ((x / tickSpacing).round()).clamp(0, tickCount - 1);

    // 计算对应的曝光值 (-2.0到2.0)
    return (((nearestTickIndex - (tickCount ~/ 2)) * 4.0) / (tickCount - 1))
        .clamp(-2.0, 2.0);
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
      },
      onTapDown: (details) {
        final double clickPosition = details.localPosition.dx;
        final double newValue = _getValueFromPosition(clickPosition);

        setState(() {
          _currentValue = newValue;
          _lastProcessedValue = newValue;
        });
        widget.onChanged(newValue);
      },
      child: Container(
        width: double.infinity,
        height: 40,
        color: Colors.transparent,
        child: CustomPaint(
          painter: _ExposureSliderPainter(
            value: _currentValue,
            isDragging: _isDragging,
          ),
        ),
      ),
    );
  }
}

/// 自定义绘制曝光滑动条UI
class _ExposureSliderPainter extends CustomPainter {
  final double value;
  final bool isDragging;

  _ExposureSliderPainter({
    required this.value,
    this.isDragging = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    // 刻度线基本设置
    final int tickCount = 19; // 总共19个刻度(中间±9)
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
        // 中间刻度线高度更高
        tickHeight = height * 0.45;
      } else {
        // 两侧刻度线高度较低
        tickHeight = height * 0.15;
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
  bool shouldRepaint(covariant _ExposureSliderPainter oldDelegate) {
    return oldDelegate.value != value || oldDelegate.isDragging != isDragging;
  }
}
