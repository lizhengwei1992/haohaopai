import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

import '../providers/camera_provider.dart';
import '../providers/settings_provider.dart';
import '../widgets/camera/camera_controls.dart';
import '../widgets/camera/camera_top_bar.dart';
import '../widgets/camera/camera_grid_lines.dart';
import '../widgets/camera/shooting_tips.dart';
import 'settings/settings_screen.dart';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;

  // 相机状态
  int _selectedCameraIndex = 0;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;
  bool _flashEnabled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera(_selectedCameraIndex);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 应用生命周期变化时处理相机
    if (!_controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      _controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(_selectedCameraIndex);
    }
  }

  // 初始化相机
  Future<void> _initCamera(int cameraIndex) async {
    _controller = CameraController(
      widget.cameras[cameraIndex],
      ResolutionPreset.max,
      imageFormatGroup: ImageFormatGroup.jpeg,
      enableAudio: false,
    );

    _initializeControllerFuture = _controller.initialize().then((_) async {
      if (!mounted) return;

      // 获取相机支持的最大/最小焦距
      _minAvailableZoom = await _controller.getMinZoomLevel();
      _maxAvailableZoom = await _controller.getMaxZoomLevel();

      // 确保使用正确的方向
      await _controller.lockCaptureOrientation();

      setState(() {});
    });
  }

  // 切换相机
  Future<void> _switchCamera() async {
    final cameraProvider = context.read<CameraProvider>();
    if (cameraProvider.state == CameraState.analyzing) return;

    final newIndex = _selectedCameraIndex == 0 ? 1 : 0;

    if (newIndex >= widget.cameras.length) return;

    setState(() {
      _selectedCameraIndex = newIndex;
      _flashEnabled = false;
    });

    await _controller.dispose();
    await _initCamera(newIndex);
  }

  // 切换闪光灯
  void _toggleFlash() async {
    if (!_controller.value.isInitialized) return;

    setState(() {
      _flashEnabled = !_flashEnabled;
    });

    await _controller.setFlashMode(
      _flashEnabled ? FlashMode.torch : FlashMode.off,
    );
  }

  // 打开设置
  void _openSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  // 打开相册
  void _openGallery() {
    // TODO: 实现打开相册功能
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('相册功能即将上线')));
  }

  // 教我拍照
  void _handleTeachPress() async {
    final cameraProvider = context.read<CameraProvider>();

    try {
      // 确保相机已初始化
      await _initializeControllerFuture;

      // 拍摄照片
      final image = await _controller.takePicture();

      // 分析照片
      if (mounted) {
        await cameraProvider.analyzeImage(image.path);
      }
    } catch (e) {
      debugPrint('教我拍照出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法分析照片，请重试')));
      }
    }
  }

  // 拍照
  void _handleCapturePress() async {
    final cameraProvider = context.read<CameraProvider>();
    final settingsProvider = context.read<SettingsProvider>();

    try {
      // 确保相机已初始化
      await _initializeControllerFuture;

      // 拍摄照片
      final image = await _controller.takePicture();

      // 压缩照片
      final compressedImagePath = await cameraProvider.compressImageForSaving(
        image.path,
        settingsProvider.imageQuality,
      );

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
          // 保存照片到相册
          final success = await cameraProvider.saveToGallery(
            compressedImagePath,
          );

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(success ? '照片已保存到相册' : '保存失败')),
            );
          }
        }

        // 重置状态
        cameraProvider.reset();
      }
    } catch (e) {
      debugPrint('拍照出错: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('拍照出错')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final cameraProvider = context.watch<CameraProvider>();
    final showingTips = cameraProvider.state == CameraState.showingTips;

    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                // 相机预览
                _buildCameraPreview(),

                // 网格线
                if (settingsProvider.showGridLines)
                  CameraGridLines(showGrid: true),

                // 顶部控制栏
                CameraTopBar(
                  currentZoom: _currentZoom,
                  flashEnabled: _flashEnabled,
                  onFlashToggle: _toggleFlash,
                  onSettingsPressed: _openSettings,
                ),

                // 拍摄建议 - 确保在showingTips状态下显示
                if (showingTips) const ShootingTips(),

                // 底部控制栏
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CameraControls(
                    onTeachPress: _handleTeachPress,
                    onCapturePress: _handleCapturePress,
                    onGalleryPress: _openGallery,
                    onSwitchCameraPress: _switchCamera,
                    showingTips: showingTips, // 传递状态给控制栏
                  ),
                ),

                // 加载指示器
                if (cameraProvider.state == CameraState.analyzing)
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
            );
          } else {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
        },
      ),
    );
  }

  Widget _buildCameraPreview() {
    // 获取屏幕尺寸
    final size = MediaQuery.of(context).size;
    // 获取相机预览的宽高比
    final deviceRatio = size.width / size.height;
    final cameraRatio = _controller.value.aspectRatio;

    // 计算缩放比例，使相机预览填满屏幕
    var scale = deviceRatio / cameraRatio;

    // 如果是横屏模式，需要调整缩放比例
    if (MediaQuery.of(context).orientation == Orientation.landscape) {
      scale = 1 / scale;
    }

    return Transform.scale(
      scale: scale,
      child: Center(
        child: GestureDetector(
          onScaleStart: (details) {
            _baseZoom = _currentZoom;
          },
          onScaleUpdate: (details) {
            double newZoom = (_baseZoom * details.scale).clamp(
              _minAvailableZoom,
              _maxAvailableZoom,
            );

            _controller.setZoomLevel(newZoom);
            setState(() {
              _currentZoom = newZoom;
            });
          },
          child: CameraPreview(_controller),
        ),
      ),
    );
  }
}
