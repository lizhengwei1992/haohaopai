import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'settings/settings_screen.dart';
import 'profile/profile_screen.dart';
import '../providers/camera_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/camera/shooting_tips.dart';
import '../widgets/camera/camera_grid_lines.dart';
import '../widgets/camera/camera_controls.dart';
import '../widgets/camera/zoom_control.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;
import '../models/photo_metadata.dart';

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
  double _minZoomLevel = 0.5;
  double _maxZoomLevel = 1.0;
  double _baseScaleLevel = 1.0;
  String _currentAspectRatio = '4:3';
  bool _isUltraWideAvailable = false;
  bool _isUsingUltraWide = false;

  // 添加手势缩放相关变量
  double _startScale = 1.0;

  // 添加平台通道
  static const platform = MethodChannel('com.example.camera/ultrawide');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
    _checkUltraWideCameraAvailability();

    // 加载应用相册中的照片
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cameraProvider =
          Provider.of<CameraProvider>(context, listen: false);
      cameraProvider.loadAppPhotos();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 如果相机控制器为空，直接返回
    if (_controller == null) {
      return;
    }

    // 当应用进入非活动状态时，释放相机资源
    if (state == AppLifecycleState.inactive) {
      // 释放相机资源
      if (_controller!.value.isInitialized) {
        _controller!.dispose();
      }
      _isInitialized = false;
    } else if (state == AppLifecycleState.resumed) {
      // 当应用恢复活动状态时，重新初始化相机
      if (!_isInitialized ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        _initializeCamera();
      }
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

  // 检查设备是否支持超广角相机
  Future<void> _checkUltraWideCameraAvailability() async {
    try {
      final bool isAvailable =
          await platform.invokeMethod('checkUltraWideCameraAvailability');
      setState(() {
        _isUltraWideAvailable = isAvailable;
        if (!isAvailable) {
          _minZoomLevel = 1.0; // 如果不支持超广角，最小缩放级别设为1.0
        }
      });
      debugPrint('超广角相机可用性: $_isUltraWideAvailable');
    } on PlatformException catch (e) {
      debugPrint('检查超广角相机可用性错误: ${e.message}');
      setState(() {
        _isUltraWideAvailable = false;
        _minZoomLevel = 1.0;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return;
      }

      final CameraController cameraController = CameraController(
        _cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      _controller = cameraController;

      await cameraController.initialize();

      // 获取相机支持的缩放范围
      try {
        final minZoom = await cameraController.getMinZoomLevel();
        final maxZoom = await cameraController.getMaxZoomLevel();

        setState(() {
          // 如果设备支持超广角，最小缩放级别设为0.5
          _minZoomLevel = _isUltraWideAvailable ? 0.5 : minZoom;
          _maxZoomLevel = maxZoom;
        });
      } catch (e) {
        // 如果获取失败，使用默认值
        setState(() {
          _minZoomLevel = _isUltraWideAvailable ? 0.5 : 1.0;
          _maxZoomLevel = 2.0;
        });
        debugPrint('获取缩放级别错误: $e');
      }

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('相机初始化错误: $e');
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

  // 处理缩放变化
  Future<void> _handleZoom(double zoom) async {
    if (zoom < 0.5) zoom = 0.5;
    if (zoom > _maxZoomLevel) zoom = _maxZoomLevel;

    setState(() {
      _currentZoomLevel = zoom;
    });

    try {
      if (_isUltraWideAvailable) {
        if (zoom < 1.0 && !_isUsingUltraWide) {
          // 切换到超广角相机
          await _switchToUltraWide(zoom);
        } else if (zoom >= 1.0 && _isUsingUltraWide) {
          // 切换回广角相机
          await _switchToWideAngle(zoom);
        } else {
          // 只调整缩放
          if (_isUsingUltraWide) {
            await _adjustUltraWideZoom(zoom);
          } else {
            await _controller!.setZoomLevel(zoom);
          }
        }
      } else {
        // 设备不支持超广角，直接使用相机控制器设置缩放
        await _controller!.setZoomLevel(zoom);
      }
    } catch (e) {
      debugPrint('设置缩放级别错误: $e');
    }
  }

  // 处理缩放手势开始
  void _handleScaleStart(ScaleStartDetails details) {
    _startScale = _currentZoomLevel;
    debugPrint('缩放手势开始: $_startScale');
  }

  // 处理缩放手势更新
  void _handleScaleUpdate(ScaleUpdateDetails details) {
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
      _handleZoom(newZoom);
      debugPrint('缩放手势更新: $newZoom');
    }
  }

  // 切换到超广角相机
  Future<void> _switchToUltraWide(double zoom) async {
    try {
      final result = await platform.invokeMethod('switchToUltraWide', {
        'zoom': zoom,
        'aspectRatio': _currentAspectRatio,
      });
      final success = result['success'] as bool;
      final message = result['message'] as String;

      if (success) {
        setState(() {
          _isUsingUltraWide = true;
        });
        debugPrint('切换到超广角相机成功: $message');
      } else {
        debugPrint('切换到超广角相机失败: $message');
      }
    } on PlatformException catch (e) {
      debugPrint('切换到超广角相机错误: ${e.message}');
    }
  }

  // 切换到广角相机
  Future<void> _switchToWideAngle(double zoom) async {
    try {
      final result =
          await platform.invokeMethod('switchToWideAngle', {'zoom': zoom});
      final success = result['success'] as bool;
      final message = result['message'] as String;

      if (success) {
        setState(() {
          _isUsingUltraWide = false;
        });
        debugPrint('切换到广角相机成功: $message');
      } else {
        debugPrint('切换到广角相机失败: $message');
      }
    } on PlatformException catch (e) {
      debugPrint('切换到广角相机错误: ${e.message}');
    }
  }

  // 调整超广角相机缩放
  Future<void> _adjustUltraWideZoom(double zoom) async {
    try {
      await platform.invokeMethod('switchToUltraWide', {
        'zoom': zoom,
        'aspectRatio': _currentAspectRatio,
      });
    } on PlatformException catch (e) {
      debugPrint('调整超广角相机缩放错误: ${e.message}');
    }
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

    // 相机控制器的原始宽高比（通常是4:3）
    final originalAspectRatio = _controller!.value.aspectRatio;

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

    // 打印当前预览区域的比例和尺寸，用于调试
    debugPrint('原始相机比例: $originalAspectRatio, 目标比例: $targetAspectRatio');
    debugPrint('预览区域尺寸: $screenWidth x $previewHeight');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 主要内容 - 使用Stack而不是Column，以便更灵活地定位预览框
          Stack(
            children: [
              // 相机预览 - 居中显示
              Positioned(
                // 计算顶部位置，使预览框垂直居中
                top: (screenHeight - previewHeight) / 2,
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
                            // 添加手势缩放功能
                            onScaleStart: _handleScaleStart,
                            onScaleUpdate: _handleScaleUpdate,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // 当不使用超广角时显示Flutter相机预览
                                if (!_isUsingUltraWide)
                                  OverflowBox(
                                    alignment: Alignment.center,
                                    child: FittedBox(
                                      fit: BoxFit.cover,
                                      child: SizedBox(
                                        width: screenWidth,
                                        height:
                                            screenWidth * originalAspectRatio,
                                        child: CameraPreview(_controller!),
                                      ),
                                    ),
                                  ),
                                // 当使用超广角时显示透明容器，让原生预览层可见
                                if (_isUsingUltraWide)
                                  Container(
                                    color: Colors.transparent,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // 相机网格线 - 移到GestureDetector之外，确保不会阻挡手势
                        if (showGridLines)
                          IgnorePointer(
                            child: CameraGridLines(showGrid: true),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 拍摄建议
              if (showingTips)
                Positioned(
                  bottom: 150, // 放在控制栏上方
                  left: 0,
                  right: 0,
                  child: const ShootingTips(),
                ),
            ],
          ),

          // 顶部空间 - 放在Stack中，使其可以与预览框重叠
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),

                  // 设置按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 缩放控制 - 移回顶部
          Positioned(
            top: topPadding + 60, // 放在顶部按钮下方
            left: 0,
            right: 0,
            child: ZoomControl(
              currentZoom: _currentZoomLevel,
              minZoom: _minZoomLevel,
              maxZoom: _maxZoomLevel,
              onZoomChanged: _handleZoom,
            ),
          ),

          // 超广角模式指示器
          if (_isUsingUltraWide)
            Positioned(
              top: topPadding + 110, // 放在缩放控制下方
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    '超广角模式',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),

          // 底部操作栏 - 放在Stack中，使其可以与预览框重叠
          Positioned(
            bottom: 20, // 增加底部间距，使控制器更靠下
            left: 0,
            right: 0,
            child: CameraControls(
              onCapturePress: () => showingTips
                  ? _handleCapturePress(context)
                  : _handleTeachPress(context),
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
              showingTips: showingTips,
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
                // 处理滤镜变化
                debugPrint('滤镜: $filter');
              },
            ),
          ),

          // 加载指示器
          if (analyzing)
            Container(
              color: Colors.black54,
              width: double.infinity,
              height: double.infinity,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      '正在分析...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // 切换前后摄像头
  Future<void> _switchCamera() async {
    if (_cameras.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('没有可用的其他相机')),
      );
      return;
    }

    final int currentCameraIndex = _cameras.indexOf(_controller!.description);
    final int newCameraIndex = (currentCameraIndex + 1) % _cameras.length;

    await _controller!.dispose();
    setState(() {
      _isInitialized = false;
      _isUsingUltraWide = false; // 切换相机时重置超广角状态
    });

    final CameraController cameraController = CameraController(
      _cameras[newCameraIndex],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();

      // 获取新相机的缩放范围
      final minZoom = await cameraController.getMinZoomLevel();
      final maxZoom = await cameraController.getMaxZoomLevel();

      setState(() {
        _isInitialized = true;
        _minZoomLevel = _isUltraWideAvailable ? 0.5 : minZoom;
        _maxZoomLevel = maxZoom;
        _currentZoomLevel = 1.0; // 重置缩放级别
      });
    } catch (e) {
      debugPrint('切换相机错误: $e');
    }
  }

  // 设置曝光值
  Future<void> _setExposure(double value) async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      await _controller!.setExposureOffset(value);
    } catch (e) {
      debugPrint('设置曝光错误: $e');
    }
  }

  // 处理"拍摄"按钮点击
  Future<void> _handleCapturePress(BuildContext context) async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    try {
      // 拍照
      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/Pictures/好好拍';
      await Directory(dirPath).create(recursive: true);
      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 使用相机控制器拍照
      final XFile photo = await _controller!.takePicture();
      await photo.saveTo(filePath);

      // 保存照片到相册
      await cameraProvider.saveToGallery(filePath);

      // 重置状态
      cameraProvider.reset();
    } catch (e) {
      debugPrint('拍照错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e')),
      );
    }
  }

  // 处理"教我拍"按钮点击
  Future<void> _handleTeachPress(BuildContext context) async {
    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    try {
      // 拍照
      final Directory extDir = await getTemporaryDirectory();
      final String dirPath = '${extDir.path}/Pictures/好好拍';
      await Directory(dirPath).create(recursive: true);
      final String filePath =
          '$dirPath/${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 使用相机控制器拍照
      final XFile photo = await _controller!.takePicture();
      await photo.saveTo(filePath);

      // 分析照片
      await cameraProvider.analyzeImage(filePath);
    } catch (e) {
      debugPrint('拍照错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('拍照失败: $e')),
      );
    }
  }

  // 显示全屏图片
  void _showFullScreenImage(BuildContext context, String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: Image.file(File(imagePath)),
          ),
        ),
      ),
    );
  }

  // 处理拍摄比例变化
  void _updateAspectRatio(String ratio) {
    setState(() {
      _currentAspectRatio = ratio;
    });

    // 如果正在使用超广角相机，更新预览层的宽高比
    if (_isUsingUltraWide) {
      _updateUltraWideAspectRatio(ratio);
    }
  }

  // 更新超广角相机预览的宽高比
  Future<void> _updateUltraWideAspectRatio(String ratio) async {
    try {
      await platform.invokeMethod('updateAspectRatio', {'aspectRatio': ratio});
      debugPrint('更新超广角预览宽高比: $ratio');
    } on PlatformException catch (e) {
      debugPrint('更新超广角预览宽高比错误: ${e.message}');
    }
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
