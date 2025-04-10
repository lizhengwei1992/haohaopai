import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_camera_service.dart';
import 'camera_control.dart';
import 'init_parameter.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // 全局相机控制器
  NativeCameraController? _nativeCameraController;
  CameraControl? _cameraControl;
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
      final isReady = await NativeCameraService.instance.isCameraReady();
      if (!isReady) {
        debugPrint('等待全局相机服务初始化...');
        await NativeCameraService.instance.waitForInitialization();
      }

      // 创建相机控制器并增加错误捕获
      _nativeCameraController = NativeCameraController(
        cameraId: 0,
        onCameraEvent: _handleCameraEvent,
      );

      // 初始化相机控制类
      _cameraControl = CameraControl(
        onStateUpdate: (VoidCallback fn) {
          if (mounted) {
            setState(fn);
          }
        },
        nativeCameraController: _nativeCameraController,
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
    Future.delayed(Duration(milliseconds: 300), () {
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
            setState(() {
              _cameraControl?.focusPoint = Offset(x, y);
              _cameraControl?.showFocusPoint = true;
              _cameraControl?.focusSuccess = true;
            });

            // 3秒后隐藏对焦点
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _cameraControl?.showFocusPoint = false;
                });
              }
            });
          }
        }
        break;

      case 'zoomChanged':
        final zoom = event['zoomFactor'] as double?;
        if (zoom != null && mounted) {
          setState(() {
            _cameraControl?.currentZoomLevel = zoom;
          });
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

  @override
  void dispose() {
    // 安全释放相机控制器
    try {
      _nativeCameraController?.dispose();
    } catch (e) {
      debugPrint('释放相机资源时出错: $e');
    }

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
    if (!_isInitialized || _cameraControl == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 初始化布局参数
    _layoutParams = CameraLayoutParams(context);

    // 创建UI控件构建器
    final controlWidgets = CameraControlWidgets(context, _cameraControl!);

    // 根据当前宽高比获取预览参数
    final previewParams =
        _layoutParams.getPreviewParams(_cameraControl!.currentAspectRatio);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 主要内容区域，包含相机预览和大部分UI元素
            GestureDetector(
              onTap: () {
                if (_cameraControl!.showFilterSelector) {
                  setState(() {
                    _cameraControl!.showFilterSelector = false;
                  });
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
                                final Offset localPosition =
                                    box.globalToLocal(details.globalPosition);

                                // 计算点击位置相对于预览框的偏移
                                final Offset adjustedPosition = Offset(
                                    localPosition.dx,
                                    localPosition.dy -
                                        previewParams.topPosition);

                                // 设置对焦点
                                _cameraControl!.setFocusPoint(
                                    adjustedPosition,
                                    BoxConstraints(
                                        maxWidth: previewParams.width,
                                        maxHeight: previewParams.height));
                              },

                              // 添加手势缩放功能
                              onScaleStart: (details) {
                                _cameraControl!.baseScaleLevel =
                                    _cameraControl!.currentZoomLevel;
                              },
                              onScaleUpdate: (details) {
                                if (details.scale != 1.0) {
                                  // 计算新的缩放级别
                                  double newZoom =
                                      _cameraControl!.baseScaleLevel *
                                          details.scale;

                                  // 设置新的缩放级别
                                  _cameraControl!.setZoomLevel(newZoom);
                                }
                              },
                              onScaleEnd: (details) {
                                // 更新基础缩放级别为当前缩放级别
                                _cameraControl!.baseScaleLevel =
                                    _cameraControl!.currentZoomLevel;
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
                                                        const Color(0xFF1A1A1A),
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
                            if (_cameraControl!.showFocusPoint &&
                                _cameraControl!.focusPoint != null)
                              Positioned(
                                left: _cameraControl!.focusPoint!.dx - 40,
                                top: _cameraControl!.focusPoint!.dy - 40,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: _cameraControl!.focusSuccess
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
                    child: controlWidgets.buildZoomControl(),
                  ),

                  // 相机控制按钮行（相机预览框下沿向下10px）
                  Positioned(
                    top: previewParams.cameraControlsY,
                    left: 0,
                    right: 0,
                    child: controlWidgets.buildCameraControlButtons(),
                  ),

                  // 底部拍照按钮区域（相机控制按钮下沿向下10px）
                  Positioned(
                    top: previewParams.bottomControlsY,
                    left: 0,
                    right: 0,
                    child: controlWidgets.buildBottomControls(),
                  ),
                ],
              ),
            ),

            // 滤镜选择器 - 单独放在外层Stack中，使其能够接收点击事件
            if (_cameraControl!.showFilterSelector)
              Positioned(
                top: previewParams.bottomPosition + 10,
                left: 0,
                right: 0,
                child: controlWidgets.buildFilterSelector(),
              ),
          ],
        ),
      ),
    );
  }
}
