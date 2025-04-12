import 'package:flutter/material.dart';
import '../state/camera_state_manager.dart';
import '../services/camera_service.dart';

/// 缩放控制组件
class ZoomControl extends StatelessWidget {
  const ZoomControl({Key? key}) : super(key: key);

  // 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    final cameraState = CameraStateManager.instance;
    final cameraService = CameraService.instance;

    // 获取全局控制器
    final nativeCameraController = cameraService.getGlobalCameraController();
    if (nativeCameraController != null) {
      // 使用原生相机设置缩放
      final success = await nativeCameraController.setZoomLevel(zoomLevel);
      if (success) {
        cameraState.currentZoomLevel = zoomLevel;
      }
    } else {
      // 仅更新状态，模拟缩放效果
      cameraState.currentZoomLevel = zoomLevel;
    }
  }

  // 处理缩放选项点击
  void _handleZoomOptionTap(String label) {
    double zoomLevel = 1.0;

    if (label == '0.5×') {
      zoomLevel = 0.5;
    } else if (label == '1×') {
      zoomLevel = 1.0;
    } else if (label == '2×') {
      zoomLevel = 2.0;
    } else if (label == '3×') {
      zoomLevel = 3.0;
    }

    setZoomLevel(zoomLevel);
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(80, 80, 80, 0.2),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomOption('0.5×', cameraState.currentZoomLevel == 0.5),
              const SizedBox(width: 6),
              _buildZoomOption('1×', cameraState.currentZoomLevel == 1.0),
              const SizedBox(width: 6),
              _buildZoomOption('2×', cameraState.currentZoomLevel == 2.0),
              const SizedBox(width: 6),
              _buildZoomOption('3×', cameraState.currentZoomLevel == 3.0),
            ],
          ),
        ),
      ),
    );
  }

  // 构建缩放选项
  Widget _buildZoomOption(String label, bool isSelected) {
    final textStyle = TextStyle(
      color: isSelected ? Colors.yellow : Colors.white,
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    );

    return GestureDetector(
      onTap: () => _handleZoomOptionTap(label),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color.fromRGBO(100, 100, 100, 0.5)
              : Colors.transparent,
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
