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
    // 准备缩放选项
    final List<Map<String, dynamic>> zoomOptions = [];

    // 如果支持超广角（最小缩放级别小于1.0），添加0.5x选项
    if (minZoom < 1.0) {
      zoomOptions.add({'level': 0.5, 'label': '0.5×'});
    }

    // 添加1.0x选项
    zoomOptions.add({'level': 1.0, 'label': '1×'});

    // 添加2.0x选项（如果最大缩放级别允许）
    if (maxZoom >= 2.0) {
      zoomOptions.add({'level': 2.0, 'label': '2×'});
    }

    // 如果最大缩放级别允许，添加更高的缩放选项
    if (maxZoom >= 5.0) {
      zoomOptions.add({'level': 5.0, 'label': '5×'});
    }

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
              // 显示当前缩放值
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _formatZoomLabel(currentZoom),
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // 缩放选项
              ...zoomOptions.map((option) {
                final bool isSelected =
                    (currentZoom - option['level']).abs() < 0.05;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _buildZoomOption(
                      option['level'], option['label'], isSelected),
                );
              }).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // 格式化缩放标签
  String _formatZoomLabel(double zoom) {
    if ((zoom - 0.5).abs() < 0.05) return '0.5×';
    if ((zoom - 1.0).abs() < 0.05) return '1×';
    if ((zoom - 2.0).abs() < 0.05) return '2×';
    if ((zoom - 5.0).abs() < 0.05) return '5×';
    return '${zoom.toStringAsFixed(1)}×';
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
