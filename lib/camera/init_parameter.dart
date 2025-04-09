import 'package:flutter/material.dart';

/// 相机界面布局参数
class CameraLayoutParams {
  /// 构造函数，初始化所有布局参数
  CameraLayoutParams(BuildContext context) {
    _initializeParams(context);
  }

  // 屏幕参数
  late final double screenWidth;
  late final double screenHeight;
  late final double topPadding;

  // 相机预览相关
  late final double previewCenterY; // 相机预览框中心Y坐标

  // 各组件定位相关
  late final double controlButtonsSpacing = 10.0; // 控制按钮间距

  // 缩放控制器位置（相机预览框下沿向上10px）
  late final double zoomControlOffsetFromBottom = 10.0;

  // 相机控制按钮位置（相机预览框下沿向下10px）
  late final double cameraControlsOffsetFromPreview = 10.0;

  // 底部按钮位置（相机控制按钮下沿向下10px）
  late final double bottomControlsOffsetFromCameraControls = 10.0;

  // 底部安全区域
  late final double bottomSafeArea;

  /// 根据屏幕尺寸计算相机预览框各种位置
  /// 对于不同的宽高比，返回不同的预览框参数
  PreviewParams getPreviewParams(String aspectRatio) {
    double targetAspectRatio;
    switch (aspectRatio) {
      case '16:9':
        targetAspectRatio = 9 / 16; // 在竖屏模式下，宽高比需要倒置
        break;
      case '1:1':
        targetAspectRatio = 1;
        break;
      case '4:3':
      default:
        targetAspectRatio = 3 / 4; // 在竖屏模式下，宽高比需要倒置
        break;
    }

    // 计算预览区域的高度，确保水平方向充满屏幕宽度
    final previewHeight = screenWidth / targetAspectRatio;

    // 预览框顶部位置，使预览框中心位于屏幕高度的0.6处
    double previewTopPosition = previewCenterY - previewHeight / 2;

    // 确保预览框不会超出屏幕底部，预留出足够的空间给底部控件
    final minBottomSpace = 200.0; // 底部按钮区域所需的最小空间
    if (previewTopPosition + previewHeight > screenHeight - minBottomSpace) {
      previewTopPosition = screenHeight - previewHeight - minBottomSpace;
    }

    // 确保预览框不会超出屏幕顶部
    if (previewTopPosition < topPadding) {
      previewTopPosition = topPadding;
    }

    // 计算各组件位置
    final previewBottomY = previewTopPosition + previewHeight;

    return PreviewParams(
      width: screenWidth,
      height: previewHeight,
      topPosition: previewTopPosition,
      bottomPosition: previewBottomY,

      // 缩放控制位置（相机预览框下沿向上10px）
      zoomControlY: previewBottomY - zoomControlOffsetFromBottom,

      // 相机控制按钮位置（相机预览框下沿向下10px）
      cameraControlsY: previewBottomY + cameraControlsOffsetFromPreview,

      // 计算底部按钮位置
      // 相机控制按钮的高度估计为50px
      bottomControlsY: previewBottomY +
          cameraControlsOffsetFromPreview +
          50 +
          bottomControlsOffsetFromCameraControls,
    );
  }

  /// 初始化所有参数
  void _initializeParams(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    topPadding = mediaQuery.padding.top;
    bottomSafeArea = mediaQuery.padding.bottom;

    // 设置相机预览框中心位于屏幕高度的0.6处（向上移动10%）
    previewCenterY = screenHeight * 0.425;
  }
}

/// 预览框参数类
class PreviewParams {
  final double width;
  final double height;
  final double topPosition;
  final double bottomPosition;
  final double zoomControlY;
  final double cameraControlsY;
  final double bottomControlsY;

  PreviewParams({
    required this.width,
    required this.height,
    required this.topPosition,
    required this.bottomPosition,
    required this.zoomControlY,
    required this.cameraControlsY,
    required this.bottomControlsY,
  });
}
