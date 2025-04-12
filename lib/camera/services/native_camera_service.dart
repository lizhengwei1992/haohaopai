import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 原生相机服务，提供与iOS原生相机通信的接口
class NativeCameraService {
  // 平台通道
  static const MethodChannel _channel =
      MethodChannel('com.haohaopai.app/native_camera');

  // 初始化完成的Completer
  final Completer<bool> _initializationCompleter = Completer<bool>();

  // 是否已初始化
  bool _isInitialized = false;

  // 全局相机控制器实例
  NativeCameraController? _globalCameraController;

  // 私有构造函数确保单例模式
  NativeCameraService._();

  // 静态实例
  static final NativeCameraService instance = NativeCameraService._();

  /// 获取全局相机控制器
  NativeCameraController? getGlobalCameraController() {
    return _globalCameraController;
  }

  /// 创建或获取全局相机控制器
  Future<NativeCameraController> getOrCreateCameraController({
    required int cameraId,
    Function(Map<String, dynamic>)? onCameraEvent,
  }) async {
    // 如果全局控制器已存在，更新事件处理器并返回
    if (_globalCameraController != null) {
      _globalCameraController!.updateEventHandler(onCameraEvent);
      return _globalCameraController!;
    }

    // 创建新的相机控制器
    _globalCameraController = NativeCameraController(
      cameraId: cameraId,
      onCameraEvent: onCameraEvent,
    );

    return _globalCameraController!;
  }

  /// 释放全局相机控制器
  void releaseGlobalCameraController() {
    _globalCameraController?.dispose();
    _globalCameraController = null;
  }

  /// 检查设备是否支持原生相机
  Future<bool> isNativeCameraSupported() async {
    if (!Platform.isIOS) return false;

    try {
      final bool isSupported =
          await _channel.invokeMethod('isNativeCameraSupported');
      return isSupported;
    } on PlatformException catch (e) {
      debugPrint('检查原生相机支持时出错: ${e.message}');
      return false;
    }
  }

  /// 获取相机能力和配置信息
  Future<Map<String, dynamic>> getCameraCapabilities() async {
    if (!Platform.isIOS) return {};

    try {
      final result = await _channel.invokeMethod('getCameraCapabilities');
      return Map<String, dynamic>.from(result as Map);
    } on PlatformException catch (e) {
      debugPrint('获取相机能力时出错: ${e.message}');
      return {};
    }
  }

  /// 检查相机是否已准备就绪
  Future<bool> isCameraReady() async {
    if (!Platform.isIOS) return false;

    // 如果已经完成了初始化，直接返回true
    if (_isInitialized) return true;

    try {
      // 查询原生端相机状态
      final bool isReady = await _channel.invokeMethod('isCameraReady');
      return isReady;
    } on PlatformException catch (e) {
      debugPrint('检查相机状态时出错: ${e.message}');
      return false;
    }
  }

  /// 等待相机初始化完成
  Future<bool> waitForInitialization() async {
    if (_isInitialized) return true;

    // 如果初始化器还未完成，等待结果
    return _initializationCompleter.future;
  }

  /// 初始化相机
  Future<bool> initializeCamera() async {
    // 如果已经初始化或非iOS平台，无需再次初始化
    if (_isInitialized) return true;
    if (!Platform.isIOS) {
      _initializationCompleter.complete(false);
      return false;
    }

    try {
      final bool success = await _channel.invokeMethod('initializeCamera');

      _isInitialized = success;

      // 完成初始化器
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(success);
      }

      return success;
    } on PlatformException catch (e) {
      debugPrint('初始化相机时出错: ${e.message}');

      // 初始化失败，完成初始化器
      if (!_initializationCompleter.isCompleted) {
        _initializationCompleter.complete(false);
      }

      return false;
    }
  }

  /// 暂停相机
  Future<void> pauseCamera() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('pauseCamera');
    } on PlatformException catch (e) {
      debugPrint('暂停相机时出错: ${e.message}');
    }
  }

  /// 恢复相机
  Future<void> resumeCamera() async {
    if (!Platform.isIOS) return;

    try {
      await _channel.invokeMethod('resumeCamera');
    } on PlatformException catch (e) {
      debugPrint('恢复相机时出错: ${e.message}');
    }
  }
}

/// 原生相机控制器类
class NativeCameraController {
  /// 相机视图ID（用于标识特定的相机实例）
  final int cameraId;

