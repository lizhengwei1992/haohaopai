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
  late final double previewCenterY; // 相机预览框中心Y坐标（固定值，基于竖直16:9计算）
  late final double previewTopY; // 相机预览框顶部Y坐标（固定值，基于竖直16:9）
  late final double previewHeightVertical16_9; // 竖直方向16:9比例时的预览框高度

  // 固定的UI位置（基于4:3比例计算）
  late final double previewHeight4_3; // 4:3比例时的预览框高度
  late final double preview4_3BottomY; // 4:3比例时的预览框底部Y坐标
  late final double fixedZoomControlY; // 固定的缩放控制器Y坐标
  late final double fixedCameraControlsY; // 固定的相机控制按钮Y坐标
  late final double fixedBottomControlsY; // 固定的底部按钮Y坐标

  // 各组件定位相关
  late final double controlButtonsSpacing = 10.0; // 控制按钮间距

  // 缩放控制器位置（相机预览框下沿向上5px）
  late final double zoomControlOffsetFromBottom = 5.0;

  // 相机控制按钮位置（相机预览框下沿向下10px）
  late final double cameraControlsOffsetFromPreview = 10.0;

  // 底部按钮位置（相机控制按钮下沿向下25px）
  late final double bottomControlsOffsetFromCameraControls = 25.0;

  // 底部安全区域
  late final double bottomSafeArea;

  /// 根据屏幕尺寸计算相机预览框各种位置
  /// 对于不同的宽高比，返回不同的预览框参数
  /// 按钮位置保持固定，不随预览框比例变化
  PreviewParams getPreviewParams(String aspectRatio) {
    double previewHeight;
    double previewTopPosition;

    switch (aspectRatio) {
      case '16:9':
        // 水平:竖直 = 9:16 的比例（在竖屏模式下）
        previewHeight = screenWidth * 16 / 9;
        // 16:9比例下，直接使用预览框顶部位置为刘海/灵动岛下沿
        // 这样可以确保16:9时相机预览框紧贴刘海/灵动岛下沿
        previewTopPosition = topPadding;
        debugPrint('16:9比例: 使用顶部位置=$previewTopPosition (刘海/灵动岛下沿)');
        break;
      case '1:1':
        // 正方形预览
        previewHeight = screenWidth;
        // 保持中心点不变
        previewTopPosition = previewCenterY - previewHeight / 2;
        break;
      case '4:3':
      default:
        // 水平:竖直 = 3:4 的比例（在竖屏模式下）
        previewHeight = screenWidth * 4 / 3;
        // 保持中心点不变
        previewTopPosition = previewCenterY - previewHeight / 2;
        break;
    }

    // 非16:9比例下，使用固定的中心点计算顶部位置
    if (aspectRatio != '16:9') {
      previewTopPosition = previewCenterY - previewHeight / 2;
    }

    debugPrint(
        '获取预览参数: 比例=$aspectRatio, 高度=$previewHeight, 顶部位置=$previewTopPosition');

    // 检查16:9比例下预览框是否真的紧贴刘海/灵动岛下沿
    if (aspectRatio == '16:9' && previewTopPosition != topPadding) {
      debugPrint(
          '警告: 16:9比例下预览框顶部位置(${previewTopPosition})与刘海/灵动岛下沿(${topPadding})不一致');
    }

    // 当前预览框的底部Y坐标
    final previewBottomY = previewTopPosition + previewHeight;

    // 输出调试信息，检查预览框是否溢出屏幕
    if (previewTopPosition < topPadding) {
      debugPrint('警告: 预览框顶部位置(${previewTopPosition})小于安全区域(${topPadding})');
    }
    if (previewBottomY > screenHeight) {
      debugPrint('警告: 预览框底部位置(${previewBottomY})超出屏幕高度(${screenHeight})');
    }

    return PreviewParams(
      width: screenWidth,
      height: previewHeight,
      topPosition: previewTopPosition,
      bottomPosition: previewBottomY,

      // 使用固定的UI位置，不随预览框比例变化
      zoomControlY: fixedZoomControlY,
      cameraControlsY: fixedCameraControlsY,
      bottomControlsY: fixedBottomControlsY,
    );
  }

  /// 初始化所有参数
  void _initializeParams(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    screenWidth = mediaQuery.size.width;
    screenHeight = mediaQuery.size.height;
    topPadding = mediaQuery.padding.top;
    bottomSafeArea = mediaQuery.padding.bottom;

    // 设置相机预览框顶部位置为刘海/灵动岛下沿
    previewTopY = topPadding;

    // 计算竖直16:9比例时的预览框高度（竖直:水平 = 16:9）
    previewHeightVertical16_9 = screenWidth * 16 / 9;

    // 计算预览框中心点位置
    // 当预览框上边沿紧贴刘海/灵动岛下沿时的中心点位置
    previewCenterY = previewTopY + previewHeightVertical16_9 / 2;

    // 计算4:3比例时的预览框参数
    previewHeight4_3 = screenWidth * 4 / 3;
    double previewTop4_3 = previewCenterY - previewHeight4_3 / 2;
    preview4_3BottomY = previewTop4_3 + previewHeight4_3;

    // 缩放控制器位置（4:3预览框下沿向上5px）
    fixedZoomControlY = preview4_3BottomY - zoomControlOffsetFromBottom;

    // 相机控制按钮位置（4:3预览框下沿向下10px）
    fixedCameraControlsY = preview4_3BottomY + cameraControlsOffsetFromPreview;

    // 底部按钮位置（相机控制按钮下沿向下25px）
    fixedBottomControlsY =
        fixedCameraControlsY + 50 + bottomControlsOffsetFromCameraControls;

    // 输出调试信息
    debugPrint('初始化布局参数: 屏幕宽度=$screenWidth, 高度=$screenHeight');
    debugPrint('顶部安全区域高度=$topPadding, 预览框顶部位置=$previewTopY');
    debugPrint(
        '竖直16:9预览框高度=$previewHeightVertical16_9, 预览框中心点Y=$previewCenterY');
    debugPrint('4:3预览框高度=$previewHeight4_3, 4:3预览框底部Y=$preview4_3BottomY');
    debugPrint(
        '固定的缩放控制器Y=$fixedZoomControlY (4:3预览框下沿向上${zoomControlOffsetFromBottom}px)');
    debugPrint(
        '固定的相机控制按钮Y=$fixedCameraControlsY (4:3预览框下沿向下${cameraControlsOffsetFromPreview}px)');
    debugPrint(
        '固定的底部按钮Y=$fixedBottomControlsY (相机控制按钮下沿向下${bottomControlsOffsetFromCameraControls}px)');

    // 检查预览框是否超出屏幕底部
    double previewBottomY = previewTopY + previewHeightVertical16_9;
    if (previewBottomY > screenHeight) {
      debugPrint(
          '警告: 竖直16:9预览框底部(${previewBottomY})超出屏幕高度(${screenHeight})，超出${previewBottomY - screenHeight}像素');
    }

    // 检查按钮是否超出屏幕底部
    if (fixedBottomControlsY + 96 > screenHeight) {
      debugPrint('警告: 底部按钮区域超出屏幕底部，可能导致部分按钮不可见');
    }
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
