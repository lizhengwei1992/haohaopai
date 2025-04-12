import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../native_camera_service.dart';
import '../state/camera_state_manager.dart';
import '../layout/layout_params.dart';
import '../controls/flash_control.dart';
import '../controls/exposure_control.dart';
import '../controls/aspect_ratio_control.dart';
import '../controls/filter_control.dart';
import '../controls/camera_switch_control.dart';
import '../controls/zoom_control.dart';
import '../actions/capture_action.dart';
import '../actions/album_action.dart';
import '../actions/guide_action.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // 相机服务
  final CameraService _cameraService = CameraService.instance;
  final CameraStateManager _stateManager = CameraStateManager.instance;

  // 全局相机控制器
  NativeCameraController? _nativeCameraController;
  late CameraLayoutParams _layoutParams;

  // 相机状态
  bool _isInitialized = false;
  bool _useNativeCamera = true;

  @override
  void initState() {
    super.initState();

    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 初始化相机
    _initCamera();
  }

  // 初始化相机
  Future<void> _initCamera() async {
    try {
      // 检查全局相机服务是否已初始化
      final isReady = await _cameraService.isCameraReady();
      if (!isReady) {
        debugPrint('等待全局相机服务初始化...');
        await _cameraService.waitForInitialization();
      }

      // 获取或创建全局相机控制器
      _nativeCameraController =
          await _cameraService.getOrCreateCameraController(
        cameraId: 0,
        onCameraEvent: _handleCameraEvent,
      );

      setState(() {
        _isInitialized = true;
      });
    } catch (e) {
      // 忽略特定的插件异常，仅记录日志
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('初始化相机时遇到预期的MissingPluginException - 页面切换或热重载导致');
      } else {
        debugPrint('初始化相机时出错: $e');
      }

      // 无论如何都标记为初始化完成，以避免UI阻塞
      setState(() {
        _isInitialized = true;
      });
    }
  }

  // 初始化原生相机
  void _initializeNativeCamera() {
    debugPrint('相机视图创建完成，执行初始化');

    // 显式重新连接事件通道，确保事件通道在视图创建后连接
    Future.delayed(const Duration(milliseconds: 300), () {
      if (_nativeCameraController != null) {
        _nativeCameraController!.reconnectEventChannel();
      }
    });
  }

  // 切换到默认模式（当原生相机不可用时）
  void _switchToDefaultMode() {
    if (_useNativeCamera) {
      setState(() {
        _useNativeCamera = false;
      });
    }
  }

  // 处理相机事件
  void _handleCameraEvent(Map<String, dynamic> event) {
    final String type = event['type'] as String? ?? 'unknown';

    debugPrint('收到相机事件: $type');

    switch (type) {
      case 'initialized':
      case 'channelTest':
        // 通道连接测试事件，无需特殊处理
        debugPrint('相机事件通道连接成功: ${event['message']}');
        break;

      case 'focusChanged':
        if (event['success'] == true) {
          final x = event['x'] as double?;
          final y = event['y'] as double?;

          if (x != null && y != null) {
            // 更新焦点状态
            _stateManager.updateFocus(Offset(x, y), true, true);

            // 3秒后隐藏对焦点
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                _stateManager.hideFocusPoint();
              }
            });
          }
        }
        break;

      case 'zoomChanged':
        final zoom = event['zoomFactor'] as double?;
        if (zoom != null && mounted) {
          _stateManager.currentZoomLevel = zoom;
        }
        break;

      case 'error':
        debugPrint('相机错误: ${event['message']}');
        break;

      default:
        debugPrint('未处理的相机事件类型: $type');
        break;
    }
  }

  // 设置对焦点
  void _setFocusPoint(Offset position, BoxConstraints constraints) {
    if (_nativeCameraController != null) {
      // 计算相对于相机视图的比例坐标 (0.0-1.0)
      final double relativeX = position.dx / constraints.maxWidth;
      final double relativeY = position.dy / constraints.maxHeight;

      // 应用对焦
      _nativeCameraController!
          .setFocusPoint(relativeX, relativeY)
          .then((success) {
        if (success) {
          _stateManager.updateFocus(position, true, true);

          // 3秒后隐藏对焦点
          Future.delayed(const Duration(seconds: 3), () {
            _stateManager.hideFocusPoint();
          });
        }
      });
    } else {
      // 模拟对焦点
      _stateManager.updateFocus(position, true, true);

      // 3秒后隐藏对焦点
      Future.delayed(const Duration(seconds: 3), () {
        _stateManager.hideFocusPoint();
      });
    }
  }

  @override
  void dispose() {
    // 不再释放相机控制器，而是保留全局实例
    // 只在应用退出时才真正释放资源

    // 移除生命周期监听
    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 根据应用生命周期变化处理相机
    if (!_isInitialized) return;

    switch (state) {
      case AppLifecycleState.resumed:
        debugPrint('应用回到前台，恢复相机');
        _nativeCameraController?.resumePreview();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        debugPrint('应用进入后台，暂停相机');
        _nativeCameraController?.pausePreview();
        break;
      case AppLifecycleState.detached:
        // 应用被终止，相机资源会在dispose中处理
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 初始化布局参数
    _layoutParams = CameraLayoutParams(context);

    // 监听相机状态变化
    return ListenableBuilder(
      listenable: _stateManager,
      builder: (context, child) {
        // 根据当前宽高比获取预览参数
        final previewParams =
            _layoutParams.getPreviewParams(_stateManager.currentAspectRatio);

        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Stack(
              children: [
                // 主要内容区域，包含相机预览和大部分UI元素
                GestureDetector(
                  onTap: () {
                    if (_stateManager.showFilterSelector) {
                      _stateManager.showFilterSelector = false;
                    }
                  },
                  child: Stack(
                    children: [
                      // 相机预览 - 放在最底层，位置根据固定中心点计算
                      Positioned(
                        top: previewParams.topPosition,
                        left: 0,
                        right: 0,
                        child: SizedBox(
                          width: previewParams.width,
                          height: previewParams.height,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 相机预览 - 使用原生相机或占位符表示
                                GestureDetector(
                                  onTapDown: (TapDownDetails details) {
                                    // 获取点击位置
                                    final RenderBox box =
                                        context.findRenderObject() as RenderBox;
                                    final Offset localPosition = box
                                        .globalToLocal(details.globalPosition);

                                    // 计算点击位置相对于预览框的偏移
                                    final Offset adjustedPosition = Offset(
                                        localPosition.dx,
                                        localPosition.dy -
                                            previewParams.topPosition);

                                    // 设置对焦点
                                    _setFocusPoint(
                                        adjustedPosition,
                                        BoxConstraints(
                                            maxWidth: previewParams.width,
                                            maxHeight: previewParams.height));
                                  },

                                  // 添加手势缩放功能
                                  onScaleStart: (details) {
                                    _stateManager.baseScaleLevel =
                                        _stateManager.currentZoomLevel;
                                  },
                                  onScaleUpdate: (details) {
                                    if (details.scale != 1.0) {
                                      // 计算新的缩放级别
                                      double newZoom =
                                          _stateManager.baseScaleLevel *
                                              details.scale;

                                      // 通过ZoomControl组件的方法设置缩放
                                      const ZoomControl().setZoomLevel(newZoom);
                                    }
                                  },
                                  onScaleEnd: (details) {
                                    // 更新基础缩放级别为当前缩放级别
                                    _stateManager.baseScaleLevel =
                                        _stateManager.currentZoomLevel;
                                  },

                                  child: _useNativeCamera &&
                                          _nativeCameraController != null
                                      ? Builder(
                                          builder: (context) {
                                            try {
                                              return Container(
                                                color: Colors.black,
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    // 如果原生相机初始化成功，显示NativeCameraView
                                                    if (Platform.isIOS)
                                                      NativeCameraView(
                                                        controller:
                                                            _nativeCameraController,
                                                        backgroundColor:
                                                            const Color(
                                                                0xFF1A1A1A),
                                                        onCreated: () {
                                                          _initializeNativeCamera();
                                                        },
                                                      ),
                                                    // 同时显示一个半透明覆盖层，保持接收手势事件
                                                    Container(
                                                      color: Colors.transparent,
                                                    )
                                                  ],
                                                ),
                                              );
                                            } catch (e) {
                                              debugPrint(
                                                  '创建NativeCameraView时发生错误: $e');
                                              Future.microtask(
                                                  () => _switchToDefaultMode());
                                              return Container(
                                                color: const Color(0xFF1A1A1A),
                                                child: const Center(
                                                  child: Text(
                                                    '相机预览区域 (降级模式)',
                                                    style: TextStyle(
                                                        color: Colors.white60,
                                                        fontSize: 16),
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                        )
                                      : Container(
                                          color: const Color(0xFF1A1A1A),
                                          child: const Center(
                                            child: Text(
                                              '相机预览区域',
                                              style: TextStyle(
                                                  color: Colors.white60,
                                                  fontSize: 16),
                                            ),
                                          ),
                                        ),
                                ),

                                // 对焦点
                                if (_stateManager.showFocusPoint &&
                                    _stateManager.focusPoint != null)
                                  Positioned(
                                    left: _stateManager.focusPoint!.dx - 40,
                                    top: _stateManager.focusPoint!.dy - 40,
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: _stateManager.focusSuccess
                                              ? Colors.green
                                              : Colors.yellow,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(40),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 顶部控制栏 - 返回按钮（移到左上角）
                      Positioned(
                        top: _layoutParams.topPadding,
                        left: 16, // 改为左侧
                        child: GestureDetector(
                          onTap: () {
                            Navigator.pop(context);
                          },
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_back_ios,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // 缩放控制（相机预览框下沿向上10px）
                      Positioned(
                        top: previewParams.zoomControlY - 40, // 位置调整，减去控件高度
                        left: 0,
                        right: 0,
                        child: const ZoomControl(),
                      ),

                      // 相机控制按钮行（相机预览框下沿向下10px）
                      Positioned(
                        top: previewParams.cameraControlsY,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: const [
                            FlashControl(),
                            ExposureControl(),
                            AspectRatioControl(),
                            FilterControl(),
                            CameraSwitchControl(),
                          ],
                        ),
                      ),

                      // 底部拍照按钮区域（相机控制按钮下沿向下10px）
                      Positioned(
                        top: previewParams.bottomControlsY,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 96, // 使用固定高度，确保足够空间
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // 中间拍摄按钮
                              const Center(child: CaptureAction()),

                              // 左右两侧按钮的容器
                              Container(
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 40.0),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      // 左侧相册按钮
                                      AlbumAction(),
                                      // 右侧教我拍按钮
                                      GuideAction(),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 滤镜选择器 - 单独放在外层Stack中，使其能够接收点击事件
                if (_stateManager.showFilterSelector)
                  Positioned(
                    top: previewParams.bottomPosition + 10,
                    left: 0,
                    right: 0,
                    child: const FilterSelector(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
