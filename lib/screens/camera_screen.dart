import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
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
import 'dart:math' as Math;
import '../widgets/camera/shooting_tips_animation.dart';
import 'dart:async';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
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

  // 添加摄像头类型识别变量
  int _currentCameraIndex = 0; // 当前摄像头索引
  bool _hasUltraWideCamera = false; // 是否有超广角摄像头
  int _standardCameraIndex = 0; // 标准摄像头索引
  int _ultraWideCameraIndex = -1; // 超广角摄像头索引
  int _frontCameraIndex = -1; // 前置摄像头索引
  bool _isUltraWideMode = false; // 是否是超广角模式

  // 相机预览的最后一帧图像
  Uint8List? _lastPreviewFrame;

  // 图像流控制器
  StreamSubscription<CameraImage>? _imageStreamSubscription;

  // 添加相机状态保存变量
  bool _wasFrontCamera = false;
  bool _wasFlashOn = false;
  double _savedZoomLevel = 1.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _analyzeCameras();

    // 加载应用相册中的照片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cameraProvider =
          Provider.of<CameraProvider>(context, listen: false);
      cameraProvider.loadAppPhotos();
    });

    _initializeCamera();
  }

  @override
  void dispose() {
    // 确保在dispose时安全地停止图像流
    _stopImageStream();

    // 安全地释放相机控制器
    if (_controller != null) {
      final oldController = _controller;
      _controller = null;

      oldController?.dispose().catchError((e) {
        debugPrint('释放相机控制器错误: $e');
      });
    }

    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('应用生命周期状态变化: $state');

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // 保存当前相机状态
      if (_controller != null && _controller!.value.isInitialized) {
        _wasFrontCamera = _currentCameraIndex == _frontCameraIndex;
        _wasFlashOn = _isFlashOn;
        _savedZoomLevel = _currentZoomLevel;

        // 只停止图像流，不释放相机控制器
        _stopImageStream();
        debugPrint(
            '已保存相机状态：前置=$_wasFrontCamera, 闪光灯=$_wasFlashOn, 缩放=$_savedZoomLevel');
      }
    } else if (state == AppLifecycleState.resumed) {
      debugPrint('应用恢复活动状态，重新初始化相机');

      // 使用微任务确保在UI更新后再初始化相机
      Future.microtask(() {
        if (mounted) {
          _initializeCamera();
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 确保相机在组件挂载时正确初始化
    if (mounted &&
        (!_isInitialized ||
            _controller == null ||
            !_controller!.value.isInitialized)) {
      _initializeCamera();
    }
  }

  // 分析可用的摄像头，识别超广角、标准和前置摄像头
  Future<void> _analyzeCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return;
      }

      // 初始化摄像头索引
      _standardCameraIndex = 0; // 默认第一个是标准后置摄像头

      // 遍历所有摄像头，识别前置和可能的超广角
      for (int i = 0; i < _cameras.length; i++) {
        final camera = _cameras[i];

        // 判断是否是前置摄像头
        if (camera.lensDirection == CameraLensDirection.front) {
          _frontCameraIndex = i;
          debugPrint('发现前置摄像头，索引: $i, 名称: ${camera.name}');
        }

        // 尝试通过摄像头名称识别超广角
        final String cameraName = camera.name.toLowerCase();
        if (camera.lensDirection == CameraLensDirection.back &&
            (cameraName.contains('ultra') ||
                cameraName.contains('wide') ||
                cameraName.contains('0.5'))) {
          _ultraWideCameraIndex = i;
          _hasUltraWideCamera = true;
          debugPrint('发现可能的超广角摄像头，索引: $i, 名称: ${camera.name}');
        }
      }

      debugPrint(
          '摄像头分析结果: 标准=$_standardCameraIndex, 超广角=$_ultraWideCameraIndex, 前置=$_frontCameraIndex');

      // 初始化相机
      _initializeCamera();
    } catch (e) {
      debugPrint('分析摄像头错误: $e');
    }
  }

  // 获取可用相机
  Future<void> _fetchCameras() async {
    try {
      _cameras = await availableCameras();
      debugPrint('找到${_cameras.length}个相机');

      if (_cameras.isNotEmpty) {
        // 查找前置相机索引
        _frontCameraIndex = _cameras.indexWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front);

        // 查找后置标准相机索引
        _standardCameraIndex = _cameras.indexWhere((camera) =>
            camera.lensDirection == CameraLensDirection.back &&
            !camera.name.toLowerCase().contains('ultra') &&
            !camera.name.toLowerCase().contains('telephoto'));

        // 查找后置超广角相机索引（如果有）
        _ultraWideCameraIndex = _cameras.indexWhere((camera) =>
            camera.lensDirection == CameraLensDirection.back &&
            (camera.name.toLowerCase().contains('ultra') ||
                camera.name.toLowerCase().contains('wide')));
      }
    } catch (e) {
      debugPrint('获取相机列表错误: $e');
    }
  }

  // 初始化相机
  Future<void> _initializeCamera() async {
    // 如果有现存的相机控制器，先安全释放
    if (_controller != null) {
      try {
        _stopImageStream();
        final oldController = _controller;
        _controller = null;
        await oldController?.dispose();
      } catch (e) {
        debugPrint('释放旧相机控制器错误: $e');
      }
    }

    if (_cameras.isEmpty) {
      await _fetchCameras();
    }

    if (_cameras.isEmpty) {
      debugPrint('没有找到可用的相机');
      return;
    }

    try {
      int cameraIndex;

      // 优先使用保存的相机状态
      if (_wasFrontCamera && _frontCameraIndex >= 0) {
        cameraIndex = _frontCameraIndex;
        debugPrint('恢复前置相机状态');
      } else if (_standardCameraIndex >= 0) {
        cameraIndex = _standardCameraIndex;
        debugPrint('使用标准后置相机');
      } else if (_cameras.isNotEmpty) {
        cameraIndex = 0;
        debugPrint('使用默认相机');
      } else {
        return;
      }

      // 通过专门的方法切换到指定相机
      await _switchToCamera(cameraIndex);

      // 恢复保存的相机设置
      if (_controller != null && _controller!.value.isInitialized) {
        // 恢复闪光灯状态
        if (_wasFlashOn) {
          await _toggleFlash();
        }

        // 恢复缩放级别
        await _setZoomLevel(_savedZoomLevel);

        debugPrint('已恢复相机设置：闪光灯=$_wasFlashOn, 缩放=$_savedZoomLevel');
      }

      debugPrint('相机初始化完成');
    } catch (e) {
      debugPrint('初始化相机错误: $e');
      setState(() {
        _isInitialized = false;
      });
    }
  }

  Future<void> _toggleFlash() async {
    if (_controller == null) return;

    try {
      final newFlashMode = _isFlashOn ? FlashMode.off : FlashMode.auto;
      await _controller!.setFlashMode(newFlashMode);
      setState(() {
        _isFlashOn = !_isFlashOn;
      });
    } catch (e) {
      debugPrint('切换闪光灯错误: $e');
    }
  }

  // 增强版设置缩放级别，支持智能切换超广角
  Future<void> _setZoomLevel(double zoom) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // 如果设备有超广角摄像头，且当前在标准摄像头，且缩放小于0.9
      if (_hasUltraWideCamera &&
          zoom < 0.9 &&
          _currentCameraIndex == _standardCameraIndex &&
          !_isUltraWideMode) {
        debugPrint('缩放级别低于0.9，切换至超广角摄像头');
        await _switchToCamera(_ultraWideCameraIndex);
        _isUltraWideMode = true;
        // 超广角模式缩放级别设置为最大值1.0
        await _controller!.setZoomLevel(1.0);
        setState(() {
          _currentZoomLevel = 1.0;
        });
        return;
      }

      // 如果在超广角模式，缩放级别大于1.1，切回标准摄像头
      if (_isUltraWideMode && zoom > 1.1) {
        debugPrint('缩放级别高于1.1，从超广角切回标准摄像头');
        await _switchToCamera(_standardCameraIndex);
        _isUltraWideMode = false;
        // 设置标准摄像头初始缩放为1.0
        await _controller!.setZoomLevel(1.0);
        setState(() {
          _currentZoomLevel = 1.0;
        });
        return;
      }

      // 正常情况下直接调整缩放
      await _controller!.setZoomLevel(zoom);
      setState(() {
        _currentZoomLevel = zoom;
      });
    } catch (e) {
      debugPrint('设置缩放级别错误: $e');
    }
  }

  // 切换到指定索引的摄像头
  Future<void> _switchToCamera(int cameraIndex) async {
    if (cameraIndex < 0 || cameraIndex >= _cameras.length) {
      debugPrint('无效的摄像头索引: $cameraIndex');
      return;
    }

    // 如果是同一个摄像头，无需切换
    if (_currentCameraIndex == cameraIndex &&
        _controller != null &&
        _controller!.value.isInitialized) {
      return;
    }

    debugPrint('切换到摄像头索引: $cameraIndex, 名称: ${_cameras[cameraIndex].name}');

    try {
      // 先将isInitialized设为false，避免在切换过程中显示错误的预览
      setState(() {
        _isInitialized = false;
      });

      // 停止图像流
      _stopImageStream();

      // 安全释放现有控制器资源
      final oldController = _controller;
      _controller = null; // 立即将控制器设为null，避免在释放过程中被访问

      // 异步释放旧控制器，避免阻塞UI
      if (oldController != null) {
        try {
          await oldController.dispose();
          debugPrint('旧相机控制器已释放');
        } catch (e) {
          debugPrint('释放旧相机控制器错误: $e');
          // 错误处理但继续执行
        }
      }

      // 创建新的相机控制器
      final CameraController newController = CameraController(
        _cameras[cameraIndex],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      // 更新控制器引用
      _controller = newController;

      // 初始化新控制器
      await newController.initialize();
      debugPrint('新相机控制器已初始化');

      // 确保组件仍然挂载
      if (!mounted) {
        await newController.dispose();
        return;
      }

      // 获取新相机的缩放范围
      _minZoomLevel = await newController.getMinZoomLevel();
      _maxZoomLevel = await newController.getMaxZoomLevel();

      // 确保最小缩放级别为1.0
      if (_minZoomLevel < 1.0) {
        _minZoomLevel = 1.0;
      }

      // 更新索引
      _currentCameraIndex = cameraIndex;

      // 初始化完成后再更新UI状态
      setState(() {
        _isInitialized = true;
        _currentZoomLevel = 1.0;
        _isFlashOn = false; // 重置闪光灯状态
      });

      // 最后再启动图像流
      _startImageStream();

      // 延迟一小段时间后再次刷新UI，确保相机预览已经准备好
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('切换相机错误: $e');
      // 出错时确保状态一致
      setState(() {
        _isInitialized = false;
      });
    }
  }

  // 修改切换相机方法，只在前置和后置标准摄像头之间切换
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;

    debugPrint('开始切换前后摄像头...');

    // 确保当前相机不为空
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('相机控制器未初始化，无法切换');
      return;
    }

    // 如果当前是前置摄像头，切换到后置标准摄像头
    if (_currentCameraIndex == _frontCameraIndex) {
      debugPrint('从前置切换到后置标准摄像头');
      await _switchToCamera(_standardCameraIndex);
    }
    // 否则切换到前置摄像头
    else {
      debugPrint('从后置切换到前置摄像头');
      await _switchToCamera(_frontCameraIndex);
    }

    // 重置超广角模式标志
    _isUltraWideMode = false;
  }

  Future<void> _takePhoto() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    try {
      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/Pictures/好好拍';
      await Directory(dirPath).create(recursive: true);
      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      final XFile photo = await _controller!.takePicture();
      await photo.saveTo(filePath);

      debugPrint('照片已保存: $filePath');
    } catch (e) {
      debugPrint('拍照错误: $e');
    }
  }

  // 优化设置对焦点的方法
  Future<void> _setFocusPoint(Offset point, BoxConstraints constraints) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    // 立即更新UI显示对焦框，不等待相机对焦完成
    setState(() {
      _focusPoint = point;
      _showFocusPoint = true;
      _focusSuccess = false; // 重置对焦状态
    });

    // 计算相对于相机预览的坐标
    final Size previewSize = constraints.biggest;

    // 将点击位置转换为相机预览的相对位置（0-1范围）
    // 注意：相机预览可能被裁剪或缩放，需要考虑实际显示区域
    double x = point.dx / previewSize.width;
    double y = point.dy / previewSize.height;

    // 确保坐标在0-1范围内
    x = x.clamp(0.0, 1.0);
    y = y.clamp(0.0, 1.0);

    // 创建对焦点（相对坐标，范围0-1）
    final focusPoint = Offset(x, y);

    try {
      // 先设置对焦模式为锁定，然后再设置为自动对焦，这样可以强制触发对焦
      await _controller!.setFocusMode(FocusMode.locked);
      await Future.delayed(const Duration(milliseconds: 50));

      // 设置相机对焦模式和对焦点
      await _controller!.setFocusMode(FocusMode.auto);
      await _controller!.setFocusPoint(focusPoint);

      // 设置曝光点（通常与对焦点相同）
      await _controller!.setExposurePoint(focusPoint);

      // 短暂延迟后标记对焦成功，模拟对焦过程
      await Future.delayed(const Duration(milliseconds: 300));

      // 对焦成功，更新UI
      if (mounted) {
        setState(() {
          _focusSuccess = true;
        });
      }

      // 2.5秒后隐藏对焦框
      Future.delayed(const Duration(milliseconds: 2500), () {
        if (mounted) {
          setState(() {
            _showFocusPoint = false;
          });
        }
      });

      debugPrint('设置对焦点: $point, 相对位置: ($x, $y)');
    } catch (e) {
      debugPrint('设置对焦点错误: $e');
      // 对焦失败，隐藏对焦框
      if (mounted) {
        Future.delayed(const Duration(milliseconds: 1000), () {
          setState(() {
            _showFocusPoint = false;
          });
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _controller == null) {
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
      cameraAspectRatio = _controller!.value.aspectRatio;
    } catch (e) {
      debugPrint('获取相机宽高比出错: $e');
      // 发生错误时尝试重新初始化相机
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _initializeCamera();
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
      body: Stack(
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
                                final RenderBox box =
                                    context.findRenderObject() as RenderBox;
                                final Offset localPosition =
                                    box.globalToLocal(details.globalPosition);

                                // 计算点击位置相对于预览框的偏移
                                final Offset adjustedPosition = Offset(
                                    localPosition.dx,
                                    localPosition.dy - previewTopPosition);

                                // 检查点击是否在预览框内
                                if (adjustedPosition.dy >= 0 &&
                                    adjustedPosition.dy <= previewHeight &&
                                    adjustedPosition.dx >= 0 &&
                                    adjustedPosition.dx <= screenWidth) {
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
                                  double newZoom = _startScale * details.scale;

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
                                      height: screenWidth * cameraAspectRatio,
                                      color: Colors.black,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          // 使用静态图片显示最后一帧
                                          Image.memory(
                                            _lastPreviewFrame ?? Uint8List(0),
                                            fit: BoxFit.cover,
                                            width: screenWidth,
                                            height:
                                                screenWidth * cameraAspectRatio,
                                          ),
                                          // 应用滤镜效果
                                          if (_currentFilter != FilterType.none)
                                            ColorFiltered(
                                              colorFilter:
                                                  CameraFilters.getColorFilter(
                                                      _currentFilter),
                                              child: Container(
                                                color: Colors.transparent,
                                              ),
                                            ),
                                        ],
                                      ),
                                    );
                                  }

                                  // 正常预览
                                  return FilteredCameraPreview(
                                    filterType: _currentFilter,
                                    child: OverflowBox(
                                      alignment: Alignment.center,
                                      child: FittedBox(
                                        fit: BoxFit.cover,
                                        child: SizedBox(
                                          width: screenWidth,
                                          height:
                                              screenWidth * cameraAspectRatio,
                                          child: CameraPreview(_controller!),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),

                          // 相机网格线 - 移到GestureDetector之外，确保不会阻挡手势
                          if (showGridLines)
                            IgnorePointer(
                              child: CameraGridLines(showGrid: true),
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

                // 拍摄建议和分析动画
                if (showingTips || analyzing)
                  Positioned.fill(
                    child: ShootingTipsAnimation(
                      tips: cameraProvider.tips,
                      isAnalyzing: analyzing,
                      uploadProgress: cameraProvider.uploadProgress,
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
                        // 个人中心按钮
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const ProfileScreen(),
                              ),
                            );
                          },
                          child: const PersonIcon(),
                        ),

                        // 相机翻转按钮（替换原来的设置按钮）
                        GestureDetector(
                          onTap: _switchCamera,
                          child: const CameraFlipIcon(), // 直接使用图标，移除底部圆形区域
                        ),
                      ],
                    ),
                  ),
                ),

                // 缩放控制 - 固定在默认4:3预览框下边缘往上10px的位置
                Positioned(
                  top: defaultPreviewBottom - 50, // 减去控件高度(40px)再减去上边距(10px)
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
                        _showFullScreenImage(
                            context, cameraProvider.recentPhotos.first.path);
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
                    onAspectRatioChange: (ratio) {
                      // 处理拍摄比例变化
                      _updateAspectRatio(ratio);
                    },
                    onExposureChange: (value) {
                      // 处理曝光变化
                      debugPrint('曝光值: $value');
                      _setExposure(value);
                    },
                    onFilterChange: (filter) {
                      // 处理滤镜变化 - 显示滤镜选择器
                      if (filter == 'toggle') {
                        _toggleFilterSelector();
                      }
                    },
                    currentFilter: _currentFilter, // 传递当前滤镜
                    showFilterSelector: _showFilterSelector, // 传递滤镜选择器状态
                  ),
                ),
              ],
            ),
          ),

          // 滤镜选择器 - 单独放在外层Stack中，使其能够接收点击事件
          if (_showFilterSelector)
            Positioned(
              bottom: 120, // 从105调整到120，确保不与拍摄按钮重叠
              left: 0,
              right: 0,
              child: FilterSelector(
                currentFilter: _currentFilter,
                onFilterChanged: _handleFilterChange,
                // 使用实时相机预览而不是静态图片
                cameraPreviewWidget:
                    _controller != null && _controller!.value.isInitialized
                        ? SizedBox(
                            width: 50,
                            height: 50,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.width *
                                    cameraAspectRatio,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          )
                        : null,
              ),
            ),
        ],
      ),
    );
  }

  // 设置曝光值
  Future<void> _setExposure(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // 确保曝光值在相机支持的范围内
      final minExposure = await _controller!.getMinExposureOffset();
      final maxExposure = await _controller!.getMaxExposureOffset();

      // 将我们的-2.0到2.0范围映射到相机支持的范围
      final normalizedValue = (value + 2.0) / 4.0; // 转换为0-1范围
      final cameraValue =
          minExposure + (maxExposure - minExposure) * normalizedValue;

      // 设置曝光值
      await _controller!.setExposureOffset(cameraValue);

      debugPrint(
          '设置曝光值: $value, 相机值: $cameraValue, 范围: $minExposure 到 $maxExposure');
    } catch (e) {
      debugPrint('设置曝光值错误: $e');
    }
  }

  // 处理"拍摄"按钮点击
  Future<void> _handleCapturePress(BuildContext context) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);
    final showingTips = cameraProvider.state == CameraState.showingTips;
    String originalPath;

    try {
      if (showingTips && cameraProvider.originalPhotoPath != null) {
        // 如果正在显示拍摄建议，使用之前保存的原始照片路径
        originalPath = cameraProvider.originalPhotoPath!;
      } else {
        // 否则拍摄新照片
        final XFile photo = await _controller!.takePicture();
        originalPath = photo.path;

        debugPrint('原始照片已拍摄: $originalPath');
      }

      // 将原始图像数据保存为压缩的PNG格式，并应用裁剪
      final String pngPath =
          await _saveAsPng(originalPath, _currentAspectRatio);
      debugPrint('照片已处理并保存: $pngPath');

      // 自动保存到相册
      try {
        await cameraProvider.saveToGallery(pngPath);

        // 保存成功后显示提示
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('照片已保存到相册')),
          );
        }
      } catch (e) {
        debugPrint('保存照片到相册出错: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('保存失败')),
          );
        }
      }

      // 将照片添加到最近照片列表
      final metadata = PhotoMetadata(
        path: pngPath,
        timestamp: DateTime.now(),
        isFromApp: true,
      );

      cameraProvider.addPhotoToRecentList(metadata);

      // 重置拍摄状态
      cameraProvider.reset();
    } catch (e) {
      debugPrint('拍照错误: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('拍照出错，请重试')),
        );
      }
    }
  }

  // 将原始图像数据保存为压缩的PNG格式，并应用裁剪
  Future<String> _saveAsPng(String imagePath, String aspectRatioStr) async {
    try {
      final File imageFile = File(imagePath);
      final Directory tempDir = await getTemporaryDirectory();
      final String pngPath =
          '${tempDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.png';

      // 获取原始文件大小
      final originalSize = await imageFile.length();
      debugPrint('原始图片大小: ${(originalSize / 1024).toStringAsFixed(1)}KB');

      // 读取原始图像数据
      final bytes = await imageFile.readAsBytes();
      // 使用image包解码图像
      final img.Image? originalImage = img.decodeImage(bytes);

      if (originalImage != null) {
        // 根据选择的拍摄比例裁剪图像
        img.Image croppedImage = originalImage;

        // 计算目标宽高比
        double targetAspectRatio;
        switch (aspectRatioStr) {
          case '16:9':
            targetAspectRatio = 16 / 9;
            break;
          case '1:1':
            targetAspectRatio = 1;
            break;
          case '4:3':
          default:
            targetAspectRatio = 4 / 3;
            break;
        }

        // 计算原始图像的宽高比（注意：相机拍摄的照片通常是横向的，所以不需要倒置比例）
        final originalAspectRatio = originalImage.width / originalImage.height;
        debugPrint('原始照片宽高比: $originalAspectRatio, 目标宽高比: $targetAspectRatio');

        // 根据宽高比计算裁剪区域
        if ((originalAspectRatio - targetAspectRatio).abs() > 0.01) {
          int cropWidth, cropHeight;
          int offsetX = 0, offsetY = 0;

          if (originalAspectRatio > targetAspectRatio) {
            // 原始图像更宽，需要裁剪宽度
            cropHeight = originalImage.height;
            cropWidth = (cropHeight * targetAspectRatio).round();
            offsetX = ((originalImage.width - cropWidth) / 2).round();
          } else {
            // 原始图像更高，需要裁剪高度
            cropWidth = originalImage.width;
            cropHeight = (cropWidth / targetAspectRatio).round();
            offsetY = ((originalImage.height - cropHeight) / 2).round();
          }

          // 裁剪图像
          croppedImage = img.copyCrop(
            originalImage,
            x: offsetX,
            y: offsetY,
            width: cropWidth,
            height: cropHeight,
          );

          debugPrint(
              '图像已裁剪: ${originalImage.width}x${originalImage.height} -> ${croppedImage.width}x${croppedImage.height}');
          debugPrint(
              '裁剪区域: 偏移($offsetX, $offsetY), 尺寸($cropWidth, $cropHeight)');
        } else {
          debugPrint('原始照片宽高比与目标宽高比接近，无需裁剪');
        }

        // 注意：我们不再在这里应用滤镜，而是只在预览时应用
        // 这样可以保留原始照片的质量，用户可以在后期处理中应用滤镜
        if (_currentFilter != FilterType.none) {
          debugPrint(
              '当前使用滤镜: ${CameraFilters.getFilterName(_currentFilter)}，但不在保存时应用');
        }

        // 编码为PNG格式并保存
        final pngBytes = img.encodePng(croppedImage);
        final pngFile = File(pngPath);
        await pngFile.writeAsBytes(pngBytes);

        // 获取保存后的文件大小
        final savedSize = await pngFile.length();
        debugPrint('保存后图片大小: ${(savedSize / 1024).toStringAsFixed(1)}KB');

        return pngPath;
      }

      return imagePath;
    } catch (e) {
      debugPrint('保存PNG格式出错: $e');
      return imagePath;
    }
  }

  // 启动图像流
  void _startImageStream() {
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('相机未初始化，无法启动图像流');
      return;
    }

    try {
      // 如果已经在运行，先停止
      _stopImageStream();

      // 启动图像流
      _controller!.startImageStream((CameraImage image) {
        // 这里我们只需要保存最新的一帧，不需要处理每一帧
        // 在实际应用中，这里可以根据需要进行处理
      });
      debugPrint('图像流已启动');
    } catch (e) {
      debugPrint('启动图像流出错: $e');
    }
  }

  // 停止图像流
  void _stopImageStream() {
    try {
      // 先取消订阅
      _imageStreamSubscription?.cancel();
      _imageStreamSubscription = null;

      // 安全地停止图像流
      if (_controller != null &&
          _controller!.value.isInitialized &&
          _controller!.value.isStreamingImages) {
        _controller!.stopImageStream();
        debugPrint('图像流已安全停止');
      }
    } catch (e) {
      debugPrint('停止图像流出错: $e');
      // 即使出错也确保清理资源
      _imageStreamSubscription = null;
    }
  }

  // 从当前预览中获取图像
  Future<Uint8List?> _getImageFromStream() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      debugPrint('相机未初始化，无法获取图像');
      return null;
    }

    try {
      // 确保在获取图像前相机处于稳定状态
      await Future.delayed(const Duration(milliseconds: 100));

      // 直接拍照获取高质量图像，这比从流中提取单帧更可靠
      final XFile photo = await _controller!.takePicture();
      if (!mounted) return null; // 确保组件仍然挂载

      final bytes = await photo.readAsBytes();
      debugPrint('成功从相机获取图像: ${bytes.length / 1024}KB');
      return bytes;
    } catch (e) {
      debugPrint('从预览获取图像失败: $e');
      return null;
    }
  }

  // 处理"教我拍"按钮点击
  Future<void> _handleTeachPress(BuildContext context) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    // 检查是否已经在教我拍流程中，如果是则不执行
    if (cameraProvider.isTeachingInProgress) {
      debugPrint('📸 教我拍流程正在进行中，忽略重复点击');
      return;
    }

    // 先重置状态，确保每次点击都会触发完整的流程
    cameraProvider.resetUploadState();

    // 在此处立即设置上传状态为进行中，确保按钮立即变为灰色
    cameraProvider.setUploadState(UploadState.uploading);

    // 使用微任务确保UI立即更新
    await Future.microtask(() {});

    final startTime = DateTime.now(); // 记录开始时间
    debugPrint('📸 教我拍流程开始: ${startTime.toString()}');

    // 打印相机画面的实际分辨率
    final cameraResolution = _controller!.value.previewSize;
    debugPrint(
        '📸 相机画面的实际分辨率: ${cameraResolution?.width} x ${cameraResolution?.height}');

    try {
      // 使用直接获取低分辨率图像的方式
      debugPrint('📸 开始获取图像...');
      final lowResStartTime = DateTime.now();

      // 直接从当前预览获取一帧图像，避免多次拍照
      final bytes = await _getImageFromStream();
      if (bytes == null) {
        throw Exception('无法获取相机图像');
      }

      // 保存最后一帧预览，用于显示
      setState(() {
        _lastPreviewFrame = bytes;
      });

      debugPrint(
          '📸 图像获取到内存: ${DateTime.now().difference(lowResStartTime).inMilliseconds}ms');

      // 直接调整图像大小至较低分辨率
      final resizedBytes = await _resizeImageFast(bytes, targetWidth: 640);
      final resizeEndTime = DateTime.now();
      debugPrint(
          '📸 图像缩放完成: ${resizeEndTime.difference(lowResStartTime).inMilliseconds}ms');
      debugPrint('📸 低分辨率图像大小: ${resizedBytes.length / 1024}KB');

      // 计算并打印从点击到发起HTTP请求的总耗时
      final requestStartTime = DateTime.now();
      debugPrint(
          '📸 从点击按钮到准备发起HTTP请求总耗时: ${requestStartTime.difference(startTime).inMilliseconds}ms');

      // 调用AI分析服务
      await cameraProvider.analyzeImageBytes(resizedBytes);
      final analysisEndTime = DateTime.now();

      // 打印HTTP请求的耗时
      debugPrint(
          '📸 HTTP请求耗时: ${analysisEndTime.difference(requestStartTime).inMilliseconds}ms');

      // 设置上传状态为成功
      cameraProvider.setUploadState(UploadState.success);

      // 计算整个流程的总耗时
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('📸 教我拍流程完成，总耗时: ${totalTime}ms');

      // 设置一个延时，在显示tips一段时间后自动结束流程
      Future.delayed(const Duration(seconds: 12), () {
        if (mounted && cameraProvider.isTeachingInProgress) {
          debugPrint('📸 教我拍流程自动结束');
          cameraProvider.finishTeaching();
        }
      });
    } catch (e) {
      debugPrint('📸 教我拍照错误: $e');
      cameraProvider.setUploadState(UploadState.error);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法分析照片，请重试')),
        );
      }

      // 记录错误时的总耗时
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('📸 教我拍流程失败，总耗时: ${totalTime}ms');
    }
  }

  // 快速调整图像大小 - 比压缩更高效
  Future<Uint8List> _resizeImageFast(Uint8List imageBytes,
      {required int targetWidth}) async {
    final resizeStartTime = DateTime.now();

    try {
      // 解码图像
      final img.Image? originalImage = img.decodeImage(imageBytes);
      if (originalImage == null) return imageBytes;

      // 打印原始图像分辨率
      debugPrint(
          '📸 原始图像分辨率: ${originalImage.width} x ${originalImage.height}');

      // 计算目标高度，保持纵横比
      final int targetHeight =
          (originalImage.height * targetWidth / originalImage.width).round();

      // 调整大小 - 使用最快的调整算法
      final img.Image resizedImage = img.copyResize(
        originalImage,
        width: targetWidth,
        height: targetHeight,
        interpolation: img.Interpolation.nearest, // 最快的插值算法
      );

      // 打印请求服务的图像分辨率
      debugPrint(
          '📸 请求服务的图像分辨率: ${resizedImage.width} x ${resizedImage.height}');

      // 编码为JPEG - 比PNG更快，文件更小
      final Uint8List result = Uint8List.fromList(img.encodeJpg(
        resizedImage,
        quality: 85, // 适中的质量，平衡大小和视觉效果
      ));

      final resizeDuration =
          DateTime.now().difference(resizeStartTime).inMilliseconds;
      debugPrint('📸 快速图像尺寸调整耗时: ${resizeDuration}ms');
      debugPrint(
          '📸 调整后图像大小: ${result.length / 1024}KB, 尺寸: ${targetWidth}x${targetHeight}');

      return result;
    } catch (e) {
      debugPrint('📸 调整图像大小出错: $e');
      return imageBytes;
    }
  }

  // 显示全屏图像
  void _showFullScreenImage(BuildContext context, String imagePath) {
    try {
      // 在导航前安全释放相机资源
      if (_controller != null && _controller!.value.isInitialized) {
        _stopImageStream();

        final oldController = _controller;
        _controller = null;

        oldController?.dispose().catchError((e) {
          debugPrint('释放相机资源错误: $e');
        });

        _isInitialized = false;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FullScreenImage(imagePath: imagePath),
        ),
      ).then((_) {
        // 返回时重新初始化相机
        if (mounted) {
          _initializeCamera();
        }
      });
    } catch (e) {
      debugPrint('显示全屏图像错误: $e');
    }
  }

  // 处理拍摄比例变化
  Future<void> _updateAspectRatio(String ratio) async {
    debugPrint('CameraScreen 接收到新的拍摄比例: $ratio，当前比例: $_currentAspectRatio');

    setState(() {
      _currentAspectRatio = ratio;
    });

    debugPrint('CameraScreen 已更新状态，新比例: $_currentAspectRatio');

    // 如果相机控制器已初始化，尝试更新相机的拍摄比例
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        // 计算新的目标宽高比
        double targetAspectRatio;
        switch (ratio) {
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

        // 获取屏幕尺寸
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final previewHeight = screenWidth / targetAspectRatio;

        debugPrint(
            '目标宽高比: $targetAspectRatio, 预览尺寸: $screenWidth x $previewHeight');
        debugPrint('屏幕尺寸: $screenWidth x $screenHeight');

        // 强制重新布局以确保预览框尺寸和位置正确更新
        setState(() {});

        debugPrint('强制刷新布局完成');

        // 添加短暂延迟后再次更新，确保布局完全应用
        // 这将更新顶部按钮和缩放控制的位置
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
            debugPrint('延迟100ms后布局刷新完成');
          }
        });

        // 再添加一次延迟更新，确保在动画完成后布局稳定
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {});
            debugPrint('延迟300ms后布局刷新完成');
          }
        });
      } catch (e) {
        debugPrint('设置拍摄比例错误: $e');
      }
    }
  }

  // 处理滤镜变化
  void _handleFilterChange(FilterType filter) {
    // 选择后自动关闭滤镜选择器
    setState(() {
      _currentFilter = filter;
      _showFilterSelector = false;
    });

    // 使用选定的滤镜
    debugPrint('滤镜已更改为: ${CameraFilters.getFilterName(filter)}');
  }

  // 切换滤镜选择器显示状态
  void _toggleFilterSelector() {
    // 直接切换滤镜选择器状态，不再使用takePicture
    setState(() {
      _showFilterSelector = !_showFilterSelector;

      // 如果打开滤镜选择器，临时保存当前选择的滤镜
      if (_showFilterSelector) {
        debugPrint('显示滤镜选择器');
      } else {
        debugPrint('隐藏滤镜选择器');
      }
    });
  }
}

class FullScreenImage extends StatelessWidget {
  final String imagePath;

  const FullScreenImage({Key? key, required this.imagePath}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 照片查看区域，支持缩放和平移
          Center(
            child: GestureDetector(
              onDoubleTap: () => Navigator.pop(context),
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(
                  tag: 'photo_preview',
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                    errorBuilder: (context, error, stackTrace) {
                      return const Center(
                        child: Text(
                          '无法加载图片',
                          style: TextStyle(color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),

          // 顶部操作栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Colors.white,
                          size: 28,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.share,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              // TODO: 实现分享功能
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('分享功能待实现')),
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.delete,
                              color: Colors.white,
                              size: 24,
                            ),
                            onPressed: () {
                              _showDeleteConfirmation(context, imagePath);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

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
}
