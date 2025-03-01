import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:provider/provider.dart';
import 'settings/settings_screen.dart';
import '../providers/camera_provider.dart';
import '../widgets/camera/shooting_tips.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image/image.dart' as img;

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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController? cameraController = _controller;

    // App state changed before we got the chance to initialize.
    if (cameraController == null || !cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
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
    final showingTips = cameraProvider.state == CameraState.showingTips;
    final analyzing = cameraProvider.state == CameraState.analyzing;

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
                        // 记录缩放开始时的缩放级别
                        _baseScaleLevel = _currentZoomLevel;
                      },
                      onScaleUpdate: (details) {
                        // 根据手势缩放比例更新相机缩放级别
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
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
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
                          IconButton(
                            icon: const Icon(
                              Icons.photo_library,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () {
                              // TODO: 实现相册功能
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

      // 直接将原始图像数据保存为PNG格式
      final String pngPath = await _saveAsPng(originalPath);

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
          // 保存PNG格式照片到相册
          final success = await cameraProvider.saveToGallery(pngPath);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(success ? '照片已保存到相册' : '保存失败')),
            );
          }

          // 如果创建了临时PNG文件，删除它
          if (pngPath != originalPath) {
            await File(pngPath).delete().catchError((e) {
              debugPrint('删除临时PNG文件出错: $e');
            });
          }
        }

        // 重置状态
        cameraProvider.reset();
      }

      debugPrint('照片已保存: $pngPath');
    } catch (e) {
      debugPrint('拍照错误: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拍照出错，请重试')),
      );
    }
  }

  // 直接将原始图像数据保存为PNG格式
  Future<String> _saveAsPng(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      final Directory tempDir = await getTemporaryDirectory();
      final String pngPath =
          '${tempDir.path}/photo_${DateTime.now().millisecondsSinceEpoch}.png';

      // 读取原始图像数据
      final bytes = await imageFile.readAsBytes();

      // 使用image包解码图像
      final img.Image? image = img.decodeImage(bytes);

      if (image != null) {
        // 直接编码为PNG格式并保存
        final pngBytes = img.encodePng(image);
        final pngFile = File(pngPath);
        await pngFile.writeAsBytes(pngBytes);
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
      {int quality = 70}) async {
    try {
      final file = File(imagePath);
      final dir = await getTemporaryDirectory();
      final targetPath =
          '${dir.path}/analysis_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final result = await FlutterImageCompress.compressAndGetFile(
        file.absolute.path,
        targetPath,
        quality: quality,
        minWidth: 1024,
        minHeight: 1024,
      );

      if (result == null) return imagePath;

      // 检查压缩后的文件大小
      final compressedSize = await result.length();
      if (compressedSize > 1024 * 1024 && quality > 50) {
        // 如果仍然超过1MB，递归压缩，降低质量
        await File(result.path).delete();
        return _compressImageForAnalysis(imagePath, quality: quality - 10);
      }

      return result.path;
    } catch (e) {
      debugPrint('压缩图像出错: $e');
      return imagePath;
    }
  }
}
