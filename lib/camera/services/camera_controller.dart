import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'native_camera_service.dart';

/// 相机控制器类，封装相机操作
class CameraController {
  // 原生相机控制器
  final NativeCameraController _nativeCameraController;

  // 构造函数，传入原生相机控制器
  CameraController(this._nativeCameraController);

  /// 拍照
  Future<Uint8List?> capturePhoto() async {
    return _nativeCameraController.capturePhoto();
  }

  /// 暂停预览
  Future<void> pausePreview() async {
    await _nativeCameraController.pausePreview();
  }

  /// 恢复预览
  Future<void> resumePreview() async {
    await _nativeCameraController.resumePreview();
  }

  /// 设置缩放级别
  Future<bool> setZoomLevel(double zoomLevel) async {
    return _nativeCameraController.setZoomLevel(zoomLevel);
  }

  /// 切换摄像头
  Future<bool> switchCamera({required bool toFront}) async {
    return _nativeCameraController.switchCamera(toFront: toFront);
  }

  /// 检查是否为前置摄像头
  Future<bool> isFrontCamera() async {
    return _nativeCameraController.isFrontCamera();
  }

  /// 更新事件处理函数
  void updateEventHandler(Function(Map<String, dynamic>)? onCameraEvent) {
    _nativeCameraController.updateEventHandler(onCameraEvent);
  }

  /// 重新连接事件通道
  void reconnectEventChannel() {
    _nativeCameraController.reconnectEventChannel();
  }
}
