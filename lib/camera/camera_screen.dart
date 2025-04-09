import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'native_camera_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({Key? key}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen>
    with WidgetsBindingObserver {
  // 全局相机控制器
  NativeCameraController? _cameraController;

  // 相机状态
  bool _isInitialized = false;
  bool _isFrontCamera = false;
  double _currentZoom = 1.0;

  // 对焦点位置
  Offset? _focusPoint;
  bool _showFocusPoint = false;

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
      // 创建相机控制器并增加错误捕获
      _cameraController = NativeCameraController(
        cameraId: 0,
        onCameraEvent: _handleCameraEvent,
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

  // 处理相机事件
  void _handleCameraEvent(Map<String, dynamic> event) {
    final String type = event['type'] as String? ?? 'unknown';

    switch (type) {
      case 'focusChanged':
        if (event['success'] == true) {
          final x = event['x'] as double?;
          final y = event['y'] as double?;

          if (x != null && y != null) {
            setState(() {
              _focusPoint = Offset(x, y);
              _showFocusPoint = true;
            });

            // 3秒后隐藏对焦点
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) {
                setState(() {
                  _showFocusPoint = false;
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
            _currentZoom = zoom;
          });
        }
        break;
    }
  }

  @override
  void dispose() {
    // 安全释放相机控制器
    try {
      _cameraController?.dispose();
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
        _cameraController?.resumePreview();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        debugPrint('应用进入后台，暂停相机');
        _cameraController?.pausePreview();
        break;
      case AppLifecycleState.detached:
        // 应用被终止，相机资源会在dispose中处理
        break;
    }
  }

  // 点击对焦处理
  void _handleFocusTap(TapDownDetails details) {
    if (_cameraController == null) return;

    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final offset = renderBox.globalToLocal(details.globalPosition);

    // 获取相机预览区域
    final previewSize = renderBox.size;

    // 将点击坐标转换为0-1范围
    final double x = offset.dx / previewSize.width;
    final double y = offset.dy / previewSize.height;

    // 设置对焦点
    try {
      _cameraController!.setFocusPoint(x, y);
    } catch (e) {
      // 忽略特定的插件异常，仅记录日志
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('设置对焦点时遇到预期的MissingPluginException');
      } else {
        debugPrint('设置对焦点时出错: $e');
      }
    }
  }

  // 手势缩放处理
  void _handleZoomUpdate(ScaleUpdateDetails details) {
    if (_cameraController == null) return;

    // 计算新的缩放级别
    double newZoom = _currentZoom * details.scale;

    // 限制缩放范围（可根据设备能力调整）
    newZoom = newZoom.clamp(1.0, 5.0);

    // 设置缩放级别
    try {
      _cameraController!.setZoomLevel(newZoom);
    } catch (e) {
      // 忽略特定的插件异常，仅记录日志
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('设置缩放级别时遇到预期的MissingPluginException');
      } else {
        debugPrint('设置缩放级别时出错: $e');
      }
    }
  }

  // 切换前后相机
  Future<void> _switchCamera() async {
    if (_cameraController == null) return;

    try {
      final isFront = await _cameraController!.isFrontCamera();
      await _cameraController!.switchCamera(toFront: !isFront);

      setState(() {
        _isFrontCamera = !isFront;
      });
    } catch (e) {
      // 忽略特定的插件异常，仅记录日志
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('切换相机时遇到预期的MissingPluginException');
      } else {
        debugPrint('切换相机时出错: $e');
      }
    }
  }

  // 拍照
  Future<void> _capturePhoto() async {
    if (_cameraController == null) return;

    try {
      final imageData = await _cameraController!.capturePhoto();

      if (imageData != null) {
        // 这里可以处理拍照结果，例如导航到预览页面
        debugPrint('拍照成功，照片大小: ${imageData.length} 字节');
      } else {
        debugPrint('拍照失败');
      }
    } catch (e) {
      // 忽略特定的插件异常，仅记录日志
      if (e.toString().contains('MissingPluginException')) {
        debugPrint('拍照时遇到预期的MissingPluginException');
      } else {
        debugPrint('拍照时出错: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // 如果不是iOS平台，显示不支持提示
    if (!Platform.isIOS) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: Text(
            '本功能仅支持iOS平台',
            style: TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      );
    }

    // 如果相机未初始化，显示加载指示器
    if (!_isInitialized) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    // 构建主界面
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 相机预览
            GestureDetector(
              onTapDown: _handleFocusTap,
              onScaleUpdate: _handleZoomUpdate,
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: NativeCameraView(
                    controller: _cameraController,
                    backgroundColor: Colors.black,
                    onCreated: () {
                      debugPrint('相机视图创建完成');
                    },
                  ),
                ),
              ),
            ),

            // 顶部控制栏
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 返回按钮
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  // 右侧控制按钮
                  Row(
                    children: [
                      // 切换相机按钮
                      GestureDetector(
                        onTap: _switchCamera,
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.flip_camera_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // 对焦点指示器
            if (_showFocusPoint && _focusPoint != null)
              Positioned(
                left: _focusPoint!.dx - 40,
                top: _focusPoint!.dy - 40,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.yellow, width: 2),
                    borderRadius: BorderRadius.circular(40),
                  ),
                ),
              ),

            // 底部控制栏
            Positioned(
              bottom: 30,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 拍照按钮
                  GestureDetector(
                    onTap: _capturePhoto,
                    child: Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 缩放指示器
            Positioned(
              top: 80,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${_currentZoom.toStringAsFixed(1)}x',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
