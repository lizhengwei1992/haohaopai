import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'settings/settings_screen.dart';
import 'profile/profile_screen.dart';
import '../providers/camera_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/camera/shooting_tips.dart';
import '../widgets/camera/camera_grid_lines.dart';
import '../widgets/camera/camera_controls.dart';
import '../widgets/camera/zoom_control.dart';
import '../widgets/camera/focus_point.dart';
import '../widgets/camera/camera_filters.dart';
import '../widgets/camera/camera_control_icons.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import '../models/photo_metadata.dart';
import '../widgets/camera/shooting_tips_animation.dart';
import 'dart:async';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/camera/index.dart'; // 导入相机服务
import '../widgets/camera/native_camera_view.dart';
import '../widgets/camera/tips_overlay.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart'; // 添加缺少的导入
import '../widgets/camera/camera_focus_point.dart'; // 添加对焦点组件导入
import '../widgets/camera/full_screen_image.dart'; // 添加全屏图像组件导入

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // 使用相机服务，不直接管理相机
  final CameraService _cameraService = CameraService();

  // 保留现有的状态变量
  bool _isInitialized = false;
  bool _isFlashOn = false;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _baseScaleLevel = 1.0;
  String _currentAspectRatio = '4:3';

  // 添加滤镜相关变量
  FilterType _currentFilter = FilterType.none;
  bool _showFilterSelector = false;

  // 添加手势缩放相关变量
  double _startScale = 1.0;

  // 添加对焦点相关变量
  Offset? _focusPoint;
  bool _showFocusPoint = false;
  bool _focusSuccess = false;

  // 超广角模式标识
  bool _isUltraWideMode = false;

  // 相机预览的最后一帧图像
  Uint8List? _lastPreviewFrame;

  // 图像流控制器
  StreamSubscription<CameraImage>? _imageStreamSubscription;

  // 添加tips可见性状态
  bool _areTipsVisible = true;

  // 原生相机控制器 (iOS)
  NativeCameraController? _nativeCameraController;

  // 是否使用原生相机
  bool _useNativeCamera = Platform.isIOS;

  // 原生相机能力
  Map<String, dynamic> _nativeCameraCapabilities = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 如果是iOS平台，检查原生相机
    if (Platform.isIOS) {
      _checkNativeCamera();
    } else {
      // 非iOS平台，使用Flutter相机
      _initializeState();
    }

    // 加载应用相册中的照片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cameraProvider =
          Provider.of<CameraProvider>(context, listen: false);
      cameraProvider.loadAppPhotos();

      // 当页面完全加载后启动图像流(仅Flutter相机)
      if (!_useNativeCamera) {
        _startImageStream();
      }
    });
  }

  // 检查原生相机支持
  Future<void> _checkNativeCamera() async {
    try {
      // 检查设备是否支持原生相机
      final isSupported = await NativeCameraService.isNativeCameraSupported();

      if (isSupported) {
        // 获取相机能力
        final capabilities = await NativeCameraService.getCameraCapabilities();

        if (mounted) {
          setState(() {
            _useNativeCamera = true;
            _nativeCameraCapabilities = capabilities;

            // 创建原生相机控制器
            _nativeCameraController = NativeCameraController(0);

            // 设置相机参数
            final zoomOptions =
                capabilities['allZoomOptions'] as List<dynamic>?;
            if (zoomOptions != null && zoomOptions.isNotEmpty) {
              _minZoomLevel = 0.5; // 最小支持0.5x (超广角)
              _maxZoomLevel = zoomOptions.last as double; // 最大支持值
            }
          });
        }
      } else {
        // 如果不支持原生相机，回退到Flutter相机
        if (mounted) {
          setState(() {
            _useNativeCamera = false;
          });
        }
        _initializeState();
      }
    } catch (e) {
      debugPrint('检查原生相机支持时出错: $e');
      // 出错时回退到Flutter相机
      if (mounted) {
        setState(() {
          _useNativeCamera = false;
        });
      }
      _initializeState();
    }
  }

  // 初始化页面状态
  Future<void> _initializeState() async {
    // 如果相机服务已经初始化，使用它提供的相机控制器
    if (_cameraService.isInitialized) {
      // 使用相机服务的控制器和相关信息
      _updateCameraStateFromService();
      return;
    }

    // 否则，等待相机服务初始化完成
    try {
      await _cameraService.initializeCamera();
      _updateCameraStateFromService();
    } catch (e) {
      debugPrint('初始化相机状态时出错: $e');
      setState(() {
        _isInitialized = false;
      });
    }
  }

  // 从相机服务更新状态
  void _updateCameraStateFromService() {
    if (!mounted) return;

    final controller = _cameraService.controller;

    if (controller != null && controller.value.isInitialized) {
      setState(() {
        _isInitialized = true;
        // 更新其他相机参数
        _getZoomLevels();
      });
    } else {
      setState(() {
        _isInitialized = false;
      });
    }
  }

  // 获取相机支持的缩放级别
  Future<void> _getZoomLevels() async {
    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      _minZoomLevel = await controller.getMinZoomLevel();
      _maxZoomLevel = await controller.getMaxZoomLevel();

      // 确保最小缩放级别为1.0
      if (_minZoomLevel < 1.0) {
        _minZoomLevel = 1.0;
      }

      setState(() {
        _currentZoomLevel = 1.0;
      });
    } catch (e) {
      debugPrint('获取缩放级别错误: $e');
    }
  }

  @override
  void dispose() {
    // 停止图像流
    _stopImageStream();

    // 释放原生相机控制器
    if (_useNativeCamera && _nativeCameraController != null) {
      _nativeCameraController?.dispose();
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_useNativeCamera) {
      // Flutter相机的生命周期处理
      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) return;

      if (state == AppLifecycleState.inactive) {
        // App进入后台或锁屏，停止图像流
        _stopImageStream();
      } else if (state == AppLifecycleState.resumed) {
        // App回到前台，恢复图像流
        _startImageStream();
      }
    } else {
      // 原生相机的生命周期处理
      if (state == AppLifecycleState.inactive) {
        // App进入后台或锁屏，停止预览
        _nativeCameraController?.stopPreview();
      } else if (state == AppLifecycleState.resumed) {
        // App回到前台，恢复预览
        _nativeCameraController?.startPreview();
      }
    }
  }

  // 构建相机预览
  Widget _buildCameraPreview() {
    if (_useNativeCamera) {
      // 使用原生相机预览
      return NativeCameraView(
        controller: _nativeCameraController,
        backgroundColor: Colors.black,
        fit: BoxFit.cover,
        onCreated: () {
          setState(() {
            _isInitialized = true;
          });
        },
      );
    } else {
      // 使用Flutter相机预览
      return CameraPreview(_cameraService.controller!);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 获取当前控制器
    final controller = _cameraService.controller;

    if (!_isInitialized ||
        controller == null ||
        !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 安全获取相机宽高比，避免空指针异常
    final double cameraAspectRatio;
    try {
      cameraAspectRatio = controller.value.aspectRatio;
    } catch (e) {
      debugPrint('获取相机宽高比出错: $e');
      // 发生错误时尝试重新初始化相机
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateCameraStateFromService();
        });
      }
      // 显示加载界面
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    final cameraProvider = Provider.of<CameraProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final showingTips = cameraProvider.state == CameraState.showingTips;
    final analyzing = cameraProvider.state == CameraState.analyzing;
    final showGridLines = (settingsProvider.showGridLines && !showingTips) ||
        (cameraProvider.state == CameraState.showingTips);

    // 获取屏幕安全区域的padding和屏幕尺寸
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenWidth = mediaQuery.size.width;
    final screenHeight = mediaQuery.size.height;

    // 目标宽高比（用户选择的拍摄比例）
    double targetAspectRatio;
    switch (_currentAspectRatio) {
      case '16:9':
        targetAspectRatio = 9 / 16; // 在竖屏模式下，宽高比需要倒置
        break;
      case '1:1':
        targetAspectRatio = 1;
        break;
      case '4:3':
      default:
        targetAspectRatio = 3 / 4; // 在竖屏模式下，宽高比需要倒置
        break;
    }

    // 计算预览区域的高度，确保水平方向充满屏幕宽度
    final previewHeight = screenWidth / targetAspectRatio;

    // 计算16:9比例时的预览框高度和位置
    final height16_9 = screenWidth / (9 / 16);
    final top16_9 = topPadding; // 16:9时顶部紧贴刘海下沿

    // 计算16:9比例时的预览框中心点位置
    final center16_9 = top16_9 + height16_9 / 2;

    // 根据固定的中心点位置，计算当前比例下的预览框顶部位置
    double previewTopPosition = center16_9 - previewHeight / 2;

    // 确保预览框不会超出屏幕底部
    final bottomPosition = previewTopPosition + previewHeight;
    if (bottomPosition > screenHeight - 80) {
      // 底部预留80像素
      // 如果超出屏幕底部，向上调整位置
      previewTopPosition = screenHeight - previewHeight - 80;
    }

    // 确保预览框不会超出屏幕顶部
    if (previewTopPosition < 0) {
      previewTopPosition = 0;
    }

    // 打印当前预览区域的比例和尺寸，用于调试
    debugPrint('原始相机比例: $cameraAspectRatio, 目标比例: $targetAspectRatio');
    debugPrint(
        '预览区域尺寸: $screenWidth x $previewHeight, 顶部位置: $previewTopPosition');
    debugPrint('屏幕尺寸: $screenWidth x $screenHeight, 顶部安全区域: $topPadding');
    debugPrint('16:9中心点: $center16_9');

    // 创建相机控制器的key
    final cameraControlsKey = GlobalKey<CameraControlsState>();

    // 计算4:3比例下的预览框高度（用于固定位置参考）
    final defaultPreviewHeight = screenWidth / (3.0 / 4.0); // 4:3比例下的高度
    final defaultPreviewTop = center16_9 - defaultPreviewHeight / 2;
    final defaultPreviewBottom = defaultPreviewTop + defaultPreviewHeight;

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: (_useNativeCamera && _nativeCameraController != null) ||
                (_cameraService.controller != null && _isInitialized)
            ? Stack(
                children: [
                  // 主要内容区域，包含相机预览和大部分UI元素
                  GestureDetector(
                    // 点击屏幕任意位置关闭展开框（只有点击到展开框以外的区域才会触发）
                    onTap: () {
                      debugPrint('点击屏幕区域');
                      // 通过key获取CameraControls的状态并关闭展开框
                      final state = cameraControlsKey.currentState;
                      if (state != null) {
                        state.closeExpandedPanel();
                      }

                      // 如果滤镜选择器打开，点击屏幕关闭它
                      if (_showFilterSelector) {
                        setState(() {
                          _showFilterSelector = false;
                        });
                      }
                    },
                    child: Stack(
                      children: [
                        // 相机预览 - 放在最底层，位置根据固定中心点计算
                        Positioned(
                          top: previewTopPosition,
                          left: 0,
                          right: 0,
                          child: SizedBox(
                            // 设置宽度为屏幕宽度，确保水平方向充满屏幕
                            width: screenWidth,
                            // 根据宽度和宽高比计算高度
                            height: previewHeight,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  // 相机预览 - 使用正确的裁剪方式避免变形
                                  ClipRect(
                                    child: GestureDetector(
                                      // 优化点击对焦功能
                                      onTapDown: (TapDownDetails details) {
                                        // 获取点击位置
                                        final RenderBox box = context
                                            .findRenderObject() as RenderBox;
                                        final Offset localPosition =
                                            box.globalToLocal(
                                                details.globalPosition);

                                        // 计算点击位置相对于预览框的偏移
                                        final Offset adjustedPosition = Offset(
                                            localPosition.dx,
                                            localPosition.dy -
                                                previewTopPosition);

                                        // 检查点击是否在预览框内
                                        if (adjustedPosition.dy >= 0 &&
                                            adjustedPosition.dy <=
                                                previewHeight &&
                                            adjustedPosition.dx >= 0 &&
                                            adjustedPosition.dx <=
                                                screenWidth) {
                                          // 设置对焦点
                                          _setFocusPoint(
                                              adjustedPosition,
                                              BoxConstraints(
                                                  maxWidth: screenWidth,
                                                  maxHeight: previewHeight));
                                        }
                                      },
                                      // 添加手势缩放功能
                                      onScaleStart: (details) {
                                        _startScale = _currentZoomLevel;
                                      },
                                      onScaleUpdate: (details) {
                                        if (details.scale != 1.0) {
                                          // 计算新的缩放级别
                                          double newZoom =
                                              _startScale * details.scale;

                                          // 限制缩放范围
                                          if (newZoom < _minZoomLevel) {
                                            newZoom = _minZoomLevel;
                                          } else if (newZoom > _maxZoomLevel) {
                                            newZoom = _maxZoomLevel;
                                          }

                                          // 设置新的缩放级别
                                          _setZoomLevel(newZoom);
                                        }
                                      },
                                      child: Consumer<CameraProvider>(
                                        builder: (context, provider, child) {
                                          // 如果预览被暂停，显示最后一帧
                                          if (provider.isPreviewPaused) {
                                            return Container(
                                              width: screenWidth,
                                              height: screenWidth *
                                                  cameraAspectRatio,
                                              color: Colors.black,
                                              child: Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  // 使用静态图片显示最后一帧
                                                  Image.memory(
                                                    _lastPreviewFrame ??
                                                        Uint8List(0),
                                                    fit: BoxFit.cover,
                                                    width: screenWidth,
                                                    height: screenWidth *
                                                        cameraAspectRatio,
                                                  ),
                                                  // 应用滤镜效果
                                                  if (_currentFilter !=
                                                      FilterType.none)
                                                    ColorFiltered(
                                                      colorFilter: CameraFilters
                                                          .getColorFilter(
                                                              _currentFilter),
                                                      child: Container(
                                                        color:
                                                            Colors.transparent,
                                                      ),
                                                    ),
                                                ],
                                              ),
                                            );
                                          }

                                          // 使用FilteredCameraPreview而不是普通CameraPreview
                                          return FilteredCameraPreview(
                                            filterType: _currentFilter,
                                            child: Stack(
                                              fit: StackFit.expand,
                                              children: [
                                                // 相机预览和模糊效果
                                                OverflowBox(
                                                  alignment: Alignment.center,
                                                  child: FittedBox(
                                                    fit: BoxFit.cover,
                                                    child: SizedBox(
                                                      width: screenWidth,
                                                      height: screenWidth *
                                                          cameraAspectRatio,
                                                      child: ClipRect(
                                                        child: BackdropFilter(
                                                          filter:
                                                              ImageFilter.blur(
                                                            sigmaX:
                                                                0, // 移除模糊效果，始终为0
                                                            sigmaY:
                                                                0, // 移除模糊效果，始终为0
                                                          ),
                                                          child:
                                                              _buildCameraPreview(), // 使用安全的预览构建方法
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),

                                                // 九宫格 - 只在tips收起时显示
                                                if (!_areTipsVisible &&
                                                    (showingTips || analyzing))
                                                  IgnorePointer(
                                                    // 使用IgnorePointer确保九宫格不会阻止相机预览区域的手势事件
                                                    child: SizedBox(
                                                      width: screenWidth,
                                                      height: screenWidth *
                                                          cameraAspectRatio,
                                                      child: CustomPaint(
                                                        painter: GridPainter(),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),

                                  // 显示对焦框
                                  if (_showFocusPoint && _focusPoint != null)
                                    FocusPoint(
                                      position: _focusPoint!,
                                      focusSuccess: _focusSuccess,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 拍摄建议和分析动画 - 单独放在一个层，确保正常接收点击事件
                        if (showingTips || analyzing)
                          Positioned.fill(
                            child: ShootingTipsAnimation(
                              tips: cameraProvider.tips,
                              isAnalyzing: analyzing,
                              uploadProgress: cameraProvider.uploadProgress,
                              onTipsVisibilityChanged:
                                  _handleTipsVisibilityChanged,
                            ),
                          ),

                        // 顶部空间 - 放在Stack中，使其可以与预览框重叠，移除底色
                        Positioned(
                          top: topPadding,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 10),
                            // 移除底色
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // 左上角添加返回按钮
                                GestureDetector(
                                  onTap: () {
                                    // 返回到个人资料页面（主页面）
                                    Navigator.of(context).pop();
                                  },
                                  child: const Icon(
                                    Icons.arrow_back_ios,
                                    color: Colors.white,
                                    size: 24,
                                  ),
                                ),

                                // 右侧空白占位，移除了相机翻转按钮
                                const SizedBox(width: 24),
                              ],
                            ),
                          ),
                        ),

                        // 缩放控制 - 固定在默认4:3预览框下边缘往上10px的位置
                        Positioned(
                          top: defaultPreviewBottom -
                              50, // 减去控件高度(40px)再减去上边距(10px)
                          left: 0,
                          right: 0,
                          child: ZoomControl(
                            currentZoom: _currentZoomLevel,
                            minZoom: _minZoomLevel,
                            maxZoom: _maxZoomLevel,
                            onZoomChanged: _setZoomLevel,
                          ),
                        ),

                        // 底部操作栏 - 固定在默认4:3预览框下边缘往下10px的位置
                        Positioned(
                          top: defaultPreviewBottom + 10, // 预览框底部向下10px
                          left: 0,
                          right: 0,
                          child: CameraControls(
                            key: cameraControlsKey,
                            onCapturePress: () => _handleCapturePress(context),
                            onTeachPress: () => _handleTeachPress(context),
                            onGalleryPress: () {
                              if (cameraProvider.recentPhotos.isNotEmpty) {
                                _showFullScreenImage(context,
                                    cameraProvider.recentPhotos.first.path);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('没有最近拍摄的照片')),
                                );
                              }
                            },
                            onSwitchCameraPress: _switchCamera,
                            onToggleFlash: _toggleFlash, // 添加闪光灯切换回调
                            isFlashOn: _isFlashOn, // 添加闪光灯状态
                            showingTips: showingTips,
                            currentAspectRatio: _currentAspectRatio, // 传递当前拍摄比例
                            onAspectRatioChange: _updateAspectRatio,
                            onExposureChange: _setExposure,
                            onFilterChange: _handleFilterChange,
                            currentFilter: _currentFilter, // 传递当前滤镜
                            showFilterSelector:
                                _showFilterSelector, // 传递滤镜选择器状态
                          ),
                        ),

                        // 添加相机类型指示器
                        _buildCameraTypeIndicator(),

                        // 对焦点
                        if (_showFocusPoint && _focusPoint != null)
                          Positioned(
                            left: _focusPoint!.dx - 25,
                            top: _focusPoint!.dy - 25,
                            child: CameraFocusPoint(
                              size: 50,
                              focusSuccess: _focusSuccess,
                            ),
                          ),

                        // 相机拍摄技巧提示
                        if (_areTipsVisible)
                          TipsOverlay(
                            onDismiss: () {
                              setState(() {
                                _areTipsVisible = false;
                              });
                            },
                          ),
                      ],
                    ),
                  ),

                  // 滤镜选择器 - 单独放在外层Stack中，使其能够接收点击事件
                  if (_showFilterSelector)
                    Positioned(
                      // 计算位置，使其与底部控制按钮上边缘对齐
                      top: defaultPreviewBottom + 10, // 与底部操作栏的顶部位置相同
                      left: 0,
                      right: 0,
                      child: FilterSelector(
                        currentFilter: _currentFilter,
                        onFilterChanged: _handleFilterChange,
                        // 使用安全的相机预览构建方法
                        cameraPreviewWidget: _cameraService.controller !=
                                    null &&
                                _cameraService.controller!.value.isInitialized
                            ? SizedBox(
                                width: 60, // 增加预览宽度从50到60
                                height: 60 / targetAspectRatio, // 保持与相机预览相同的宽高比
                                child: FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    height: MediaQuery.of(context).size.width *
                                        _cameraService
                                            .controller!.value.aspectRatio,
                                    child: ClipRect(
                                      child:
                                          _buildCameraPreview(), // 使用安全的预览构建方法
                                    ),
                                  ),
                                ),
                              )
                            : Container(
                                width: 60, // 增加预览宽度从50到60
                                height: 60 / targetAspectRatio, // 保持与相机预览相同的宽高比
                                color: Colors.black,
                              ),
                      ),
                    ),
                ],
              )
            : const Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  // 添加一个辅助方法来获取当前相机类型的显示文本
  // 显示删除确认对话框
  void _showDeleteConfirmation(BuildContext context, String imagePath) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              // 删除照片
              final provider =
                  Provider.of<CameraProvider>(context, listen: false);

              // 显示加载指示器
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => const Center(
                  child: CircularProgressIndicator(),
                ),
              );

              // 异步删除照片
              provider.removePhoto(imagePath).then((_) {
                // 关闭加载指示器
                Navigator.pop(context);
                // 关闭对话框和预览页面
                Navigator.pop(context); // 关闭对话框
                Navigator.pop(context); // 关闭预览页面

                // 显示删除成功提示
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('照片已删除')),
                );
              }).catchError((error) {
                // 关闭加载指示器
                Navigator.pop(context);
                // 关闭对话框
                Navigator.pop(context);

                // 显示错误提示
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('删除照片失败: $error')),
                );
              });
            },
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 开始图像流
  Future<void> _startImageStream() async {
    if (_useNativeCamera) return; // 原生相机不需要这个

    if (!_cameraService.isInitialized) {
      debugPrint('相机服务未初始化，无法启动图像流');
      return;
    }

    _cameraService.startImageStream();

    setState(() {
      _isInitialized = true;
    });

    debugPrint('相机图像流已启动');
  }

  // 停止图像流
  Future<void> _stopImageStream() async {
    if (_useNativeCamera) return; // 原生相机不需要这个

    if (!_cameraService.isInitialized) return;

    _cameraService.stopImageStream();

    debugPrint('相机图像流已停止');
  }

  // 处理图像帧
  void _processImageStream(CameraImage image) {
    if (_useNativeCamera) return; // 原生相机不需要这个

    // 这里处理图像帧数据
    // 可以用于实时分析或其他功能
  }

  // 拍照
  Future<void> _capturePhoto() async {
    if (_useNativeCamera) {
      try {
        // 使用原生相机拍照
        final imageData = await _nativeCameraController?.capturePhoto();
        if (imageData != null) {
          // 处理照片数据
          final tempDir = await getTemporaryDirectory();
          final filePath =
              '${tempDir.path}/${DateTime.now().millisecondsSinceEpoch}.jpg';

          final file = File(filePath);
          await file.writeAsBytes(imageData);

          // 保存到相册
          await ImageGallerySaver.saveFile(filePath);

          // 更新应用相册
          final cameraProvider =
              Provider.of<CameraProvider>(context, listen: false);
          await cameraProvider.addPhotoToAppGallery(filePath);

          // 提供触觉反馈
          HapticFeedback.mediumImpact();

          // 显示全屏预览
          if (mounted) {
            _showFullScreenImage(context, filePath);
          }
        }
      } catch (e) {
        debugPrint('原生相机拍照失败: $e');
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败：$e')),
        );
      }
    } else {
      // 使用Flutter相机拍照
      final controller = _cameraService.controller;
      if (controller == null || !controller.value.isInitialized) {
        return;
      }

      // 播放拍照声音
      try {
        SystemSound.play(SystemSoundType.click);
      } catch (e) {
        debugPrint('播放拍照声音失败: $e');
      }

      final cameraProvider =
          Provider.of<CameraProvider>(context, listen: false);

      try {
        // 拍摄新照片
        final XFile photo = await controller.takePicture();
        final originalPath = photo.path;

        debugPrint('原始照片已拍摄: $originalPath');

        // 将图片添加到相册
        await cameraProvider.saveToGallery(originalPath);

        if (mounted) {
          _showFullScreenImage(context, originalPath);
        }
      } catch (e) {
        debugPrint('拍照错误: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('拍照出错，请重试')),
          );
        }
      }
    }
  }

  // 切换前后摄像头
  Future<void> _switchCamera() async {
    if (_useNativeCamera) {
      final isFrontCamera = await _nativeCameraController?.isFrontCamera ?? false;
      await _nativeCameraController?.switchCamera(toFront: !isFrontCamera);
      return;
    }

    setState(() {
      _isCameraChanging = true;
    });

    try {
      // 修复参数传递问题
      /* 原实现（有错误）
      final success = await _cameraService
          .switchToCamera(_cameraService.frontCameraIndex == _cameraService.currentCameraIndex
              ? 0
              : _cameraService.frontCameraIndex);
      */
      
      // 使用正确的枚举类型
      final isFrontCamera = 
          _cameraService.frontCameraIndex == _cameraService.currentCameraIndex;
      final success = await _cameraService.switchToCamera(
          isFrontCamera ? CameraType.standard : CameraType.front);

      if (success) {
        setState(() {
          // 重置状态
        // 如果在超广角模式，缩放级别大于1.1，切回标准摄像头
        if (_isUltraWideMode && zoom > 1.1) {
          debugPrint('缩放级别高于1.1，从超广角切回标准摄像头');
          await _cameraService
              .switchToCamera(_cameraService.standardCameraIndex);
          setState(() {
            _isUltraWideMode = false;
            _currentZoomLevel = 1.0;
          });
          _updateCameraStateFromService();
          return;
        }

        // 正常情况下直接调整缩放
        await controller.setZoomLevel(zoom);
        setState(() {
          _currentZoomLevel = zoom;
        });
      } catch (e) {
        debugPrint('设置缩放级别错误: $e');
      }
    }
  }

  // 切换闪光灯
  Future<void> _toggleFlash() async {
    if (_useNativeCamera) {
      try {
        final mode = await _nativeCameraController?.toggleFlash();
        setState(() {
          _isFlashOn = mode == 'on';
        });
      } catch (e) {
        debugPrint('切换原生相机闪光灯失败: $e');
      }
    } else {
      // 使用Flutter相机切换闪光灯
      final controller = _cameraService.controller;
      if (controller == null) return;

      try {
        final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.auto;
        await controller.setFlashMode(newFlashMode);
        setState(() {
          _isFlashOn = !_isFlashOn;
        });
      } catch (e) {
        debugPrint('切换闪光灯错误: $e');
      }
    }
  }

  // 显示全屏图像
  void _showFullScreenImage(BuildContext context, String imagePath) {
    try {
      // 记录当前相机状态，以便返回时恢复
      bool wasStreaming = false;
      double savedZoomLevel = _currentZoomLevel;

      if (_useNativeCamera) {
        // 原生相机处理
        _nativeCameraController?.stopPreview();
      } else {
        // Flutter相机处理
        final controller = _cameraService.controller;
        if (controller != null && controller.value.isInitialized) {
          // 如果正在使用图像流，暂时停止
          if (controller.value.isStreamingImages) {
            wasStreaming = true;
            _stopImageStream(); // 暂停图像流
          }
        }
      }

      // 暂停预览显示
      final cameraProvider =
          Provider.of<CameraProvider>(context, listen: false);
      cameraProvider.pausePreview();

      debugPrint('🖼️ 查看照片: $imagePath，已暂停相机预览');

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(imagePath: imagePath),
        ),
      ).then((_) {
        // 返回时恢复相机预览
        if (mounted) {
          // 恢复预览显示
          cameraProvider.resumePreview();

          if (_useNativeCamera) {
            // 恢复原生相机预览
            _nativeCameraController?.startPreview();
          } else {
            // 恢复Flutter相机预览
            final controller = _cameraService.controller;
            if (controller != null && controller.value.isInitialized) {
              // 如果之前在使用图像流，恢复图像流
              if (wasStreaming) {
                _startImageStream();
              }

              // 恢复缩放级别
              if (_currentZoomLevel != savedZoomLevel) {
                _setZoomLevel(savedZoomLevel);
              }
            }
          }

          debugPrint('🖼️ 从照片查看返回，已恢复相机预览');
        }
      });
    } catch (e) {
      debugPrint('🖼️ 显示全屏图像错误: $e');
    }
  }

  // 构建相机类型指示器
  Widget _buildCameraTypeIndicator() {
    String typeText = '标准';

    if (_useNativeCamera) {
      // 原生相机类型显示
      if (_nativeCameraController?.isFrontCamera ?? false) {
        typeText = '前置';
      } else {
        // 根据当前缩放级别估算类型
        if (_currentZoomLevel < 0.7) {
          typeText = '超广角';
        } else if (_currentZoomLevel > 1.8) {
          typeText = '长焦';
        }
      }
    } else {
      // Flutter相机类型显示
      if (_cameraService.isUsingFrontCamera()) {
        typeText = '前置';
      } else if (_cameraService.isUsingUltraWideCamera()) {
        typeText = '超广角';
      } else if (_cameraService.isUsingTelephotoCamera()) {
        typeText = '长焦';
      }
    }

    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          typeText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  // 处理tips可见性变化
  void _handleTipsVisibilityChanged(bool isVisible) {
    debugPrint('tips可见性变化回调触发: $isVisible -> $_areTipsVisible');

    // 使用微任务延迟状态更新，避免在构建过程中调用setState
    Future.microtask(() {
      if (mounted) {
        setState(() {
          _areTipsVisible = isVisible;
        });
        debugPrint('tips可见性已更新: $_areTipsVisible，将更新UI');
      }
    });
  }

  // 处理"拍摄"按钮点击
  Future<void> _handleCapturePress(BuildContext context) async {
    // 直接调用拍照方法
    await _capturePhoto();
  }

  // 处理"教我拍"按钮点击
  Future<void> _handleTeachPress(BuildContext context) async {
    // 获取提供者
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    // 提供触觉反馈
    HapticFeedback.mediumImpact();

    // 显示提示层
    setState(() {
      _areTipsVisible = true;
    });

    // 如果有实现AI分析服务，可以在这里调用
    // 暂时先提示用户功能开发中
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI拍摄建议功能开发中')),
    );
  }

  // 处理拍摄比例变化
  Future<void> _updateAspectRatio(String ratio) async {
    setState(() {
      _currentAspectRatio = ratio;
    });

    // 如果需要更新相机预览尺寸，在这里实现
  }

  // 处理曝光值变化
  Future<void> _setExposure(double value) async {
    if (_useNativeCamera) {
      // 原生相机暂不支持曝光调整
      return;
    }

    final controller = _cameraService.controller;
    if (controller == null || !controller.value.isInitialized) return;

    try {
      // 确保曝光值在相机支持的范围内
      final minExposure = await controller.getMinExposureOffset();
      final maxExposure = await controller.getMaxExposureOffset();

      // 将我们的-2.0到2.0范围映射到相机支持的范围
      final normalizedValue = (value + 2.0) / 4.0; // 转换为0-1范围
      final cameraValue =
          minExposure + (maxExposure - minExposure) * normalizedValue;

      // 设置曝光值
      await controller.setExposureOffset(cameraValue);

      debugPrint(
          '设置曝光值: $value, 相机值: $cameraValue, 范围: $minExposure 到 $maxExposure');
    } catch (e) {
      debugPrint('设置曝光值错误: $e');
    }
  }

  // 切换滤镜选择器显示状态
  void _toggleFilterSelector() {
    setState(() {
      _showFilterSelector = !_showFilterSelector;
    });
  }

  // 处理滤镜变化
  void _handleFilterChange(FilterType filter) {
    setState(() {
      _currentFilter = filter;
      _showFilterSelector = false;
    });
  }

  // 开始分析实时预览 - 目前未实现
  Future<void> _startAnalyzing() async {
    if (mounted) {
      setState(() {
        _isAnalyzing = true;
      });
    }

    /* 以下方法已移动到新的服务中，暂时注释掉
    try {
      await CameraService().startImageStream((image) {
        if (_isAnalyzing && mounted) {
          _processImageStream(image);
        }
      });
    } catch (e) {
      print('开启实时分析时出错: $e');
      
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
    */
  }

  // 停止分析实时预览 - 目前未实现
  Future<void> _stopAnalyzing() async {
    if (mounted) {
      setState(() {
        _isAnalyzing = false;
      });
    }

    /* 以下方法已移动到新的服务中，暂时注释掉
    try {
      await CameraService().stopImageStream();
    } catch (e) {
      print('停止实时分析时出错: $e');
    }
    */
  }

  // 处理图像流 - 目前未实现
  void _processImageStream(dynamic image) {
    // TODO: 实现实时分析功能
  }
}

// 添加九宫格绘制器
class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // 绘制垂直线
    for (int i = 1; i < 3; i++) {
      final x = size.width * (i / 3);
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        paint,
      );
    }

    // 绘制水平线
    for (int i = 1; i < 3; i++) {
      final y = size.height * (i / 3);
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