  /// 方法通道，用于调用原生相机方法
  late final MethodChannel _methodChannel;

  /// 事件通道，用于接收相机事件
  late final EventChannel _eventChannel;

  /// 事件监听器
  StreamSubscription<dynamic>? _eventSubscription;

  /// 相机事件回调
  final void Function(Map<String, dynamic>)? onCameraEvent;

  /// 实际使用的事件处理器（可更新）
  void Function(Map<String, dynamic>)? _eventHandler;

  /// 事件通道是否连接成功
  bool _isEventChannelConnected = false;

  /// 事件通道连接重试次数
  int _eventChannelRetryCount = 0;

  /// 最大重试次数
  static const int _maxRetryCount = 3;

  /// 私有构造函数
  NativeCameraController._({
    required this.cameraId,
    this.onCameraEvent,
  }) {
    // 初始化时设置事件处理器
    _eventHandler = onCameraEvent;
  }

  /// 创建实例的工厂方法
  factory NativeCameraController(
      {required int cameraId, Function(Map<String, dynamic>)? onCameraEvent}) {
    final controller = NativeCameraController._(
        cameraId: cameraId, onCameraEvent: onCameraEvent);
    controller._methodChannel =
        MethodChannel('com.haohaopai.app/native_camera_view_$cameraId');
    controller._eventChannel =
        EventChannel('com.haohaopai.app/native_camera_events_$cameraId');

    // 延迟设置事件通道，给原生代码足够时间注册
    if (onCameraEvent != null) {
      // 先等待一段时间，让原生视图有足够时间进行初始化和注册
      Future.delayed(const Duration(milliseconds: 500), () {
        controller._setupEventChannel();
      });
    }
    return controller;
  }

