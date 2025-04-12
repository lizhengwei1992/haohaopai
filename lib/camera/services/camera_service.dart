import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'camera_controller.dart';
import '../native_camera_service.dart';

/// 相机服务类，单例模式管理全局相机资源
class CameraService {
  // 私有构造函数确保单例模式
  CameraService._();

  // 静态单例实例
  static final CameraService instance = CameraService._();

  // 现有相机服务实例，重用其功能以减少迁移风险
  final NativeCameraService _nativeCameraService = NativeCameraService.instance;

  /// 获取全局相机控制器
  NativeCameraController? getGlobalCameraController() {
    return _nativeCameraService.getGlobalCameraController();
  }

  /// 创建或获取全局相机控制器
  Future<NativeCameraController> getOrCreateCameraController({
    required int cameraId,
    Function(Map<String, dynamic>)? onCameraEvent,
  }) async {
    return _nativeCameraService.getOrCreateCameraController(
      cameraId: cameraId,
      onCameraEvent: onCameraEvent,
    );
  }

  /// 释放全局相机控制器
  void releaseGlobalCameraController() {
    _nativeCameraService.releaseGlobalCameraController();
  }

  /// 检查设备是否支持原生相机
  Future<bool> isNativeCameraSupported() async {
    return _nativeCameraService.isNativeCameraSupported();
  }

  /// 获取相机能力和配置信息
  Future<Map<String, dynamic>> getCameraCapabilities() async {
    return _nativeCameraService.getCameraCapabilities();
  }

  /// 检查相机是否已准备就绪
  Future<bool> isCameraReady() async {
    return _nativeCameraService.isCameraReady();
  }

  /// 等待相机初始化完成
  Future<bool> waitForInitialization() async {
    return _nativeCameraService.waitForInitialization();
  }

  /// 初始化相机
  Future<bool> initializeCamera() async {
    return _nativeCameraService.initializeCamera();
  }

  /// 暂停相机
  Future<void> pauseCamera() async {
    await _nativeCameraService.pauseCamera();
  }

  /// 恢复相机
  Future<void> resumeCamera() async {
    await _nativeCameraService.resumeCamera();
  }
}
