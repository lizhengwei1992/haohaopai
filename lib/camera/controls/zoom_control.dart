import 'dart:io';
import 'package:flutter/material.dart';
import '../state/camera_state_manager.dart';

/// 缩放控制组件
class ZoomControl extends StatelessWidget {
  const ZoomControl({Key? key}) : super(key: key);

  // 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    final cameraState = CameraStateManager.instance;

    // 如果是前置摄像头，强制设置为1.0倍缩放
    if (cameraState.currentCameraType == 'front') {
      await cameraState.setZoom(1.0);
      return;
    }

    // 使用CameraStateManager的方法设置缩放
    await cameraState.setZoom(zoomLevel);
  }

  // 处理缩放选项点击
  void _handleZoomOptionTap(String label) {
    final cameraState = CameraStateManager.instance;

    // 前置摄像头禁用缩放功能
    if (cameraState.currentCameraType == 'front') {
      return;
    }

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

    // 判断是否是DualWideCamera设备
    final isDualWideCamera = hasVirtualDeviceSupport &&
        hasUltraWide &&
        switchPoints.isNotEmpty &&
        switchPoints[0] == 2.0;

    // 根据相机类型和设备类型设置缩放因子
    final cameraType = cameraState.currentCameraType;

    if (cameraType == 'front') {
      // 前置相机不进行缩放，始终保持1.0x
      zoomLevel = 1.0;
    } else if (isDualWideCamera) {
      // 后置DualWideCamera设备需要特殊处理
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
      // 常规后置相机设备的标准处理
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

    // 检查是否是前置摄像头
    final isFrontCamera = cameraState.currentCameraType == 'front';

    // 如果是前置摄像头，不显示任何缩放控件
    if (isFrontCamera) {
      return const SizedBox.shrink();
    }

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

    // 检查设备是否支持0.5x缩放（超广角）
    final supportsUltraWide = hasUltraWide || cameraState.minZoomLevel <= 0.5;

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
                  // 只有支持超广角的设备显示0.5x选项
                  if (supportsUltraWide) ...[
                    _buildZoomOption(
                        '0.5×',
                        isDualWideCamera
                            ? (zoomLevel - 1.0).abs() <
                                0.1 // DualWideCamera: 1.0 -> 0.5x
                            : (zoomLevel - 0.5).abs() <
                                0.1), // 普通设备: 0.5 -> 0.5x
                    const SizedBox(width: 6),
                  ],

                  // 标准1x选项始终显示
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
        width: 40, // 进一步增大宽度
        height: 40, // 增大高度
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color.fromRGBO(100, 100, 100, 0.5)
              : Colors.transparent,
        ),
        child: Center(
          // 使用FittedBox确保文本不会溢出
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: textStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
