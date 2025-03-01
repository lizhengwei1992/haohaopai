import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onTeachPress;
  final VoidCallback onCapturePress;
  final VoidCallback onGalleryPress;
  final VoidCallback onSwitchCameraPress;
  final bool showingTips;

  const CameraControls({
    super.key,
    required this.onTeachPress,
    required this.onCapturePress,
    required this.onGalleryPress,
    required this.onSwitchCameraPress,
    this.showingTips = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 160,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.8), Colors.transparent],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // // 模式选择器
            // if (!showingTips)
            //   Padding(
            //     padding: const EdgeInsets.only(bottom: 20),
            //     child: Row(
            //       mainAxisAlignment: MainAxisAlignment.center,
            //       children: [_buildModeOption('照片', true)],
            //     ),
            //   ),

            // 底部控制栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 左侧按钮 - 切换相机
                IconButton(
                  icon: const Icon(
                    Icons.flip_camera_ios,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: onSwitchCameraPress,
                ),

                // 中间按钮 - 拍照/教我拍
                _buildCaptureButton(showingTips),

                // 右侧按钮 - 相册
                IconButton(
                  icon: const Icon(
                    Icons.photo_library,
                    color: Colors.white,
                    size: 28,
                  ),
                  onPressed: onGalleryPress,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(String label, bool isSelected) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.6),
            fontSize: 16,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(height: 4),
        if (isSelected)
          Container(
            width: 20,
            height: 3,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    );
  }

  Widget _buildCaptureButton(bool showingTips) {
    return GestureDetector(
      onTap: showingTips ? onCapturePress : onTeachPress,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          color:
              showingTips ? Colors.green.withOpacity(0.3) : Colors.transparent,
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: showingTips ? Colors.green : Colors.white,
            ),
            child: Center(
              child: showingTips
                  ? const Icon(Icons.check, color: Colors.white, size: 30)
                  : const Text(
                      '教我拍',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
