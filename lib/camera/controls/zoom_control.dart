import 'dart:io';
import 'package:flutter/material.dart';
import '../state/camera_state_manager.dart';

/// 缩放控制组件
class ZoomControl extends StatelessWidget {
  const ZoomControl({Key? key}) : super(key: key);

  // 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    final cameraState = CameraStateManager.instance;

    // 使用CameraStateManager的方法设置缩放
    await cameraState.setZoom(zoomLevel);
  }

  // 处理缩放选项点击
  void _handleZoomOptionTap(String label) {
    final cameraState = CameraStateManager.instance;
    double zoomLevel = 1.0;

    // 获取设备信息
    final hasVirtualDeviceSupport = Platform.isIOS &&
        (cameraState.cameraCapabilities['hasVirtualDeviceSupport'] ?? false);
    final hasUltraWide =
        cameraState.cameraCapabilities['hasUltraWide'] ?? false;

    // 获取设备切换点
    List<double> switchPoints = [];
    if (hasVirtualDeviceSupport) {
      final rawSwitchPoints =
          cameraState.cameraCapabilities['virtualDeviceSwitchPoints'] ?? [];
      if (rawSwitchPoints is List) {
        switchPoints = List<double>.from(
            rawSwitchPoints.map((x) => x is double ? x : x.toDouble()));
      }
    }

    // 根据设备类型和切换点调整缩放值
    if (hasVirtualDeviceSupport &&
        hasUltraWide &&
        switchPoints.isNotEmpty &&
        switchPoints[0] == 2.0) {
      // DualWideCamera设备需要特殊处理
      if (label == '0.5×') {
        zoomLevel = 1.0; // DualWideCamera的1.0对应超广角0.5x
      } else if (label == '1×') {
        zoomLevel = 2.0; // DualWideCamera的2.0对应广角1x
      } else if (label == '2×') {
        zoomLevel = 4.0; // DualWideCamera的4.0对应2x变焦
      } else if (label == '3×') {
        zoomLevel = 6.0; // DualWideCamera的6.0对应3x变焦
      }
    } else {
      // 常规设备的标准处理
      if (label == '0.5×') {
        zoomLevel = 0.5;
      } else if (label == '1×') {
        zoomLevel = 1.0;
      } else if (label == '2×') {
        zoomLevel = 2.0;
      } else if (label == '3×') {
        zoomLevel = 3.0;
      }
    }

    setZoomLevel(zoomLevel);
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    // 获取设备信息
    final hasVirtualDeviceSupport = Platform.isIOS &&
        (cameraState.cameraCapabilities['hasVirtualDeviceSupport'] ?? false);
    final hasUltraWide =
        cameraState.cameraCapabilities['hasUltraWide'] ?? false;

    // 获取设备切换点
    List<double> switchPoints = [];
    if (hasVirtualDeviceSupport) {
      final rawSwitchPoints =
          cameraState.cameraCapabilities['virtualDeviceSwitchPoints'] ?? [];
      if (rawSwitchPoints is List) {
        switchPoints = List<double>.from(
            rawSwitchPoints.map((x) => x is double ? x : x.toDouble()));
      }
    }

    // 判断是否是DualWideCamera设备
    final isDualWideCamera = hasVirtualDeviceSupport &&
        hasUltraWide &&
        switchPoints.isNotEmpty &&
        switchPoints[0] == 2.0;

    // 使用 ValueListenableBuilder 来监听焦距变化
    return ValueListenableBuilder<double>(
      valueListenable: cameraState.currentZoomLevelNotifier,
      builder: (context, zoomLevel, child) {
        // 计算显示给用户看的缩放倍率（与实际效果对应）
        String displayZoom;

        if (isDualWideCamera) {
          // DualWideCamera设备需要特殊处理显示的缩放倍率
          double displayValue = zoomLevel / 2.0; // DualWideCamera实际缩放为内部缩放值的一半

          // 校正一些特殊值
          if ((zoomLevel - 1.0).abs() < 0.1) {
            displayValue = 0.5; // 1.0对应0.5x
          } else if ((zoomLevel - 2.0).abs() < 0.1) {
            displayValue = 1.0; // 2.0对应1.0x
          } else if ((zoomLevel - 4.0).abs() < 0.1) {
            displayValue = 2.0; // 4.0对应2.0x
          } else if ((zoomLevel - 6.0).abs() < 0.1) {
            displayValue = 3.0; // 6.0对应3.0x
          }

          displayZoom = '${displayValue.toStringAsFixed(1)}×';
        } else {
          // 常规设备直接显示
          displayZoom = '${zoomLevel.toStringAsFixed(1)}×';
        }

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
                  // 显示当前焦距值
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      displayZoom,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  _buildZoomOption(
                      '0.5×',
                      isDualWideCamera
                          ? (zoomLevel - 1.0).abs() <
                              0.1 // DualWideCamera: 1.0 -> 0.5x
                          : (zoomLevel - 0.5).abs() < 0.1), // 普通设备: 0.5 -> 0.5x
                  const SizedBox(width: 6),
                  _buildZoomOption(
                      '1×',
                      isDualWideCamera
                          ? (zoomLevel - 2.0).abs() <
                              0.1 // DualWideCamera: 2.0 -> 1x
                          : (zoomLevel - 1.0).abs() < 0.1), // 普通设备: 1.0 -> 1x
                  const SizedBox(width: 6),
                  _buildZoomOption(
                      '2×',
                      isDualWideCamera
                          ? (zoomLevel - 4.0).abs() <
                              0.1 // DualWideCamera: 4.0 -> 2x
                          : (zoomLevel - 2.0).abs() < 0.1), // 普通设备: 2.0 -> 2x
                  const SizedBox(width: 6),
                  _buildZoomOption(
                      '3×',
                      isDualWideCamera
                          ? (zoomLevel - 6.0).abs() <
                              0.1 // DualWideCamera: 6.0 -> 3x
                          : (zoomLevel - 3.0).abs() < 0.1), // 普通设备: 3.0 -> 3x
                ],
              ),
            ),
          ),
        );
      },
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
