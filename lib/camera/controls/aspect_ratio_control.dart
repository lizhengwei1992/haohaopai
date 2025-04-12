import 'package:flutter/material.dart';
import '../state/camera_state_manager.dart';

/// 画面比例控制组件
class AspectRatioControl extends StatelessWidget {
  const AspectRatioControl({Key? key}) : super(key: key);

  // 切换拍摄比例
  Future<void> toggleAspectRatio() async {
    final cameraState = CameraStateManager.instance;

    // 循环切换可用比例
    cameraState.toggleAspectRatio();

    // TODO: 调用原生相机控制宽高比
    debugPrint('拍摄比例设置功能尚未实现');
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    return GestureDetector(
      onTap: toggleAspectRatio,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: Text(
            cameraState.currentAspectRatio,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
