import 'package:flutter/material.dart';

class CameraTopBar extends StatelessWidget {
  final double currentZoom;
  final bool flashEnabled;
  final VoidCallback onFlashToggle;
  final VoidCallback onSettingsPressed;

  const CameraTopBar({
    super.key,
    required this.currentZoom,
    required this.flashEnabled,
    required this.onFlashToggle,
    required this.onSettingsPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // 闪光灯按钮
            _buildIconButton(
              icon: flashEnabled ? Icons.flash_on : Icons.flash_off,
              onPressed: onFlashToggle,
              tooltip: flashEnabled ? '关闭闪光灯' : '开启闪光灯',
            ),

            // 缩放指示器
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${currentZoom.toStringAsFixed(1)}x',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            // 设置按钮
            _buildIconButton(
              icon: Icons.settings,
              onPressed: onSettingsPressed,
              tooltip: '设置',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Material(
      color: Colors.transparent,
      child: Tooltip(
        message: tooltip,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(30),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
      ),
    );
  }
}