  /// 设置事件通道
  void _setupEventChannel() {
    // 避免重复设置
    if (_isEventChannelConnected || _eventSubscription != null) {
      return;
    }

    try {
      _eventChannelRetryCount++;
      debugPrint(
          '正在连接相机事件通道: ${_eventChannel.name} (尝试 $_eventChannelRetryCount/$_maxRetryCount)');

      // 使用try-catch包裹事件流订阅
      _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
        (dynamic event) {
          // 成功收到事件，标记为已连接
          _isEventChannelConnected = true;
          _eventChannelRetryCount = 0;

          if (event is Map) {
            final eventData = Map<String, dynamic>.from(event);
            debugPrint('收到相机事件: ${eventData['type']}');
            _eventHandler?.call(eventData);
          } else {
            debugPrint('收到未知格式的相机事件: $event');
          }
        },
        onError: (dynamic error) {
          // 错误处理
          if (error.toString().contains('MissingPluginException')) {
            debugPrint('事件通道MissingPluginException - 需要重试');

            // 释放当前订阅
            _eventSubscription?.cancel();
            _eventSubscription = null;
            _isEventChannelConnected = false;

            // 如果还没有超过最大重试次数，延迟后重试
            if (_eventChannelRetryCount < _maxRetryCount) {
              Future.delayed(
                  Duration(milliseconds: 1000 * _eventChannelRetryCount), () {
                if (!_isEventChannelConnected && _eventHandler != null) {
                  debugPrint('尝试重新连接事件通道');
                  _setupEventChannel();
                }
              });
            } else {
              debugPrint('事件通道连接失败，已达到最大重试次数 $_maxRetryCount');
            }
          } else {
            debugPrint('相机事件通道错误: $error');
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      // 处理其他异常
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('设置事件通道时遇到MissingPluginException - 稍后将重试');

        // 如果是MissingPluginException，延迟后重试
        if (_eventChannelRetryCount < _maxRetryCount) {
          Future.delayed(Duration(milliseconds: 1000 * _eventChannelRetryCount),
              () {
            if (!_isEventChannelConnected && _eventHandler != null) {
              debugPrint('尝试重新连接事件通道');
              _setupEventChannel();
            }
          });
        }
      } else {
        debugPrint('设置事件通道时出错: $e');
      }
    }
  }

  /// 重新连接事件通道（主动调用）
  void reconnectEventChannel() {
    // 如果已连接，先断开
    if (_eventSubscription != null) {
      _eventSubscription?.cancel();
      _eventSubscription = null;
    }

    _isEventChannelConnected = false;
    _eventChannelRetryCount = 0; // 重置重试计数

    // 如果有回调，尝试重新连接
    if (_eventHandler != null) {
      _setupEventChannel();
    }
  }

  /// 初始化相机
  Future<bool> initialize() async {
    try {
      final bool success = await _methodChannel.invokeMethod('initialize');
      return success;
    } on PlatformException catch (e) {
      debugPrint('初始化相机时出错: ${e.message}');
      return false;
    }
  }

  /// 开始预览
  Future<bool> startPreview() async {
    try {
      final bool success = await _methodChannel.invokeMethod('startPreview');
      return success;
    } on PlatformException catch (e) {
      debugPrint('开始预览时出错: ${e.message}');
      return false;
    }
  }

  /// 停止预览
  Future<bool> stopPreview() async {
    try {
      final bool success = await _methodChannel.invokeMethod('stopPreview');
      return success;
    } on PlatformException catch (e) {
      debugPrint('停止预览时出错: ${e.message}');
      return false;
    }
  }

  /// 暂停预览
  Future<bool> pausePreview() async {
    try {
      final bool success = await _methodChannel.invokeMethod('pausePreview');
      return success;
    } on PlatformException catch (e) {
      debugPrint('暂停预览时出错: ${e.message}');
      return false;
    }
  }

  /// 恢复预览
  Future<bool> resumePreview() async {
    try {
      final bool success = await _methodChannel.invokeMethod('resumePreview');
      return success;
    } on PlatformException catch (e) {
      debugPrint('恢复预览时出错: ${e.message}');
      return false;
    }
  }

  /// 拍照
  Future<Uint8List?> capturePhoto() async {
    try {
      final result = await _methodChannel.invokeMethod('capturePhoto');
      return result != null ? result as Uint8List : null;
    } on PlatformException catch (e) {
      debugPrint('拍照时出错: ${e.message}');
      return null;
    }
  }

  /// 切换相机
  Future<bool> switchCamera({required bool toFront}) async {
    try {
      final bool success = await _methodChannel.invokeMethod(
        'switchCamera',
        {'toFront': toFront},
      );
      return success;
    } on PlatformException catch (e) {
      debugPrint('切换相机时出错: ${e.message}');
      return false;
    }
  }

  /// 是否为前置相机
  Future<bool> isFrontCamera() async {
    try {
      final bool isFront = await _methodChannel.invokeMethod('isFrontCamera');
      return isFront;
    } on PlatformException catch (e) {
      debugPrint('检查相机方向时出错: ${e.message}');
      return false;
    }
  }

  /// 设置缩放级别
  Future<bool> setZoomLevel(double zoomLevel) async {
    try {
      final bool success = await _methodChannel.invokeMethod(
        'setZoomLevel',
        {'zoomLevel': zoomLevel},
      );
      return success;
    } on PlatformException catch (e) {
      debugPrint('设置缩放级别时出错: ${e.message}');
      return false;
    }
  }

  /// 设置闪光灯模式
  Future<bool> setFlashMode(String mode) async {
    try {
      final bool success = await _methodChannel.invokeMethod(
        'setFlashMode',
        {'mode': mode},
      );
      return success;
    } on PlatformException catch (e) {
      debugPrint('设置闪光灯模式时出错: ${e.message}');
      return false;
    }
  }

  /// 设置对焦点
  Future<bool> setFocusPoint(double x, double y) async {
    try {
      final bool success = await _methodChannel.invokeMethod(
        'setFocusPoint',
        {'x': x, 'y': y},
      );
      return success;
    } on PlatformException catch (e) {
      debugPrint('设置对焦点时出错: ${e.message}');
      return false;
    }
  }

  /// 释放资源
  void dispose() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  /// 更新事件处理器
  void updateEventHandler(Function(Map<String, dynamic>)? newEventHandler) {
    _eventHandler = newEventHandler;

    // 如果已经连接事件通道，不需要重新设置
    // 如果未连接，且有新的处理器，则重新连接
    if (!_isEventChannelConnected && _eventHandler != null) {
      reconnectEventChannel();
    }
  }
}

/// 原生相机视图组件
class NativeCameraView extends StatefulWidget {
  /// 相机控制器
  final NativeCameraController? controller;

  /// 创建完成回调
  final VoidCallback? onCreated;

  /// 视图宽度
  final double width;

  /// 视图高度
  final double height;

