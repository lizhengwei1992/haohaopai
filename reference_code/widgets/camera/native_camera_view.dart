import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../services/index.dart';

/// 原生相机控制器 - 用于控制原生相机视图
class NativeCameraController {
  final int _id;
  final MethodChannel _channel;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // 相机状态
  bool _isPreviewActive = false;
  double _currentZoomLevel = 1.0;
  String _flashMode = 'off'; // 可能的值: 'off', 'on', 'auto'
  bool _isFrontCamera = false;

  // 相机事件监听器
  NativeCameraEventListener? _eventListener;

  /// 获取状态
  bool get isInitialized => _isInitialized;
  bool get isPreviewActive => _isPreviewActive;
  double get currentZoomLevel => _currentZoomLevel;
  String get flashMode => _flashMode;
  bool get isFrontCamera => _isFrontCamera;

  NativeCameraController(this._id)
      : _channel = MethodChannel('com.haohaopai.app/native_camera_view_$_id');

  /// 初始化相机
  Future<void> initialize() async {
    if (_isDisposed) {
      throw CameraException(
        'CAMERA_DISPOSED',
        '相机控制器已被释放，无法初始化',
      );
    }

    if (_isInitialized) {
      return; // 已经初始化
    }

    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '相机初始化失败');
    }
  }

  /// 开始预览
  Future<void> startPreview() async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    if (_isPreviewActive) {
      return; // 已经在预览中
    }

    try {
      final result = await _channel.invokeMethod<bool>('startPreview');
      _isPreviewActive = result ?? false;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '启动预览失败');
    }
  }

  /// 停止预览
  Future<void> stopPreview() async {
    if (!_isInitialized || !_isPreviewActive) {
      return; // 没有初始化或已经停止预览
    }

    try {
      final result = await _channel.invokeMethod<bool>('stopPreview');
      if (result ?? false) {
        _isPreviewActive = false;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '停止预览失败');
    }
  }

  /// 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'setZoomLevel',
        {'zoomLevel': zoomLevel},
      );

      if (result ?? false) {
        _currentZoomLevel = zoomLevel;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置缩放失败');
    }
  }

  /// 拍照
  Future<Uint8List> capturePhoto() async {
    if (!_isInitialized || !_isPreviewActive) {
      throw CameraException(
        'CAMERA_NOT_READY',
        '相机未准备好拍照',
      );
    }

    try {
      final photoData = await _channel.invokeMethod<Uint8List>('capturePhoto');
      if (photoData == null) {
        throw CameraException('CAPTURE_ERROR', '拍照失败，未返回图像数据');
      }
      return photoData;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '拍照失败');
    }
  }

  /// 切换前后相机
  Future<void> switchCamera({required bool toFront}) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'switchCamera',
        {'toFront': toFront},
      );

      if (result ?? false) {
        _isFrontCamera = toFront;
        // 重置缩放级别，因为切换相机后缩放会重置
        _currentZoomLevel = 1.0;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '切换相机失败');
    }
  }

  /// 切换闪光灯模式
  Future<String> toggleFlash() async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final mode = await _channel.invokeMethod<String>('toggleFlash');
      if (mode != null) {
        _flashMode = mode;
        return mode;
      }
      throw CameraException('FLASH_ERROR', '切换闪光灯失败');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '切换闪光灯失败');
    }
  }

  /// 设置对焦点
  Future<void> setFocusPoint(Offset point) async {
    if (!_isInitialized || !_isPreviewActive) {
      throw CameraException(
        'CAMERA_NOT_READY',
        '相机未准备好设置对焦点',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setFocusPoint',
        {'x': point.dx, 'y': point.dy},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置对焦点失败');
    }
  }

  /// 设置滤镜
  Future<void> setFilter(String filterName) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setFilter',
        {'filterName': filterName},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置滤镜失败');
    }
  }

  /// 设置纵横比
  Future<void> setAspectRatio(String ratio) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setAspectRatio',
        {'ratio': ratio},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置纵横比失败');
    }
  }

  /// 获取相机能力
  Future<Map<String, dynamic>> getCameraCapabilities() async {
    try {
      final result = await _channel.invokeMethod('getCameraCapabilities');
      return result as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('获取相机能力失败: ${e.message}');
      return {};
    }
  }

  /// 设置事件监听器
  void setEventListener({
    required Function(Map<String, dynamic>) onZoomChanged,
    required Function(Map<String, dynamic>) onFocusChanged,
    required Function(Map<String, dynamic>) onOrientationChanged,
  }) {
    _eventListener?.dispose();

    _eventListener = NativeCameraEventListener(
      viewId: _id,
      onZoomChanged: onZoomChanged,
      onFocusChanged: onFocusChanged,
      onOrientationChanged: onOrientationChanged,
    );

    _eventListener!.startListening();
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _eventListener?.dispose();

    if (_isInitialized) {
      try {
        if (_isPreviewActive) {
          await stopPreview();
        }
        await _channel.invokeMethod<bool>('dispose');
      } catch (e) {
        debugPrint('释放相机资源时出错: $e');
      }
    }

    _isInitialized = false;
  }
}

