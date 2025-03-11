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
    // 准备固定缩放选项：1x、2x、5x
    final List<Map<String, dynamic>> zoomOptions = [
      {'level': 1.0, 'label': '1×'},
      {'level': 2.0, 'label': '2×'},
      {'level': 5.0, 'label': '5×'},
    ];

    // 格式化当前缩放值显示
    String currentZoomLabel = '${currentZoom.toStringAsFixed(1)}×';

    // 检查当前缩放值是否接近某个固定选项
    bool isFixedZoomLevel = zoomOptions.any(
        (option) => (currentZoom - option['level'] as double).abs() < 0.05);

    // 当缩放系数是小数时（非固定选项），左侧显示应该高亮
    bool highlightCurrentZoom = !isFixedZoomLevel;

    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 左侧显示当前实际缩放值
              Padding(
                padding: const EdgeInsets.only(right: 12, left: 4),
                child: Text(
                  currentZoomLabel,
                  style: TextStyle(
                    color: highlightCurrentZoom ? Colors.yellow : Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 分隔线
              Container(
                height: 20,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),

              // 固定缩放选项
              ...zoomOptions.map((option) {
                final bool isSelected =
                    (currentZoom - option['level'] as double).abs() < 0.05;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: _buildZoomOption(option['level'] as double,
                      option['label'] as String, isSelected),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildZoomOption(double zoomLevel, String label, bool isSelected) {
    return GestureDetector(
      onTap: () => onZoomChanged(zoomLevel),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color:
              isSelected ? Colors.white.withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.yellow : Colors.white,
            fontSize: isSelected ? 14 : 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
