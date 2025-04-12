import 'package:flutter/material.dart';
import '../state/camera_state_manager.dart';

/// 画面比例控制组件
class AspectRatioControl extends StatelessWidget {
  const AspectRatioControl({Key? key}) : super(key: key);

  // 切换拍摄比例
  Future<void> toggleAspectRatio() async {
    final cameraState = CameraStateManager.instance;

    // 获取当前比例并计算下一个比例
    final ratios = ['4:3', '1:1', '16:9'];
    final currentIndex = ratios.indexOf(cameraState.currentAspectRatio);
    final nextIndex = (currentIndex + 1) % ratios.length;
    final nextRatio = ratios[nextIndex];

    // 使用CameraStateManager的方法设置拍摄比例
    cameraState.setAspectRatio(nextRatio);

    debugPrint('拍摄比例已设置为: $nextRatio');
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