/// iOS 原生相机视图
class NativeCameraView extends StatefulWidget {
  final NativeCameraController? controller;
  final Widget? placeholder;
  final bool autoInitialize;
  final BoxFit fit;
  final Color backgroundColor;
  final VoidCallback? onCreated;
  final VoidCallback? onTap;
  final Function(Offset)? onFocusTap;

  const NativeCameraView({
    Key? key,
    this.controller,
    this.placeholder,
    this.autoInitialize = true,
    this.fit = BoxFit.cover,
    this.backgroundColor = Colors.black,
    this.onCreated,
    this.onTap,
    this.onFocusTap,
  }) : super(key: key);

  @override
  _NativeCameraViewState createState() => _NativeCameraViewState();
}

class _NativeCameraViewState extends State<NativeCameraView>
    with WidgetsBindingObserver {
  NativeCameraController? _controller;
  bool _isInitialized = false;

  // 用于跟踪缩放状态
  double _currentZoom = 1.0;
  bool _isZooming = false;

  // 用于跟踪对焦状态
  Offset? _focusPoint;
  bool _showFocusPoint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 使用提供的控制器或创建一个新的
    _controller = widget.controller ?? NativeCameraController(0);

    // 设置事件监听器
    _setupEventListeners();

    // 如果设置了自动初始化，初始化相机
    if (widget.autoInitialize) {
      _initializeCamera();
    }
  }

  @override
  void didUpdateWidget(NativeCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果控制器发生变化，更新控制器
    if (widget.controller != oldWidget.controller) {
      // 清理旧控制器
      if (_controller != null && _controller != widget.controller) {
        _controller!.dispose();
      }

      // 使用新控制器
      _controller = widget.controller ?? NativeCameraController(0);

      // 设置事件监听器
      _setupEventListeners();

      // 如果设置了自动初始化，初始化相机
      if (widget.autoInitialize) {
        _initializeCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用生命周期变化处理
    switch (state) {
      case AppLifecycleState.resumed:
        // 应用恢复前台，恢复预览
        if (_isInitialized) {
          _controller?.startPreview();
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 应用进入后台，停止预览
        _controller?.stopPreview();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 如果我们创建了控制器，需要释放它
    if (_controller != null && widget.controller == null) {
      _controller!.dispose();
    }

    super.dispose();
  }

  // 设置事件监听器
  void _setupEventListeners() {
    _controller?.setEventListener(
      onZoomChanged: _handleZoomChanged,
      onFocusChanged: _handleFocusChanged,
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import '../../services/camera/index.dart';

/// 原生相机控制器 - 用于控制原生相机视图
class NativeCameraController {
  final int _id;
  final MethodChannel _channel;
  bool _isInitialized = false;
  bool _isDisposed = false;

  // 相机状态
  bool _isPreviewActive = false;
  double _currentZoomLevel = 1.0;
  String _flashMode = 'off'; // 可能的值: 'off', 'on', 'auto'
  bool _isFrontCamera = false;

  // 相机事件监听器
  NativeCameraEventListener? _eventListener;

  /// 获取状态
  bool get isInitialized => _isInitialized;
  bool get isPreviewActive => _isPreviewActive;
  double get currentZoomLevel => _currentZoomLevel;
  String get flashMode => _flashMode;
  bool get isFrontCamera => _isFrontCamera;

  NativeCameraController(this._id)
      : _channel = MethodChannel('com.haohaopai.app/native_camera_view_$_id');

  /// 初始化相机
  Future<void> initialize() async {
    if (_isDisposed) {
      throw CameraException(
        'CAMERA_DISPOSED',
        '相机控制器已被释放，无法初始化',
      );
    }

    if (_isInitialized) {
      return; // 已经初始化
    }

    try {
      final result = await _channel.invokeMethod<bool>('initialize');
      _isInitialized = result ?? false;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '相机初始化失败');
    }
  }

  /// 开始预览
  Future<void> startPreview() async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    if (_isPreviewActive) {
      return; // 已经在预览中
    }

    try {
      final result = await _channel.invokeMethod<bool>('startPreview');
      _isPreviewActive = result ?? false;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '启动预览失败');
    }
  }

  /// 停止预览
  Future<void> stopPreview() async {
    if (!_isInitialized || !_isPreviewActive) {
      return; // 没有初始化或已经停止预览
    }

    try {
      final result = await _channel.invokeMethod<bool>('stopPreview');
      if (result ?? false) {
        _isPreviewActive = false;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '停止预览失败');
    }
  }

  /// 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'setZoomLevel',
        {'zoomLevel': zoomLevel},
      );

      if (result ?? false) {
        _currentZoomLevel = zoomLevel;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置缩放失败');
    }
  }

  /// 拍照
  Future<Uint8List> capturePhoto() async {
    if (!_isInitialized || !_isPreviewActive) {
      throw CameraException(
        'CAMERA_NOT_READY',
        '相机未准备好拍照',
      );
    }

    try {
      final photoData = await _channel.invokeMethod<Uint8List>('capturePhoto');
      if (photoData == null) {
        throw CameraException('CAPTURE_ERROR', '拍照失败，未返回图像数据');
      }
      return photoData;
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '拍照失败');
    }
  }

  /// 切换前后相机
  Future<void> switchCamera({required bool toFront}) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final result = await _channel.invokeMethod<bool>(
        'switchCamera',
        {'toFront': toFront},
      );

      if (result ?? false) {
        _isFrontCamera = toFront;
        // 重置缩放级别，因为切换相机后缩放会重置
        _currentZoomLevel = 1.0;
      }
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '切换相机失败');
    }
  }

  /// 切换闪光灯模式
  Future<String> toggleFlash() async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      final mode = await _channel.invokeMethod<String>('toggleFlash');
      if (mode != null) {
        _flashMode = mode;
        return mode;
      }
      throw CameraException('FLASH_ERROR', '切换闪光灯失败');
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '切换闪光灯失败');
    }
  }

  /// 设置对焦点
  Future<void> setFocusPoint(Offset point) async {
    if (!_isInitialized || !_isPreviewActive) {
      throw CameraException(
        'CAMERA_NOT_READY',
        '相机未准备好设置对焦点',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setFocusPoint',
        {'x': point.dx, 'y': point.dy},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置对焦点失败');
    }
  }

  /// 设置滤镜
  Future<void> setFilter(String filterName) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setFilter',
        {'filterName': filterName},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置滤镜失败');
    }
  }

  /// 设置纵横比
  Future<void> setAspectRatio(String ratio) async {
    if (!_isInitialized) {
      throw CameraException(
        'CAMERA_NOT_INITIALIZED',
        '相机尚未初始化',
      );
    }

    try {
      await _channel.invokeMethod<bool>(
        'setAspectRatio',
        {'ratio': ratio},
      );
    } on PlatformException catch (e) {
      throw CameraException(e.code, e.message ?? '设置纵横比失败');
    }
  }

  /// 获取相机能力
  Future<Map<String, dynamic>> getCameraCapabilities() async {
    try {
      final result = await _channel.invokeMethod('getCameraCapabilities');
      return result as Map<String, dynamic>;
    } on PlatformException catch (e) {
      debugPrint('获取相机能力失败: ${e.message}');
      return {};
    }
  }

  /// 设置事件监听器
  void setEventListener({
    required Function(Map<String, dynamic>) onZoomChanged,
    required Function(Map<String, dynamic>) onFocusChanged,
    required Function(Map<String, dynamic>) onOrientationChanged,
  }) {
    _eventListener?.dispose();

    _eventListener = NativeCameraEventListener(
      viewId: _id,
      onZoomChanged: onZoomChanged,
      onFocusChanged: onFocusChanged,
      onOrientationChanged: onOrientationChanged,
    );

    _eventListener!.startListening();
  }

  /// 释放资源
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    _isDisposed = true;
    _eventListener?.dispose();

    if (_isInitialized) {
      try {
        if (_isPreviewActive) {
          await stopPreview();
        }
        await _channel.invokeMethod<bool>('dispose');
      } catch (e) {
        debugPrint('释放相机资源时出错: $e');
      }
    }

    _isInitialized = false;
  }
}

