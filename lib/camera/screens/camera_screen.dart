import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/camera_service.dart';
import '../services/native_camera_service.dart';
import '../state/camera_state_manager.dart';
import '../layout/layout_params.dart';
import '../controls/flash_control.dart';
import '../controls/exposure_control.dart';
import '../controls/aspect_ratio_control.dart';
import '../controls/grid_control.dart';
import '../controls/camera_switch_control.dart';
import '../controls/zoom_control.dart';
import '../actions/capture_action.dart';
import '../actions/album_action.dart';
import '../actions/guide_action.dart';
import '../../aitips/providers/ai_tip_provider.dart';
import '../../aitips/widgets/ai_tip_animation.dart';

// 网格线绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    // 绘制水平线(2条，分成3份)
    final double cellHeight = size.height / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(0, cellHeight * i),
        Offset(size.width, cellHeight * i),
        paint,
      );
    }

    // 绘制垂直线(2条，分成3份)
    final double cellWidth = size.width / 3;
    for (int i = 1; i < 3; i++) {
      canvas.drawLine(
        Offset(cellWidth * i, 0),
        Offset(cellWidth * i, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

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
  double _currentZoomLevel = 1.0; // 当前缩放级别

  @override
  void initState() {
    super.initState();

    // 添加应用生命周期监听
    WidgetsBinding.instance.addObserver(this);

    // 确保进入相机页面时"教我拍"功能是干净的初始状态
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final aiTipProvider = Provider.of<AiTipProvider>(context, listen: false);
      aiTipProvider.reset();
      debugPrint('📸 进入相机页面，重置教我拍状态到初始状态');
    });

    // 初始化相机
    _initCamera();
  }

  // 初始化相机
  Future<void> _initCamera() async {
    try {
      // 初始化相机状态
      if (!_stateManager.isCameraInitialized) {
        await _stateManager.initializeCameraSettings();
      }

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

      // 应用当前的相机设置
      _applyCurrentCameraSettings();

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

  // 应用当前相机设置
  Future<void> _applyCurrentCameraSettings() async {
    if (_nativeCameraController == null) return;

    try {
      // 获取相机类型和设备信息
      final cameraType = _stateManager.currentCameraType;
      final hasVirtualDeviceSupport = Platform.isIOS &&
          (_stateManager.cameraCapabilities['hasVirtualDeviceSupport'] ??
              false);
      final hasUltraWide =
          _stateManager.cameraCapabilities['hasUltraWide'] ?? false;

      // 获取设备切换点
      List<double> switchPoints = [];
      if (hasVirtualDeviceSupport) {
        final rawSwitchPoints =
            _stateManager.cameraCapabilities['virtualDeviceSwitchPoints'] ?? [];
        if (rawSwitchPoints is List) {
          switchPoints = List<double>.from(
              rawSwitchPoints.map((x) => x is double ? x : x.toDouble()));
        }
      }

      double zoomLevel = 1.0;

      // 首次启动相机与返回相机页面逻辑区分处理
      if (_stateManager.isFirstLaunch) {
        // 首次启动时，设置默认缩放因子
        if (cameraType == 'back') {
          // 对于后置相机，如果是DualWideCamera，使用2.0作为缩放因子显示1.0x视角
          if (hasVirtualDeviceSupport &&
              hasUltraWide &&
              switchPoints.isNotEmpty &&
              switchPoints[0] == 2.0) {
            zoomLevel = 2.0; // 对应1.0x广角
          } else {
            zoomLevel = 1.0; // 普通设备
          }
        } else if (cameraType == 'front') {
          // 前置相机固定使用1.0缩放因子，显示为1.0x原始画面
          zoomLevel = 1.0;
        }

        // 首次启动标志改为false
        _stateManager.isFirstLaunch = false;
      } else {
        // 从其他页面返回相机页面时，恢复上次的缩放状态
        if (cameraType == 'back') {
          zoomLevel = _stateManager.lastBackCameraZoomLevel;
        } else if (cameraType == 'front') {
          zoomLevel = _stateManager.lastFrontCameraZoomLevel;
        }
        debugPrint(
            '恢复上次${cameraType == 'back' ? '后置' : '前置'}相机缩放状态: $zoomLevel');
      }

      // 更新缩放级别
      _stateManager.currentZoomLevel = zoomLevel;
      await _nativeCameraController!.setZoomLevel(zoomLevel);
      debugPrint('应用相机设置缩放级别: $zoomLevel');

      // 应用其他设置
      // 注意：这里可以添加更多设置的应用，如闪光灯、曝光等
    } catch (e) {
      debugPrint('应用相机设置时出错: $e');
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

    // 延迟设置初始缩放，确保在相机视图完全加载并且事件通道连接后设置
    Future.delayed(const Duration(milliseconds: 800), () {
      if (_nativeCameraController != null) {
        // 再次应用当前相机设置，确保缩放因子正确
        _applyCurrentCameraSettings();
        debugPrint('延迟应用相机设置完成');
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

      case 'zoomChanged':
        final zoomFactor = event['zoomFactor'] as double?;
        if (zoomFactor != null && mounted) {
          // 更新显示的缩放级别
          setState(() {
            _currentZoomLevel = zoomFactor;
          });

          // 同步更新状态管理器的缩放级别
          _stateManager.currentZoomLevel = zoomFactor;

          // 如果正在缩放引起镜头切换，重置状态
          if (_stateManager.isCameraChanging) {
            _stateManager.isCameraChanging = false;
            debugPrint('镜头切换完成，重置isCameraChanging状态');
          }
        }
        break;

      case 'virtualDeviceZoomChanged':
        // 处理虚拟设备丝滑缩放事件 - iOS 13+设备的特殊事件
        final zoomFactor = event['zoomFactor'] as double?;
        final isSmooth = event['isSmooth'] as bool? ?? false;
        if (zoomFactor != null && mounted) {
          debugPrint('虚拟摄像头缩放: $zoomFactor, 丝滑切换: $isSmooth');

          // 更新显示的缩放级别
          setState(() {
            _currentZoomLevel = zoomFactor;
          });

          // 同步更新状态管理器的缩放级别
          _stateManager.currentZoomLevel = zoomFactor;

          // 如果正在缩放引起镜头切换，重置状态
          if (_stateManager.isCameraChanging) {
            _stateManager.isCameraChanging = false;
            debugPrint('虚拟镜头切换完成，重置isCameraChanging状态');
          }
        }
        break;

      case 'flashModeChanged':
        final mode = event['mode'] as String?;
        if (mode != null && mounted) {
          _stateManager.flashMode = mode;
          _stateManager.isFlashOn = mode == 'auto';
          debugPrint('闪光灯模式已更新: $mode');
        }
        break;

      case 'cameraTypeChanged':
        debugPrint('相机事件: 相机类型变化 - ${event['deviceType']} (Flutter 端不主动重启预览)');
        // 重置 isCameraChanging 状态
        if (_stateManager.isCameraChanging) {
          _stateManager.isCameraChanging = false;
          debugPrint('原生相机类型切换完成，重置isCameraChanging状态');
        }
        break;

      case 'cameraSwitched':
        final position = event['position'] as String?;
        debugPrint('收到相机切换事件：position=$position');

        if (position != null && mounted) {
          // 将原生相机类型映射到Flutter使用的类型
          final mappedPosition = (position == 'front') ? 'front' : 'back';
          debugPrint('原生相机类型 $position 映射到 $mappedPosition');

          // 保存上一个相机类型
          final previousType = _stateManager.currentCameraType;

          // 设置新的相机类型
          _stateManager.currentCameraType = mappedPosition;

          // 如果相机类型发生了变化，重新应用缩放设置
          if (previousType != mappedPosition) {
            // 应用一个小延迟，等待UI更新
            Future.delayed(const Duration(milliseconds: 100), () {
              // 如果切换到前置相机，设置固定缩放为1.0 (前置摄像头原始画面)
              if (mappedPosition == 'front') {
                _stateManager.currentZoomLevel = 1.0;
                if (_nativeCameraController != null) {
                  _nativeCameraController!.setZoomLevel(1.0);
                }
              }
              // 如果从前置切换回后置，确保应用保存的后置相机缩放
              else if (previousType == 'front' && mappedPosition == 'back') {
                double targetZoom = _stateManager.lastBackCameraZoomLevel;
                _stateManager.currentZoomLevel = targetZoom;
                if (_nativeCameraController != null) {
                  _nativeCameraController!.setZoomLevel(targetZoom);
                }
              }
            });
          }

          // 确保前后置切换也重置状态
          if (_stateManager.isProcessingCameraChange) {
            _stateManager.isProcessingCameraChange = false;
            debugPrint('前后摄像头切换完成，重置isProcessingCameraChange状态');
          } else if (_stateManager.isCameraChanging) {
            // 如果是因为调用 switchCamera 触发的类型变化，也重置 isCameraChanging
            _stateManager.isCameraChanging = false;
            debugPrint('前后摄像头切换事件也重置isCameraChanging状态');
          }
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
    // 强制停止教我拍流程，防止动画残留
    final aiTipProvider = Provider.of<AiTipProvider>(context, listen: false);
    aiTipProvider.forceStop();
    debugPrint('📸 离开相机页面，强制停止教我拍流程并重置所有状态');

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

        // 应用回到前台时，完全重置教我拍状态，确保状态干净
        final aiTipProvider =
            Provider.of<AiTipProvider>(context, listen: false);
        aiTipProvider.reset();
        debugPrint('📸 应用回到前台时重置教我拍状态，确保状态干净');

        // 应用回到前台时，重新应用相机设置
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_nativeCameraController != null) {
            _applyCurrentCameraSettings();
          }
        });
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        debugPrint('应用进入后台，暂停相机');
        _nativeCameraController?.pausePreview();

        // 应用进入后台时强制停止教我拍流程
        final aiTipProvider =
            Provider.of<AiTipProvider>(context, listen: false);
        aiTipProvider.forceStop();
        debugPrint('📸 应用进入后台时强制停止教我拍流程');
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

        // 输出调试信息，验证布局是否正确
        debugPrint('当前预览框参数: 比例=${_stateManager.currentAspectRatio}');
        debugPrint(
            '预览框位置: 顶部=${previewParams.topPosition}, 底部=${previewParams.bottomPosition}');
        debugPrint(
            '控制按钮位置: 缩放控制Y=${previewParams.zoomControlY}, 相机控制Y=${previewParams.cameraControlsY}, 底部按钮Y=${previewParams.bottomControlsY}');

        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              // 主要内容区域，包含相机预览和大部分UI元素
              GestureDetector(
                onTap: () {
                  // 移除滤镜选择器相关代码
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
                                // onTapDown 已恢复，现在再次注释掉以移除对焦功能
                                // onTapDown: (TapDownDetails details) {
                                //   // 获取点击位置
                                //   final RenderBox box =
                                //       context.findRenderObject() as RenderBox;
                                //   final Offset localPosition =
                                //       box.globalToLocal(details.globalPosition);
                                //
                                //   // 计算点击位置相对于预览框的偏移
                                //   final Offset adjustedPosition = Offset(
                                //       localPosition.dx,
                                //       localPosition.dy -
                                //           previewParams.topPosition);
                                //
                                //   // 设置对焦点
                                //   _setFocusPoint(
                                //       adjustedPosition,
                                //       BoxConstraints(
                                //           maxWidth: previewParams.width,
                                //           maxHeight: previewParams.height));
                                // },

                                // 保留缩放手势功能
                                onScaleStart: (details) {
                                  // 前置摄像头禁用缩放功能
                                  if (_stateManager.currentCameraType ==
                                      'front') {
                                    return;
                                  }
                                  _stateManager.baseScaleLevel =
                                      _stateManager.currentZoomLevel;
                                },
                                onScaleUpdate: (details) {
                                  // 前置摄像头禁用缩放功能
                                  if (_stateManager.currentCameraType ==
                                      'front') {
                                    return;
                                  }

                                  // 增加判断：如果相机正在切换，则忽略缩放更新
                                  if (_stateManager.isCameraChanging) {
                                    debugPrint('相机正在切换，忽略本次缩放更新');
                                    return;
                                  }

                                  if (details.scale != 1.0) {
                                    // 计算新的缩放级别
                                    double newZoom =
                                        _stateManager.baseScaleLevel *
                                            details.scale;

                                    // 直接调用 CameraStateManager 的 setZoom 方法
                                    _stateManager.setZoom(newZoom);

                                    // 打印当前缩放级别，用于调试
                                    debugPrint(
                                        '当前缩放级别: ${_stateManager.currentZoomLevel.toStringAsFixed(2)}');
                                  }
                                },
                                onScaleEnd: (details) {
                                  // 前置摄像头禁用缩放功能
                                  if (_stateManager.currentCameraType ==
                                      'front') {
                                    return;
                                  }
                                  _stateManager.baseScaleLevel =
                                      _stateManager.currentZoomLevel;
                                },

                                child: Stack(
                                  children: [
                                    // 如果原生相机初始化成功，显示NativeCameraView
                                    if (Platform.isIOS)
                                      NativeCameraView(
                                        controller: _nativeCameraController,
                                        backgroundColor:
                                            const Color(0xFF1A1A1A),
                                        onCreated: () {
                                          _initializeNativeCamera();
                                        },
                                      ),
                                    // 同时显示一个半透明覆盖层，保持接收手势事件
                                    Container(
                                      color: Colors.transparent,
                                    ),

                                    // 添加网格线
                                    ListenableBuilder(
                                      listenable: _stateManager,
                                      builder: (context, _) {
                                        return _stateManager.showGridLines
                                            ? CustomPaint(
                                                painter: GridPainter(),
                                                size: Size.infinite,
                                              )
                                            : const SizedBox.shrink();
                                      },
                                    ),

                                    // 在 NativeCameraView 上层添加加载指示器
                                    if (_stateManager.isCameraChanging)
                                      Positioned.fill(
                                        child: Container(
                                          color: Colors.black.withOpacity(0.5),
                                          child: const Center(
                                              child: CircularProgressIndicator(
                                                  color: Colors.white)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 可点击透明覆盖层，用于关闭展开的控制面板
                    if (_stateManager.isExposureControlExpanded ||
                        _stateManager.isAspectRatioControlExpanded)
                      Positioned.fill(
                        child: IgnorePointer(
                          ignoring: !(_stateManager.isExposureControlExpanded ||
                              _stateManager.isAspectRatioControlExpanded),
                          child: GestureDetector(
                            onTap: () {
                              // 点击空白处关闭控制面板
                              setState(() {
                                if (_stateManager.isExposureControlExpanded) {
                                  _stateManager.isExposureControlExpanded =
                                      false;
                                }
                                if (_stateManager
                                    .isAspectRatioControlExpanded) {
                                  _stateManager.isAspectRatioControlExpanded =
                                      false;
                                }
                              });
                            },
                            child: Container(
                              color: Colors.transparent,
                            ),
                          ),
                        ),
                      ),

                    // 缩放控制（相机预览框下沿向上10px）
                    if (_stateManager.currentCameraType != 'front') ...[
                      Positioned(
                        top: previewParams.zoomControlY - 40, // 位置调整，减去控件高度
                        left: 0,
                        right: 0,
                        child: const ZoomControl(),
                      ),
                    ],

                    // 相机控制按钮行（相机预览框下沿向下10px）
                    Positioned(
                      top: previewParams.cameraControlsY,
                      left: 0,
                      right: 0,
                      child: _stateManager.isAspectRatioControlExpanded
                          // 当拍摄比例控制面板展开时，只显示该控件
                          ? const AspectRatioControl()
                          // 当曝光控制面板展开时，只显示该控件
                          : _stateManager.isExposureControlExpanded
                              ? const ExposureControl()
                              // 正常状态下显示所有控制按钮
                              : Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: const [
                                    FlashControl(),
                                    ExposureControl(),
                                    AspectRatioControl(),
                                    GridControl(),
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

              // AI拍摄建议动画 - 放在Stack的最顶层
              Consumer<AiTipProvider>(
                builder: (context, provider, child) {
                  final bool shouldBlockHitTest =
                      provider.state == AiTipState.analyzing ||
                          (provider.state == AiTipState.showingTips &&
                              provider.isProcessing);

                  return AbsorbPointer(
                    // 在分析中或显示建议时阻断点击事件，确保用户只能专注于"教我拍"功能
                    absorbing: shouldBlockHitTest,
                    child: AiTipAnimation(
                      tips: provider.tips,
                      isAnalyzing: provider.state == AiTipState.analyzing,
                      onTipsVisibilityChanged: (visible) {
                        debugPrint('教我拍提示可见性: $visible');
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
