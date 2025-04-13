import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:developer';

/// 相机类型枚举
enum CameraType {
  standard, // 标准广角
  ultraWide, // 超广角
  telephoto, // 长焦
  front // 前置
}

/// 全局相机服务，负责在应用启动时初始化相机资源
/// 并管理相机的生命周期，避免重复初始化
class CameraService {
  // 单例模式
  static final CameraService _instance = CameraService._internal();
  factory CameraService() => _instance;
  CameraService._internal();

  // 相机相关状态
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isStreamActive = false;

  // 摄像头索引
  int _standardCameraIndex = 0; // 标准后置摄像头索引
  int _ultraWideCameraIndex = -1; // 超广角摄像头索引
  int _frontCameraIndex = -1; // 前置摄像头索引
  int _currentCameraIndex = 0; // 当前使用的摄像头索引
  int _telephotoIndex = -1; // 长焦相机索引

  // Getters
  List<CameraDescription> get cameras => _cameras;
  CameraController? get controller => _controller;
  bool get isInitialized => _isInitialized;
  bool get isStreamActive => _isStreamActive;
  int get standardCameraIndex => _standardCameraIndex;
  int get ultraWideCameraIndex => _ultraWideCameraIndex;
  int get frontCameraIndex => _frontCameraIndex;
  int get currentCameraIndex => _currentCameraIndex;
  int get telephotoIndex => _telephotoIndex;

  // 平台通道
  static const MethodChannel _channel =
      MethodChannel('com.haohaopai.app/camera_features');

  /// 初始化相机，在应用启动时调用
  Future<void> initializeCamera() async {
    if (_isInitialized) {
      debugPrint('相机已经初始化，跳过初始化过程');
      return;
    }

    try {
      debugPrint('开始初始化相机资源...');
      // 获取所有可用相机
      _cameras = await availableCameras();
      debugPrint('找到${_cameras.length}个相机');

      if (_cameras.isEmpty) {
        debugPrint('没有找到可用的相机');
        return;
      }

      // 分析摄像头类型
      await _analyzeCameras();

      // 初始化标准后置摄像头(默认)
      await _initializeCameraController(_standardCameraIndex);

      _isInitialized = true;
      debugPrint('相机资源初始化完成');
    } catch (e) {
      debugPrint('初始化相机资源时出错: $e');
      _isInitialized = false;
    }
  }