/// iOS 原生相机视图
class NativeCameraView extends StatefulWidget {
  final NativeCameraController? controller;
  final Widget? placeholder;
  final bool autoInitialize;
  final BoxFit fit;
  final Color backgroundColor;
  final VoidCallback? onCreated;
  final VoidCallback? onTap;
  final Function(Offset)? onFocusTap;

  const NativeCameraView({
    Key? key,
    this.controller,
    this.placeholder,
    this.autoInitialize = true,
    this.fit = BoxFit.cover,
    this.backgroundColor = Colors.black,
    this.onCreated,
    this.onTap,
    this.onFocusTap,
  }) : super(key: key);

  @override
  _NativeCameraViewState createState() => _NativeCameraViewState();
}

class _NativeCameraViewState extends State<NativeCameraView>
    with WidgetsBindingObserver {
  NativeCameraController? _controller;
  bool _isInitialized = false;

  // 用于跟踪缩放状态
  double _currentZoom = 1.0;
  bool _isZooming = false;

  // 用于跟踪对焦状态
  Offset? _focusPoint;
  bool _showFocusPoint = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 使用提供的控制器或创建一个新的
    _controller = widget.controller ?? NativeCameraController(0);

    // 设置事件监听器
    _setupEventListeners();

    // 如果设置了自动初始化，初始化相机
    if (widget.autoInitialize) {
      _initializeCamera();
    }
  }

  @override
  void didUpdateWidget(NativeCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果控制器发生变化，更新控制器
    if (widget.controller != oldWidget.controller) {
      // 清理旧控制器
      if (_controller != null && _controller != widget.controller) {
        _controller!.dispose();
      }

      // 使用新控制器
      _controller = widget.controller ?? NativeCameraController(0);

      // 设置事件监听器
      _setupEventListeners();

      // 如果设置了自动初始化，初始化相机
      if (widget.autoInitialize) {
        _initializeCamera();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用生命周期变化处理
    switch (state) {
      case AppLifecycleState.resumed:
        // 应用恢复前台，恢复预览
        if (_isInitialized) {
          _controller?.startPreview();
        }
        break;

      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // 应用进入后台，停止预览
        _controller?.stopPreview();
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // 如果我们创建了控制器，需要释放它
    if (_controller != null && widget.controller == null) {
      _controller!.dispose();
    }

    super.dispose();
  }

  // 设置事件监听器
  void _setupEventListeners() {
    _controller?.setEventListener(
      onZoomChanged: _handleZoomChanged,
      onFocusChanged: _handleFocusChanged,
      onOrientationChanged: _handleOrientationChanged,
    );
  }

  // 处理缩放变化事件
  void _handleZoomChanged(Map<String, dynamic> event) {
    final type = event['type'] as String;

    if (type == 'zoomStarted') {
      setState(() {
        _isZooming = true;
      });
    } else if (type == 'zoomEnded') {
      setState(() {
        _isZooming = false;
        _currentZoom = event['zoomFactor'] as double;
      });
    } else if (type == 'zoomChanged') {
      setState(() {
        _currentZoom = event['zoomFactor'] as double;
      });
    }
  }

  // 处理对焦变化事件
  void _handleFocusChanged(Map<String, dynamic> event) {
    final x = event['x'] as double;
    final y = event['y'] as double;
    final success = event['success'] as bool;

    if (success) {
      setState(() {
        _focusPoint = Offset(x, y);
        _showFocusPoint = true;
      });

      // 2秒后隐藏对焦点
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showFocusPoint = false;
          });
        }
      });
    }
  }

  // 处理方向变化事件
  void _handleOrientationChanged(Map<String, dynamic> event) {
    // 这里可以处理设备方向变化
    // 由于Flutter会自动处理大部分方向适配，这里可能不需要特殊处理
  }

  // 初始化相机
  Future<void> _initializeCamera() async {
    try {
      await _controller?.initialize();
      await _controller?.startPreview();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });

        widget.onCreated?.call();
      }
    } catch (e) {
      debugPrint('初始化相机时出错: $e');
    }
  }

  // 处理点击事件
  void _handleTap(TapDownDetails details) {
    widget.onTap?.call();

    if (widget.onFocusTap != null) {
      // 将点击位置传递给回调
      final position = details.localPosition;
      widget.onFocusTap!(position);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 只有在iOS平台上才显示原生相机视图
    if (!Platform.isIOS) {
      return Center(
        child: widget.placeholder ?? const Text('原生相机仅支持iOS平台'),
      );
    }

    // 如果相机尚未初始化，显示占位符
    if (!_isInitialized) {
      return Container(
        color: widget.backgroundColor,
        child: widget.placeholder ??
            const Center(child: CircularProgressIndicator()),
      );
    }

    // 原生相机视图
    return GestureDetector(
      onTapDown: _handleTap,
      child: Stack(
        children: [
          // 原生相机视图
          UiKitView(
            viewType: 'com.haohaopai.app/native_camera_view',
            creationParams: <String, dynamic>{
              'backgroundColor': widget.backgroundColor.value,
              'fit': widget.fit.toString(),
            },
            creationParamsCodec: const StandardMessageCodec(),
          ),

          // 对焦点指示器
          if (_showFocusPoint && _focusPoint != null)
            Positioned(
              left: _focusPoint!.dx - 40,
              top: _focusPoint!.dy - 40,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.yellow, width: 2),
                ),
              ),
            ),

          // 缩放指示器
          if (_isZooming)
            Positioned(
              bottom: 50,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black45,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