  /// 背景颜色
  final Color backgroundColor;

  /// 创建原生相机视图
  const NativeCameraView({
    Key? key,
    this.controller,
    this.onCreated,
    this.width = double.infinity,
    this.height = double.infinity,
    this.backgroundColor = Colors.black,
  }) : super(key: key);

  @override
  State<NativeCameraView> createState() => _NativeCameraViewState();
}

class _NativeCameraViewState extends State<NativeCameraView>
    with WidgetsBindingObserver {
  // 内部控制器（当未提供外部控制器时使用）
  NativeCameraController? _internalController;

  // 当前实际使用的控制器
  NativeCameraController? get _controller =>
      widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();

    // 添加观察者以监听应用生命周期变化
    WidgetsBinding.instance.addObserver(this);

    // 如果没有提供外部控制器，创建内部控制器
    if (widget.controller == null) {
      _internalController = NativeCameraController(
        cameraId: DateTime.now().millisecondsSinceEpoch,
        onCameraEvent: _handleCameraEvent,
      );
    }
  }

  @override
  void didUpdateWidget(NativeCameraView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 如果控制器发生变化，更新处理逻辑
    if (widget.controller != oldWidget.controller) {
      if (widget.controller == null) {
        // 从外部控制器切换到内部控制器
        _internalController = NativeCameraController(
          cameraId: DateTime.now().millisecondsSinceEpoch,
          onCameraEvent: _handleCameraEvent,
        );
      } else if (oldWidget.controller == null) {
        // 从内部控制器切换到外部控制器，清理内部控制器
        _internalController?.dispose();
        _internalController = null;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 监听应用生命周期变化，以便正确处理相机资源
    switch (state) {
      case AppLifecycleState.resumed:
        // 应用回到前台，恢复相机
        _resumeCameraIfNeeded();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        // 应用进入后台，暂停相机
        _pauseCameraIfNeeded();
        break;
      case AppLifecycleState.detached:
        // 应用被终止，不做特殊处理（dispose会处理资源释放）
        break;
    }
  }

  void _handleCameraEvent(Map<String, dynamic> event) {
    // 处理来自相机的事件，如需要可以在这里添加更多逻辑
    final String type = event['type'] as String? ?? 'unknown';

    switch (type) {
      case 'initialized':
        debugPrint('相机事件: 初始化完成');
        break;
      case 'error':
        debugPrint('相机事件: 错误 - ${event['message']}');
        break;
      case 'zoomChanged':
        debugPrint('相机事件: 缩放变化 - ${event['zoomFactor']}');
        break;
      default:
        debugPrint('相机事件: $type - $event');
        break;
    }
  }

  Future<void> _pauseCameraIfNeeded() async {
    try {
      await _controller?.pausePreview();
    } catch (e) {
      debugPrint('暂停相机时出错: $e');
    }
  }

  Future<void> _resumeCameraIfNeeded() async {
    try {
      await _controller?.resumePreview();
    } catch (e) {
      debugPrint('恢复相机时出错: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果不是iOS平台，显示一个占位符
    if (!Platform.isIOS) {
      return Container(
        width: widget.width,
        height: widget.height,
        color: widget.backgroundColor,
        child: const Center(
          child: Text(
            '仅支持iOS平台',
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    // 创建参数
    final Map<String, dynamic> creationParams = {
      'controllerId': _controller?.cameraId,
      'backgroundColor': widget.backgroundColor.value,
    };

    // 返回原生视图
    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: UiKitView(
        viewType: 'com.haohaopai.app/native_camera_view',
        creationParams: creationParams,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (int id) {
          // 视图创建完成后初始化和启动相机
          _initializeAndStartPreview();

          // 调用创建完成回调
          if (widget.onCreated != null) {
            widget.onCreated!();
          }
        },
      ),
    );
  }

  // 初始化并启动预览
  Future<void> _initializeAndStartPreview() async {
    try {
      // 初始化相机
      final initialized = await _controller?.initialize() ?? false;
      if (initialized) {
        // 启动预览
        await _controller?.startPreview();
      }
    } catch (e) {
      debugPrint('初始化和启动相机预览时出错: $e');
    }
  }

  @override
  void dispose() {
    // 清理内部创建的控制器
    if (_internalController != null) {
      _internalController!.dispose();
      _internalController = null;
    }

    // 移除观察者
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }
}
