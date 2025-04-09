import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'native_camera_service.dart';

// 定义滤镜类型枚举
enum FilterType {
  none,
  natural,
  vivid,
  cold,
  warm,
  blackAndWhite,
  toggle, // 特殊值，用于切换滤镜选择器
}

/// 提供相机控制功能的类
class CameraControl {
  // 相机控制状态
  bool isFlashOn = false;
  double currentZoomLevel = 1.0;
  double minZoomLevel = 1.0;
  double maxZoomLevel = 3.0;
  bool showGridLines = false;
  String currentAspectRatio = '4:3';
  FilterType currentFilter = FilterType.none;
  bool showFilterSelector = false;
  double baseScaleLevel = 1.0;
  bool isCameraChanging = false;
  Map<String, dynamic> cameraCapabilities = {};

  // 焦点相关
  Offset? focusPoint;
  bool showFocusPoint = false;
  bool focusSuccess = false;

  // 原生相机控制器
  final NativeCameraController? nativeCameraController;

  // 状态更新回调
  final Function(VoidCallback fn) onStateUpdate;

  // 构造函数
  CameraControl({
    required this.onStateUpdate,
    this.nativeCameraController,
  });

  // 设置焦点点
  void setFocusPoint(Offset point, BoxConstraints constraints) {
    if (nativeCameraController != null) {
      // 计算相对于相机视图的比例坐标 (0.0-1.0)
      final double relativeX = point.dx / constraints.maxWidth;
      final double relativeY = point.dy / constraints.maxHeight;

      // 应用对焦
      nativeCameraController!
          .setFocusPoint(relativeX, relativeY)
          .then((success) {
        if (success) {
          onStateUpdate(() {
            focusPoint = point;
            showFocusPoint = true;
            focusSuccess = true;
          });

          // 3秒后隐藏对焦点
          Future.delayed(const Duration(seconds: 3), () {
            onStateUpdate(() {
              showFocusPoint = false;
            });
          });
        }
      });
    } else {
      // 模拟对焦点
      onStateUpdate(() {
        focusPoint = point;
        showFocusPoint = true;
        focusSuccess = true;
      });

      // 3秒后隐藏对焦点
      Future.delayed(const Duration(seconds: 3), () {
        onStateUpdate(() {
          showFocusPoint = false;
        });
      });
    }
  }

