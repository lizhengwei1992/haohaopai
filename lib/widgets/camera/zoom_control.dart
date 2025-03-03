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

    // 始终添加0.5x选项
    zoomOptions.add({'level': 0.5, 'label': '0.5×'});

    // 添加当前缩放值（如果接近1.0，则显示为1x）
    if ((currentZoom - 1.0).abs() < 0.05) {
      zoomOptions.add({'level': 1.0, 'label': '1×'});
    } else {
      zoomOptions.add({
        'level': currentZoom,
        'label': '${currentZoom.toStringAsFixed(1)}×'
      });
    }

    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4), // 调高透明度
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
            children: zoomOptions.map((option) {
              final bool isSelected = option['level'] == 0.5
                  ? (currentZoom - 0.5).abs() < 0.05
                  : option['level'] != 0.5;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _buildZoomOption(
                    option['level'], option['label'], isSelected),
              );
            }).toList(),
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
            fontSize: isSelected ? 14 : 12, // 调小字体大小
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