  /// 分析设备上的摄像头类型
  Future<void> _analyzeCameras() async {
    if (_cameras.isEmpty) return;

    // 重置索引
    _standardCameraIndex = -1;
    _ultraWideCameraIndex = -1;
    _frontCameraIndex = -1;
    _telephotoIndex = -1;

    debugPrint('📷 开始分析设备相机，共${_cameras.length}个相机:');

    // 详细打印所有相机信息，便于调试
    for (int i = 0; i < _cameras.length; i++) {
      final camera = _cameras[i];
      debugPrint(
          '📷 Flutter相机[$i]: ${camera.name}, 方向: ${camera.lensDirection}');
    }

    // 先设置前置相机索引
    for (int i = 0; i < _cameras.length; i++) {
      if (_cameras[i].lensDirection == CameraLensDirection.front) {
        _frontCameraIndex = i;
        debugPrint('📷 ✓ 找到前置相机: $i - ${_cameras[i].name}');
        break;
      }
    }

    // 获取原生API相机信息
    Map<String, dynamic> nativeCameraInfo = {};
    try {
      nativeCameraInfo = await getCameraFeatures();
      debugPrint('📷 原生API返回相机信息: $nativeCameraInfo');

      if (nativeCameraInfo.isEmpty) {
        debugPrint('📷 ⚠️ 原生API返回空信息，将回退到基础相机识别方法');
      } else {
        debugPrint('📷 ✓ 成功获取原生API相机信息');
      }
    } catch (e) {
      debugPrint('📷 ⚠️ 获取原生相机信息出错: $e');
    }

    // 如果成功获取原生API相机信息，使用它进行准确匹配
    if (nativeCameraInfo.isNotEmpty &&
        nativeCameraInfo.containsKey('devices')) {
      final nativeDevices = nativeCameraInfo['devices'] as List;
      if (nativeDevices.isNotEmpty) {
        debugPrint('📷 ===== 开始精确匹配iOS原生相机与Flutter相机 =====');
        debugPrint(
            '📷 原生API返回${nativeDevices.length}个相机设备，Flutter有${_cameras.length}个相机');

        // 构建原生相机映射表，相机ID => 相机类型
        final Map<String, String> nativeCameraTypes = {};
        final Map<String, int> nativeCameraPositions = {};

        for (final device in nativeDevices) {
          final uniqueID = device['uniqueID'] as String;
          final deviceType = device['deviceType'] as String;
          final position = device['position'] as int;

          nativeCameraTypes[uniqueID] = deviceType;
          nativeCameraPositions[uniqueID] = position;

          debugPrint('📷 原生相机: ID=$uniqueID, 类型=$deviceType, 位置=$position');
        }

        // 从Flutter相机名称中尝试提取原生相机ID
        // 在iOS上，Flutter相机名称通常是原生相机的uniqueID
        for (int i = 0; i < _cameras.length; i++) {
          final camera = _cameras[i];
          final name = camera.name;

          // 检查该相机名称是否与原生相机ID匹配
          String? matchedID;
          for (final uniqueID in nativeCameraTypes.keys) {
            if (name == uniqueID || name.contains(uniqueID)) {
              matchedID = uniqueID;
              debugPrint('📷 ✓ Flutter相机[$i]匹配到原生相机ID: $matchedID');
              break;
            }
          }

          // 如果找到匹配ID
          if (matchedID != null) {
            final deviceType = nativeCameraTypes[matchedID]!;
            final position = nativeCameraPositions[matchedID]!;

            // 根据设备类型和位置进行分类
            if (position == 1) {
              // 前置相机 (AVCaptureDevicePosition.front = 1)
              _frontCameraIndex = i;
              debugPrint('📷 ✓ 通过原生类型确认为前置相机: $i - $name');
            } else if (position == 2) {
              // 后置相机 (AVCaptureDevicePosition.back = 2)
              if (deviceType.contains('builtInUltraWideCamera')) {
                _ultraWideCameraIndex = i;
                debugPrint('📷 ✓ 通过原生类型确认为超广角相机: $i - $name');
              } else if (deviceType.contains('builtInTelephotoCamera')) {
                _telephotoIndex = i;
                debugPrint('📷 ✓ 通过原生类型确认为长焦相机: $i - $name');
              } else if (deviceType.contains('builtInWideAngleCamera')) {
                _standardCameraIndex = i;
                debugPrint('📷 ✓ 通过原生类型确认为标准广角相机: $i - $name');
              } else {
                // 如果没有更具体的类型，假设是标准后置相机
                if (_standardCameraIndex == -1) {
                  _standardCameraIndex = i;
                  debugPrint('📷 ✓ 后置相机但类型不明确，默认为标准广角: $i - $name');
                }
              }
            }
          }
        }
      }
    } else {
      // 如果无法通过原生API获取详细信息，使用基本逻辑确定相机类型
      debugPrint('📷 使用基本逻辑识别相机类型');

      // 1. 查找标准广角摄像头（默认后置摄像头）
      for (int i = 0; i < _cameras.length; i++) {
        final camera = _cameras[i];
        if (camera.lensDirection == CameraLensDirection.back) {
          if (_standardCameraIndex == -1) {
            _standardCameraIndex = i;
            debugPrint('📷 ✓ 找到标准广角相机: $i - ${camera.name}');
          }
        }
      }
    }

    // 如果仍然没有找到标准相机，将第一个后置相机作为标准相机
    if (_standardCameraIndex == -1) {
      for (int i = 0; i < _cameras.length; i++) {
        if (_cameras[i].lensDirection == CameraLensDirection.back) {
          _standardCameraIndex = i;
          debugPrint('📷 ✓ 没有找到明确标准广角相机，使用第一个后置相机: $i - ${_cameras[i].name}');
          break;
        }
      }
    }

    // 如果还是没有找到任何相机，使用第0个
    if (_standardCameraIndex == -1 && _cameras.isNotEmpty) {
      _standardCameraIndex = 0;
      debugPrint('📷 ⚠️ 没有找到后置相机，使用第一个可用相机作为默认相机: ${_cameras[0].name}');
    }

    // 如果只找到了前置相机但没有后置相机
    if (_standardCameraIndex == -1 && _frontCameraIndex != -1) {
      _standardCameraIndex = _frontCameraIndex;
      debugPrint('📷 ⚠️ 只找到前置相机，将其作为默认相机');
    }

    // 输出分析结果
    debugPrint('📷 ===== 相机分析结果 =====');
    debugPrint('📷 标准广角索引: $_standardCameraIndex');
    debugPrint(
        '📷 超广角索引: ${_ultraWideCameraIndex != -1 ? _ultraWideCameraIndex : "未找到"}');
    debugPrint(
        '📷 前置相机索引: ${_frontCameraIndex != -1 ? _frontCameraIndex : "未找到"}');
    debugPrint('📷 长焦相机索引: ${_telephotoIndex != -1 ? _telephotoIndex : "未找到"}');
  }

