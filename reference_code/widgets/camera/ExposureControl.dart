import 'package:flutter/material.dart';

class ExposureControl extends StatefulWidget {
  final Function(double) onChanged;

  const ExposureControl({Key? key, required this.onChanged}) : super(key: key);

  @override
  _ExposureControlState createState() => _ExposureControlState();
}

class _ExposureControlState extends State<ExposureControl> {
  double _currentValue = 0.0;
  double _startDragX = 0.0;
  double _lastProcessedValue = 0.0;
  final double _minDragThreshold = 10.0; // Define _minDragThreshold

  void _updateValue(double dx) {
    // 计算拖动的相对距离，转换为曝光值变化
    final double controlWidth =
        MediaQuery.of(context).size.width * 0.55; // 控件宽度为屏幕宽度的55%
    final double dragDistance = dx - _startDragX;

    // 如果拖动距离太小，忽略这次更新
    if (dragDistance.abs() < _minDragThreshold) {
      return;
    }

    // 将拖动距离映射到曝光值变化
    // 降低灵敏度：控件宽度的2/3对应1.0的曝光值变化
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

    // 更新UI并调用回调，但不四舍五入，拖动过程中平滑变化
    setState(() {
      _currentValue = newValue;
    });
    widget.onChanged(newValue);

    // 重新设置起始位置，防止连续的小移动累积成大变化
    _startDragX = dx;
  }

  // 根据点击位置计算相应的曝光值
  double _getValueFromPosition(double x) {
    final double width =
        MediaQuery.of(context).size.width * 0.55; // 控件宽度为屏幕宽度的55%
    // Implementation of _getValueFromPosition method
    return 0.0; // Placeholder return, actual implementation needed
  }

  @override
  Widget build(BuildContext context) {
    // Implementation of build method
    return Container(); // Placeholder return, actual implementation needed
  }
}