  // 拍照
  Future<void> capturePhoto(BuildContext context) async {
    if (nativeCameraController != null) {
      try {
        // 使用原生相机拍照
        final imageData = await nativeCameraController!.capturePhoto();
        if (imageData != null) {
          // 在这里处理照片数据，如保存到相册、显示预览等
          debugPrint('拍照成功，获取到照片数据: ${imageData.length} 字节');

          // TODO: 添加照片处理逻辑

          // 显示提示
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('照片已拍摄，功能待实现')),
          );
        }
      } catch (e) {
        debugPrint('拍照出错: $e');
        // 显示错误提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('拍照失败: $e')),
        );
      }
    } else {
      // 模拟拍照
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相机功能模拟：已拍摄照片')),
      );
    }
  }

  // 切换闪光灯
  Future<void> toggleFlash() async {
    // 临时占位实现，仅更新UI状态
    onStateUpdate(() {
      isFlashOn = !isFlashOn;
    });

    // 原本的NativeCameraController.toggleFlash()相关代码被移除
    debugPrint('闪光灯切换功能尚未实现');
  }

  // 切换前后摄像头
  Future<void> switchCamera() async {
    if (nativeCameraController != null) {
      onStateUpdate(() {
        isCameraChanging = true;
      });

      try {
        // 获取当前是否为前置摄像头
        bool isFront;
        try {
          isFront = await nativeCameraController!.isFrontCamera();
          debugPrint('当前是否前置相机: $isFront');
        } catch (e) {
          // 如果调用失败，假设当前不是前置
          debugPrint('检查相机方向失败: $e，假设当前不是前置相机');
          isFront = false;
        }

        // 切换到相反的摄像头
        final success =
            await nativeCameraController!.switchCamera(toFront: !isFront);
        debugPrint('切换相机结果: $success');

        onStateUpdate(() {
          isCameraChanging = false;
        });
      } catch (e) {
        debugPrint('切换相机出错: $e');
        onStateUpdate(() {
          isCameraChanging = false;
        });
      }
    }
  }

  // 设置滤镜
  Future<void> setFilter(FilterType filter) async {
    // 如果是切换滤镜选择器的请求
    if (filter == FilterType.toggle) {
      onStateUpdate(() {
        showFilterSelector = !showFilterSelector;
      });
      return;
    }

    // 临时占位实现，仅更新UI状态
    onStateUpdate(() {
      currentFilter = filter;
    });

    // 原本的NativeCameraController.setFilter()相关代码被移除
    debugPrint('滤镜设置功能尚未实现');
  }

  // 设置拍摄比例
  Future<void> setAspectRatio(String ratio) async {
    // 临时占位实现，仅更新UI状态
    onStateUpdate(() {
      currentAspectRatio = ratio;
    });

    // 原本的NativeCameraController.setAspectRatio()相关代码被移除
    debugPrint('拍摄比例设置功能尚未实现');
  }

  // 切换拍摄比例
  void toggleAspectRatio() {
    // 循环切换可用比例：4:3 -> 1:1 -> 16:9 -> 4:3
    final ratios = ['4:3', '1:1', '16:9'];
    final currentIndex = ratios.indexOf(currentAspectRatio);
    final nextIndex = (currentIndex + 1) % ratios.length;
    setAspectRatio(ratios[nextIndex]);
  }

  // 设置缩放级别
  Future<void> setZoomLevel(double zoomLevel) async {
    // 限制在允许的范围内
    double newZoomLevel = zoomLevel;
    if (newZoomLevel < minZoomLevel) {
      newZoomLevel = minZoomLevel;
    } else if (newZoomLevel > maxZoomLevel) {
      newZoomLevel = maxZoomLevel;
    }

    if (nativeCameraController != null) {
      // 使用原生相机设置缩放
      final success = await nativeCameraController!.setZoomLevel(newZoomLevel);
      if (success) {
        onStateUpdate(() {
          currentZoomLevel = newZoomLevel;
        });
      }
    } else {
      // 仅更新状态，模拟缩放效果
      onStateUpdate(() {
        currentZoomLevel = newZoomLevel;
      });
    }
  }
}

/// 相机控制按钮布局构建类
class CameraControlWidgets {
  final CameraControl controller;
  final BuildContext context;

  CameraControlWidgets(this.context, this.controller);

