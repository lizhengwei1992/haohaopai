import 'package:flutter/material.dart';
import '../services/camera_service.dart';

/// 拍照操作组件
class CaptureAction extends StatelessWidget {
  const CaptureAction({Key? key}) : super(key: key);

  // 拍照
  Future<void> capturePhoto(BuildContext context) async {
    final cameraService = CameraService.instance;
    final nativeCameraController = cameraService.getGlobalCameraController();

    if (nativeCameraController != null) {
      try {
        // 使用原生相机拍照
        final imageData = await nativeCameraController.capturePhoto();
        if (imageData != null) {
          // 在这里处理照片数据，如保存到相册、显示预览等
          debugPrint('拍照成功，获取到照片数据: ${imageData.length} 字节');

          // TODO: 添加照片处理逻辑

          // 显示提示
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('照片已拍摄，功能待实现')),
            );
          }
        }
      } catch (e) {
        debugPrint('拍照出错: $e');
        // 显示错误提示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('拍照失败: $e')),
          );
        }
      }
    } else {
      // 模拟拍照
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相机功能模拟：已拍摄照片')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => capturePhoto(context),
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
}
