import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:provider/provider.dart';
import '../providers/camera_provider.dart';
import '../widgets/shooting_tips.dart';
import '../widgets/camera_controls.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'dart:io';

class CameraScreen extends StatefulWidget {
  final List<CameraDescription> cameras;

  const CameraScreen({super.key, required this.cameras});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  bool _showingTips = false;
  double _minAvailableZoom = 1.0;
  double _maxAvailableZoom = 1.0;
  double _currentZoom = 1.0;
  double _baseZoom = 1.0;

  @override
  void initState() {
    super.initState();
    // 初始化相机
    _controller = CameraController(widget.cameras[0], ResolutionPreset.high);
    _initializeControllerFuture = _controller.initialize().then((_) async {
      // 获取相机支持的最大/最小焦距
      _minAvailableZoom = await _controller.getMinZoomLevel();
      _maxAvailableZoom = await _controller.getMaxZoomLevel();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              children: [
                // 相机预览
                GestureDetector(
                  onScaleStart: (details) {
                    _baseZoom = _currentZoom;
                  },
                  onScaleUpdate: (details) {
                    double newZoom = (_baseZoom * details.scale)
                        .clamp(_minAvailableZoom, _maxAvailableZoom);
                    _controller.setZoomLevel(newZoom);
                    setState(() {
                      _currentZoom = newZoom;
                    });
                  },
                  child: SizedBox.expand(
                    child: AspectRatio(
                      aspectRatio: 1 / _controller.value.aspectRatio,
                      child: CameraPreview(_controller),
                    ),
                  ),
                ),

                // 拍摄建议气泡
                if (_showingTips) const ShootingTips(),

                // 底部控制栏
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: CameraControls(
                    onTeachPress: _handleTeachPress,
                    onCapturePress: _handleCapturePress,
                    showingTips: _showingTips,
                  ),
                ),
              ],
            );
          } else {
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }

  Future<String> _compressImage(String imagePath) async {
    final file = File(imagePath);
    final targetPath = imagePath.replaceAll('.jpg', '_compressed.jpg');
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 85,
      minWidth: 1024,
      minHeight: 1024,
      // 设置最大字节为1MB
      keepExif: false,
    );
    
    if (result == null) return imagePath;
    
    // 检查压缩后的文件大小
    final compressedSize = await result.length();
    if (compressedSize > 1024 * 1024) {
      // 如果仍然超过1MB，递归压缩，降低质量
      await File(result.path).delete();
      return _compressImage(imagePath);
    }
    
    // 删除原始文件
    await file.delete();
    return result.path;
  }

  void _handleTeachPress() async {
    final cameraProvider = context.read<CameraProvider>();

    // 获取当前预览图像
    final image = await _controller.takePicture();
    
    // 压缩图片
    final compressedImagePath = await _compressImage(image.path);

    // 调用AI分析获取建议
    await cameraProvider.analyzeImage(compressedImagePath);

    setState(() {
      _showingTips = true;
    });
  }

  void _handleCapturePress() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      // 压缩图片
      final compressedImagePath = await _compressImage(image.path);

      // 保存到相册
      if (context.mounted) {
        final save = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
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
          final result = await ImageGallerySaver.saveFile(compressedImagePath);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(result['isSuccess'] ? '照片已保存到相册' : '保存失败'),
              ),
            );
          }
        }
      }

      setState(() {
        _showingTips = false;
      });
    } catch (e) {
      debugPrint(e.toString());
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('拍照出错')));
      }
    }
  }
}