  /// 初始化相机控制器
  Future<void> _initializeCameraController(int cameraIndex) async {
    if (cameraIndex < 0 || cameraIndex >= _cameras.length) {
      debugPrint('相机索引超出范围: $cameraIndex，可用相机数量: ${_cameras.length}');
      return;
    }

    // 释放之前的控制器
    await _controller?.dispose();

    // 创建新的控制器
    final newController = CameraController(
      _cameras[cameraIndex],
      ResolutionPreset.high, // 使用高分辨率
      enableAudio: false, // 禁用音频（纯拍照模式）
      imageFormatGroup: ImageFormatGroup.jpeg, // 使用JPEG格式
    );

    _controller = newController;
    _currentCameraIndex = cameraIndex;

    // 初始化控制器
    try {
      await newController.initialize();
      debugPrint('相机控制器初始化成功，索引: $cameraIndex');
    } catch (e) {
      debugPrint('初始化相机控制器失败: $e');
      _controller = null;
    }
  }

  /// 切换到指定类型的相机
  Future<bool> switchToCamera(CameraType type) async {
    if (!_isInitialized) return false;

    int? targetIndex;
    switch (type) {
      case CameraType.standard:
        targetIndex = _standardCameraIndex;
        break;
      case CameraType.ultraWide:
        targetIndex = _ultraWideCameraIndex;
        break;
      case CameraType.telephoto:
        targetIndex = _telephotoIndex;
        break;
      case CameraType.front:
        targetIndex = _frontCameraIndex;
        break;
    }

    if (targetIndex == null ||
        targetIndex < 0 ||
        targetIndex >= _cameras.length) {
      debugPrint('请求的相机类型不可用: $type');
      return false;
    }

    if (targetIndex == _currentCameraIndex) {
      // 已经是请求的相机类型
      return true;
    }

    await _initializeCameraController(targetIndex);
    return _controller != null;
  }

  /// 释放相机资源
  Future<void> dispose() async {
    await _controller?.dispose();
    _controller = null;
    _isInitialized = false;
  }

  /// 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    if (!_isInitialized || _controller == null) return;

    try {
      await _controller!.setZoomLevel(zoomLevel);
    } catch (e) {
      debugPrint('设置缩放级别失败: $e');
    }
  }

  /// 拍照
  Future<XFile?> takePicture() async {
    if (!_isInitialized || _controller == null) return null;

    try {
      final file = await _controller!.takePicture();
      return file;
    } catch (e) {
      debugPrint('拍照失败: $e');
      return null;
    }
  }

  /// 调用原生API获取相机特性
  Future<Map<String, dynamic>> getCameraFeatures() async {
    try {
      debugPrint('📱 调用原生API getCameraFeatures开始');
      final result = await _channel.invokeMethod('getCameraFeatures');

      if (result is Map<dynamic, dynamic>) {
        final Map<String, dynamic> features = {};
        result.forEach((key, value) {
          if (key is String) {
            features[key] = value;
          }
        });
        debugPrint('📱 原生API调用成功，返回数据大小: ${features.length}');
        return features;
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('📱 调用原生API getCameraFeatures失败: $e');
      return {};
    }
  }
}