  // 构建缩放控制UI
  Widget buildZoomControl() {
    return Container(
      height: 40,
      color: Colors.transparent,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(80, 80, 80, 0.2),
            borderRadius: BorderRadius.circular(40),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildZoomOption('0.5×', controller.currentZoomLevel == 0.5),
              const SizedBox(width: 6),
              _buildZoomOption('1×', controller.currentZoomLevel == 1.0),
              const SizedBox(width: 6),
              _buildZoomOption('2×', controller.currentZoomLevel == 2.0),
              const SizedBox(width: 6),
              _buildZoomOption('3×', controller.currentZoomLevel == 3.0),
            ],
          ),
        ),
      ),
    );
  }

  // 构建缩放选项
  Widget _buildZoomOption(String label, bool isSelected) {
    final textStyle = TextStyle(
      color: isSelected ? Colors.yellow : Colors.white,
      fontSize: 14,
      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
    );

    return GestureDetector(
      onTap: () => _handleZoomOptionTap(label),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected
              ? const Color.fromRGBO(100, 100, 100, 0.5)
              : Colors.transparent,
        ),
        child: Center(
          child: Text(
            label,
            style: textStyle,
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }

  // 处理缩放选项点击
  void _handleZoomOptionTap(String label) {
    double zoomLevel = 1.0;

    if (label == '0.5×') {
      zoomLevel = 0.5;
    } else if (label == '1×') {
      zoomLevel = 1.0;
    } else if (label == '2×') {
      zoomLevel = 2.0;
    } else if (label == '3×') {
      zoomLevel = 3.0;
    }

    controller.setZoomLevel(zoomLevel);
  }

  // 构建相机控制按钮
  Widget buildCameraControlButtons() {
    return Container(
      width: double.infinity,
      height: 50, // 固定高度为50
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // 闪光灯按钮
          _buildControlButton(
            onTap: controller.toggleFlash,
            child: SvgPicture.asset(
              controller.isFlashOn
                  ? 'assets/icons/camera_flash_off.svg'
                  : 'assets/icons/camera_flash_auto.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),

          // 曝光按钮
          _buildControlButton(
            onTap: () {
              // 曝光控制功能将在后续实现
            },
            child: _buildExposureIcon(),
          ),

          // 画面比例按钮
          _buildControlButton(
            onTap: controller.toggleAspectRatio,
            child: Text(
              controller.currentAspectRatio,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          // 滤镜按钮
          _buildControlButton(
            onTap: () => controller.setFilter(FilterType.toggle),
            child: SvgPicture.asset(
              'assets/icons/camera_fliter.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),

          // 相机翻转按钮
          _buildControlButton(
            onTap: controller.switchCamera,
            child: SvgPicture.asset(
              'assets/icons/camera_reverse.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建控制按钮
  Widget _buildControlButton({
    required VoidCallback onTap,
    required Widget child,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(child: child),
      ),
    );
  }

  // 构建曝光图标
  Widget _buildExposureIcon() {
    return CustomPaint(
      size: const Size(22, 22),
      painter: ExposureIconPainter(),
    );
  }

  // 构建底部控制栏
  Widget buildBottomControls() {
    return Container(
      height: 96, // 使用固定高度，确保足够空间
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 中间拍摄按钮
          Center(child: _buildCaptureButton()),

          // 左右两侧按钮的容器
          Container(
            width: double.infinity,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // 左侧相册按钮
                  GestureDetector(
                    onTap: () {
                      // 相册功能将在后续实现
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFA0A9FC),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/photo_album.svg',
                          width: 45,
                          height: 45,
                        ),
                      ),
                    ),
                  ),

                  // 右侧教我拍按钮
                  GestureDetector(
                    onTap: () {
                      // 教我拍功能将在后续实现
                    },
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: SvgPicture.asset(
                          'assets/icons/magic.svg',
                          width: 96,
                          height: 96,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建拍照按钮
  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: () => controller.capturePhoto(context),
      child: Container(
        width: 70,
        height: 70,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromRGBO(52, 137, 142, 1),
                    width: 3,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(70, 70)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromRGBO(8, 229, 235, 1),
                    width: 3,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(70, 70)),
                ),
              ),
            ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.11723876744508743, 0.9628744125366211),
                    end: Alignment(-0.908519446849823, 0.28769782185554504),
                    colors: [
                      Color.fromRGBO(121, 113, 181, 1),
                      Color.fromRGBO(32, 34, 67, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.all(Radius.elliptical(60, 60)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 构建滤镜选择器
  Widget buildFilterSelector() {
    // 滤镜选项
    final List<Map<String, dynamic>> filters = [
      {'type': FilterType.none, 'name': '无'},
      {'type': FilterType.natural, 'name': '自然'},
      {'type': FilterType.vivid, 'name': '鲜艳'},
      {'type': FilterType.cold, 'name': '冷色'},
      {'type': FilterType.warm, 'name': '暖色'},
      {'type': FilterType.blackAndWhite, 'name': '黑白'},
    ];

    return Container(
      height: 120,
      color: Colors.black54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final bool isSelected = controller.currentFilter == filter['type'];

          return GestureDetector(
            onTap: () {
              controller.setFilter(filter['type'] as FilterType);
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.yellow : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    // 这里可以添加预览图，目前使用占位符
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filter['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.yellow : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// 曝光图标绘制器
class ExposureIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // 绘制一个圆
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 3,
      paint,
    );

    // 绘制中心点
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width / 12,
      Paint()..color = Colors.white,
    );

    // 绘制四条辐射线
    // 上
    canvas.drawLine(
      Offset(size.width / 2, size.height / 6),
      Offset(size.width / 2, 0),
      paint,
    );
    // 下
    canvas.drawLine(
      Offset(size.width / 2, size.height * 5 / 6),
      Offset(size.width / 2, size.height),
      paint,
    );
    // 左
    canvas.drawLine(
      Offset(size.width / 6, size.height / 2),
      Offset(0, size.height / 2),
      paint,
    );
    // 右
    canvas.drawLine(
      Offset(size.width * 5 / 6, size.height / 2),
      Offset(size.width, size.height / 2),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
