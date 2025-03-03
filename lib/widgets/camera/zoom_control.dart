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
    // 确保显示的缩放选项包括0.5x
    final List<Map<String, dynamic>> zoomOptions = [
      {'level': 0.5, 'label': '0.5×'},
      {'level': 1.0, 'label': '1×'},
      {'level': 2.0, 'label': '2×'},
    ];

    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: zoomOptions.map((option) {
              final bool isSelected =
                  (currentZoom - option['level']).abs() < 0.2;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
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
              isSelected ? Colors.white.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
            fontSize: isSelected ? 16 : 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
