import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// 原生相机服务
/// 负责与iOS原生相机实现通信
class NativeCameraService {
  // 平台通道
  static const MethodChannel _channel =
      MethodChannel('com.haohaopai.app/native_camera');

  // 教我拍功能通道
  static const MethodChannel _teachCaptureChannel =
      MethodChannel('com.haohaopai.app/teach_capture');

  // 单例模式
  static final NativeCameraService _instance = NativeCameraService._internal();
  factory NativeCameraService() => _instance;
  NativeCameraService._internal();

  /// 检查设备是否支持原生相机
  static Future<bool> isNativeCameraSupported() async {
    if (!Platform.isIOS) return false;

    try {
      return await _channel.invokeMethod('isNativeCameraSupported') ?? false;
    } catch (e) {
      debugPrint('检查原生相机支持时出错: $e');
      return false;
    }
  }

  /// 获取相机能力
  static Future<Map<String, dynamic>> getCameraCapabilities() async {
    if (!Platform.isIOS) return {};

    try {
      final result = await _channel.invokeMethod('getCameraCapabilities');

      if (result is Map<dynamic, dynamic>) {
        // 将动态Map转换为字符串键的Map
        final Map<String, dynamic> capabilities = {};
        result.forEach((key, value) {
          if (key is String) {
            capabilities[key] = value;
          }
        });
        return capabilities;
      }

      return result as Map<String, dynamic>;
    } catch (e) {
      debugPrint('获取相机能力时出错: $e');
      return {};
    }
  }

  /// 教我拍功能：获取当前预览帧
  static Future<Uint8List?> captureCurrentPreviewFrame() async {
    if (!Platform.isIOS) return null;

    try {
      final result =
          await _teachCaptureChannel.invokeMethod('captureCurrentFrame');
      if (result is Uint8List) {
        return result;
      }
      return null;
    } catch (e) {
      debugPrint('获取预览帧出错: $e');
      return null;
    }
  }
}

/// 原生相机控制器事件监听器
class NativeCameraEventListener {
  final EventChannel _eventChannel;
  final void Function(Map<String, dynamic>) onZoomChanged;
  final void Function(Map<String, dynamic>) onFocusChanged;
  final void Function(Map<String, dynamic>) onOrientationChanged;

  StreamSubscription? _subscription;

  NativeCameraEventListener({
    required int viewId,
    required this.onZoomChanged,
    required this.onFocusChanged,
    required this.onOrientationChanged,
  }) : _eventChannel =
            EventChannel('com.haohaopai.app/native_camera_events_$viewId');

  /// 开始监听事件
  void startListening() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(_handleEvent);
  }

  /// 停止监听事件
  void stopListening() {
    _subscription?.cancel();
    _subscription = null;
  }

  /// 处理事件
  void _handleEvent(dynamic event) {
    if (event is! Map<String, dynamic>) return;

    final type = event['type'] as String?;

    switch (type) {
      case 'zoomChanged':
      case 'zoomStarted':
      case 'zoomEnded':
        onZoomChanged(event);
        break;

      case 'focusChanged':
        onFocusChanged(event);
        break;

      case 'orientationChanged':
        onOrientationChanged(event);
        break;
    }
  }

  /// 释放资源
  void dispose() {
    stopListening();
  }
}

/// 自定义相机异常
class CameraException implements Exception {
  final String code;
  final String message;

  CameraException(this.code, this.message);

  @override
  String toString() => 'CameraException($code, $message)';
}
