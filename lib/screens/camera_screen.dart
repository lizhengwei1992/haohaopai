import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'settings/settings_screen.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();

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
        _minZoomLevel = await cameraController.getMinZoomLevel();
        _maxZoomLevel = await cameraController.getMaxZoomLevel();

        // 确保最小缩放级别支持广角
        if (_minZoomLevel > 0.5) {
          _minZoomLevel = 0.5;
        }
      } catch (e) {
        // 如果获取失败，使用默认值
        _minZoomLevel = 0.5;
        _maxZoomLevel = 2.0;
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

  Future<void> _setZoomLevel(double zoom) async {
    if (_controller == null) return;

    try {
      await _controller!.setZoomLevel(zoom);
      setState(() {
        _currentZoomLevel = zoom;
      });
    } catch (e) {
      debugPrint('设置缩放级别错误: $e');
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

    // 在竖屏模式下，宽高比需要倒置
    final portraitTargetRatio = 1 / targetAspectRatio;

    // 计算预览区域的高度，确保水平方向充满屏幕宽度
    final previewHeight = screenWidth / portraitTargetRatio;

    // 打印当前预览区域的比例和尺寸，用于调试
    debugPrint(
        '原始相机比例: $originalAspectRatio, 目标比例: $targetAspectRatio, 竖屏目标比例: $portraitTargetRatio');
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
                          child: OverflowBox(
                            alignment: Alignment.center,
                            child: FittedBox(
                              fit: BoxFit.cover,
                              child: SizedBox(
                                width: screenWidth,
                                height: screenWidth * originalAspectRatio,
                                child: CameraPreview(_controller!),
                              ),
                            ),
                          ),
                        ),

                        // 相机网格线
                        if (showGridLines) CameraGridLines(showGrid: true),
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
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 1.0],
                ),
              ),
              child: ZoomControl(
                currentZoom: _currentZoomLevel,
                minZoom: _minZoomLevel,
                maxZoom: _maxZoomLevel,
                onZoomChanged: _setZoomLevel,
              ),
            ),
          ),

          // 底部操作栏 - 放在Stack中，使其可以与预览框重叠
          Positioned(
            bottom: 0,
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
    if (_cameras.length < 2) return;

    final int currentIndex = _cameras.indexOf(_controller!.description);
    final int newIndex = (currentIndex + 1) % _cameras.length;

    await _controller?.dispose();

    final CameraController cameraController = CameraController(
      _cameras[newIndex],
      ResolutionPreset.max,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    _controller = cameraController;

    try {
      await cameraController.initialize();
      _minZoomLevel = await cameraController.getMinZoomLevel();
      _maxZoomLevel = await cameraController.getMaxZoomLevel();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _currentZoomLevel = 1.0;
        });
      }
    } catch (e) {
      debugPrint('切换相机错误: $e');
    }
  }

  // 设置曝光值
  Future<void> _setExposure(double value) async {
    if (_controller == null) return;

    try {
      await _controller!.setExposureOffset(value);
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
        // 注意：这里只是拍摄原始照片，裁剪将在后续处理中进行
        final XFile photo = await _controller!.takePicture();
        originalPath = photo.path;

        debugPrint('原始照片已拍摄: $originalPath');
      }

      // 将原始图像数据保存为压缩的PNG格式，并应用裁剪
      final String pngPath =
          await _saveAsPng(originalPath, _currentAspectRatio);
      debugPrint('照片已处理并保存: $pngPath');

      // 询问是否保存到相册
      if (mounted) {
        final save = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('保存照片'),
            content: const Text('是否保存到相册?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('保存'),
              ),
            ],
          ),
        );

        if (save == true) {
          try {
            // 保存PNG格式照片到相册
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
        } else {
          // 如果用户选择不保存到相册，仍然将照片添加到最近照片列表
          // 这样用户可以在预览框中看到刚拍摄的照片
          final metadata = PhotoMetadata(
            path: pngPath,
            timestamp: DateTime.now(),
            isFromApp: true,
          );

          cameraProvider.addPhotoToRecentList(metadata);
        }

        // 只重置拍摄状态，不影响最近照片列表
        cameraProvider.reset();
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

  // 处理"教我拍"按钮点击
  Future<void> _handleTeachPress(BuildContext context) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }

    final cameraProvider = Provider.of<CameraProvider>(context, listen: false);

    try {
      // 拍照
      final XFile photo = await _controller!.takePicture();

      // 直接将原始图像数据保存为PNG格式，并应用裁剪
      final String pngPath = await _saveAsPng(photo.path, _currentAspectRatio);

      // 保存原始照片路径，以便后续使用
      cameraProvider.setOriginalPhotoPath(pngPath);

      // 压缩照片用于AI分析，减少传输时间
      final compressedPath = await _compressImageForAnalysis(pngPath);

      // 分析照片
      await cameraProvider.analyzeImage(compressedPath);

      // 分析完成后删除临时压缩文件
      if (compressedPath != pngPath) {
        await File(compressedPath).delete().catchError((e) {
          debugPrint('删除临时压缩文件出错: $e');
        });
      }

      debugPrint('照片已分析: $pngPath');
    } catch (e) {
      debugPrint('教我拍照错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法分析照片，请重试')),
      );
    }
  }

  // 压缩图像用于AI分析
  Future<String> _compressImageForAnalysis(String imagePath,
      {int quality = 80}) async {
    try {
      final file = File(imagePath);
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/analysis_${DateTime.now().millisecondsSinceEpoch}.jpg';

      // 获取原始文件大小
      final originalSize = await file.length();
      debugPrint('AI分析原始图片大小: ${(originalSize / 1024).toStringAsFixed(1)}KB');

      // 如果原始文件已经小于300KB，直接返回
      if (originalSize < 300 * 1024) {
        debugPrint('图片已经足够小，无需压缩用于AI分析');
        return imagePath;
      }

      // 根据原始图片大小动态调整压缩质量
      int dynamicQuality = quality;
      if (originalSize > 3 * 1024 * 1024) {
        // 大于3MB
        dynamicQuality = 70;
      } else if (originalSize > 1 * 1024 * 1024) {
        // 大于1MB
        dynamicQuality = 75;
      }

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: dynamicQuality,
        // 保持较高的分辨率以确保AI分析质量
        minWidth: 1280,
        minHeight: 1280,
        format: CompressFormat.jpeg,
      );

      if (result == null) return imagePath;

      // 检查压缩后的文件大小
      final compressedSize = await result.length();
      final savingPercentage =
          ((originalSize - compressedSize) / originalSize * 100)
              .toStringAsFixed(1);
      debugPrint(
          'AI分析图片压缩: 原始大小 ${(originalSize / 1024).toStringAsFixed(1)}KB, 压缩后 ${(compressedSize / 1024).toStringAsFixed(1)}KB, 节省 $savingPercentage%');

      // 如果压缩后仍然超过800KB且质量大于60，递归压缩，降低质量
      if (compressedSize > 800 * 1024 && dynamicQuality > 60) {
        await File(result.path).delete();
        return _compressImageForAnalysis(imagePath,
            quality: dynamicQuality - 10);
      }

      return result.path;
    } catch (e) {
      debugPrint('压缩图像出错: $e');
      return imagePath;
    }
  }

  void _showFullScreenImage(BuildContext context, String imagePath) {
    // 在导航前释放相机资源
    if (_controller != null && _controller!.value.isInitialized) {
      _controller!.dispose();
      _isInitialized = false;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImage(imagePath: imagePath),
      ),
    ).then((_) {
      // 返回时重新初始化相机
      if (!_isInitialized ||
          _controller == null ||
          !_controller!.value.isInitialized) {
        _initializeCamera();
      }
    });
  }

  // 处理拍摄比例变化
  Future<void> _updateAspectRatio(String ratio) async {
    setState(() {
      _currentAspectRatio = ratio;
    });

    // 如果相机控制器已初始化，尝试更新相机的拍摄比例
    if (_controller != null && _controller!.value.isInitialized) {
      try {
        // 计算新的目标宽高比
        double targetAspectRatio;
        switch (ratio) {
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

        // 在竖屏模式下的目标宽高比
        final portraitTargetRatio = 1 / targetAspectRatio;

        // 获取屏幕尺寸
        final screenWidth = MediaQuery.of(context).size.width;
        final previewHeight = screenWidth / portraitTargetRatio;

        debugPrint(
            '拍摄比例已更改为: $ratio, 目标宽高比: $targetAspectRatio, 预览尺寸: $screenWidth x $previewHeight');

        // 强制重新布局以确保预览框尺寸和位置正确更新
        setState(() {});

        // 添加短暂延迟后再次更新，确保布局完全应用
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            setState(() {});
          }
        });

        // 再添加一次延迟更新，确保在动画完成后布局稳定
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted) {
            setState(() {});
          }
        });
      } catch (e) {
        debugPrint('设置拍摄比例错误: $e');
      }
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
