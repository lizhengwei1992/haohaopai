import 'package:flutter/material.dart';

class ZoomControl extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final Function(double) onZoomChanged;

  const ZoomControl({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    // 准备固定缩放选项（仅保留1×、2×、3×三个固定选项）
    final List<Map<String, dynamic>> fixedZoomOptions = [
      {'level': 1.0, 'label': '1×'},
      {'level': 2.0, 'label': '2×'},
      {'level': 3.0, 'label': '3×'},
    ];

    // 找出当前缩放值是否等于某个固定选项
    bool isFixedLevel = false;
    int fixedLevelIndex = -1;

    for (int i = 0; i < fixedZoomOptions.length; i++) {
      double level = fixedZoomOptions[i]['level'] as double;
      if ((currentZoom - level).abs() < 0.05) {
        isFixedLevel = true;
        fixedLevelIndex = i;
        break;
      }
    }

    // 格式化当前缩放值（保留一位小数）
    String currentZoomText = currentZoom.toStringAsFixed(1) + '×';

    // 处理显示为整数的情况
    if (currentZoom.toInt() == currentZoom) {
      currentZoomText = currentZoom.toInt().toString() + '×';
    }

    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Color.fromRGBO(80, 80, 80, 0.2), // 底层背景色透明度更低
            borderRadius: BorderRadius.circular(40), // 大圆角，接近圆形
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 当前实时缩放值（第一个位置）
              _buildRealTimeZoomOption(currentZoomText, !isFixedLevel),
              SizedBox(width: 6), // 添加间距

              // 三个固定选项
              for (int i = 0; i < fixedZoomOptions.length; i++) ...[
                _buildZoomOption(
                  fixedZoomOptions[i]['level'] as double,
                  fixedZoomOptions[i]['label'] as String,
                  isFixedLevel && i == fixedLevelIndex,
                ),
                if (i < fixedZoomOptions.length - 1)
                  SizedBox(width: 6), // 选项之间的间距
              ],
            ],
          ),
        ),
      ),
    );
  }

  // 实时缩放选项 - 完全圆形
  Widget _buildRealTimeZoomOption(String label, bool isHighlighted) {
    final textStyle = TextStyle(
      color: isHighlighted ? Colors.yellow : Colors.white,
      fontSize: 14,
      fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
    );

    return Container(
      width: 32, // 固定宽度
      height: 32, // 固定高度
      decoration: BoxDecoration(
        shape: BoxShape.circle, // 完全圆形
        color: isHighlighted
            ? Color.fromRGBO(100, 100, 100, 0.5) // 选中状态背景色
            : Colors.transparent, // 未选中时保持透明
      ),
      child: Center(
        child: Text(
          label,
          style: textStyle,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // 固定缩放选项 - 完全圆形
  Widget _buildZoomOption(double zoomLevel, String label, bool isSelected) {
    final textStyle = TextStyle(
      color: isSelected ? Colors.yellow : Colors.white,
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    );

    return GestureDetector(
      onTap: () => onZoomChanged(zoomLevel),
      child: Container(
        width: 32, // 固定宽度
        height: 32, // 固定高度
        decoration: BoxDecoration(
          shape: BoxShape.circle, // 完全圆形
          color: isSelected
              ? Color.fromRGBO(100, 100, 100, 0.5) // 选中状态背景色
              : Colors.transparent, // 未选中时保持透明
        ),
        child: Center(
          child: Text(
            label,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
