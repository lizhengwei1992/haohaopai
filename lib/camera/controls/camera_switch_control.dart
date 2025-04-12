import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';
import '../services/camera_service.dart';

/// 相机切换控制组件
class CameraSwitchControl extends StatelessWidget {
  const CameraSwitchControl({Key? key}) : super(key: key);

  // 切换前后摄像头
  Future<void> switchCamera() async {
    final cameraState = CameraStateManager.instance;
    final cameraService = CameraService.instance;

    // 更新UI状态，显示切换中
    cameraState.isCameraChanging = true;

    try {
      // 获取全局控制器
      final nativeCameraController = cameraService.getGlobalCameraController();
      if (nativeCameraController != null) {
        // 获取当前是否为前置摄像头
        bool isFront;
        try {
          isFront = await nativeCameraController.isFrontCamera();
          debugPrint('当前是否前置相机: $isFront');
        } catch (e) {
          // 如果调用失败，假设当前不是前置
          debugPrint('检查相机方向失败: $e，假设当前不是前置相机');
          isFront = false;
        }

        // 切换到相反的摄像头
        final success =
            await nativeCameraController.switchCamera(toFront: !isFront);
        debugPrint('切换相机结果: $success');
      }
    } catch (e) {
      debugPrint('切换相机出错: $e');
    } finally {
      // 切换完成，更新UI状态
      cameraState.isCameraChanging = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: switchCamera,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
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
      ),
    );
  }
}
