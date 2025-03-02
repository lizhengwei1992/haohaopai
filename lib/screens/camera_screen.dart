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
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 1.0;
  double _baseScaleLevel = 1.0;

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

      _minZoomLevel = await cameraController.getMinZoomLevel();
      _maxZoomLevel = await cameraController.getMaxZoomLevel();

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
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final cameraProvider = Provider.of<CameraProvider>(context);
    final settingsProvider = Provider.of<SettingsProvider>(context);
    final showingTips = cameraProvider.state == CameraState.showingTips;
    final analyzing = cameraProvider.state == CameraState.analyzing;
    final showGridLines = (settingsProvider.showGridLines && !showingTips) ||
        (cameraProvider.state == CameraState.showingTips);

    return Scaffold(
      body: Stack(
        children: [
          // 相机预览
          Positioned.fill(
            child: AspectRatio(
              aspectRatio: 1,
              child: ClipRect(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller!.value.previewSize!.height,
                    height: _controller!.value.previewSize!.width,
                    child: GestureDetector(
                      onScaleStart: (details) {
                        _baseScaleLevel = _currentZoomLevel;
                      },
                      onScaleUpdate: (details) {
                        if (details.scale != 1.0) {
                          double newZoomLevel =
                              (_baseScaleLevel * details.scale)
                                  .clamp(_minZoomLevel, _maxZoomLevel);
                          _setZoomLevel(newZoomLevel);
                        }
                      },
                      child: CameraPreview(_controller!),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 相机网格线
          if (showGridLines)
            Positioned.fill(
              child: CameraGridLines(showGrid: true),
            ),

          // 顶部操作栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isFlashOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleFlash,
                      tooltip: _isFlashOn ? '关闭闪光灯' : '开启闪光灯',
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(128),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${_currentZoomLevel.toStringAsFixed(1)}x',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SettingsScreen(),
                          ),
                        );
                      },
                      tooltip: '设置',
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 拍摄建议
          if (showingTips) const ShootingTips(),

          // 底部操作栏
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.8), Colors.transparent],
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // 左侧预览相册按钮
                          Consumer<CameraProvider>(
                            builder: (context, provider, child) {
                              final hasRecentPhotos =
                                  provider.recentPhotos.isNotEmpty;

                              return GestureDetector(
                                onTap: () {
                                  if (hasRecentPhotos) {
                                    // 全屏查看照片
                                    _showFullScreenImage(context,
                                        provider.recentPhotos.first.path);
                                  } else {
                                    // 如果没有照片，显示提示
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('没有最近拍摄的照片')),
                                    );
                                  }
                                },
                                child: Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 2),
                                    color: Colors.black.withOpacity(0.3),
                                  ),
                                  child: hasRecentPhotos
                                      ? ClipOval(
                                          child: Hero(
                                            tag: 'photo_preview',
                                            child: Image.file(
                                              File(provider
                                                  .recentPhotos.first.path),
                                              fit: BoxFit.cover,
                                              width: 50,
                                              height: 50,
                                              errorBuilder:
                                                  (context, error, stackTrace) {
                                                return const Icon(
                                                  Icons.photo_library,
                                                  color: Colors.white,
                                                  size: 24,
                                                );
                                              },
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.photo_library,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                ),
                              );
                            },
                          ),

                          // 中间拍摄按钮
                          GestureDetector(
                            onTap: () => showingTips
                                ? _handleCapturePress(context)
                                : _handleTeachPress(context),
                            child: Container(
                              width: 70,
                              height: 70,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border:
                                    Border.all(color: Colors.white, width: 3),
                                color: Colors.transparent,
                              ),
                              child: Center(
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 300),
                                  width: 60,
                                  height: 60,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: Center(
                                    child: Text(
                                      showingTips ? '拍摄' : '教我拍',
                                      style: const TextStyle(
                                        color: Colors.black,
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 右侧占位，保持布局平衡
                          const SizedBox(width: 50, height: 50),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 加载指示器
          if (analyzing)
            Container(
              color: Colors.black54,
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
      }

      // 将原始图像数据保存为压缩的PNG格式
      final String pngPath = await _saveAsPng(originalPath);
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

  // 将原始图像数据保存为压缩的PNG格式
  Future<String> _saveAsPng(String imagePath) async {
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
      final img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        // 直接编码为PNG格式并保存
        final pngBytes = img.encodePng(image);
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

      // 直接将原始图像数据保存为PNG格式
      final String pngPath = await _saveAsPng(photo.path);

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
