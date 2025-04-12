import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';
import '../services/camera_service.dart';

/// 闪光灯控制组件
class FlashControl extends StatelessWidget {
  const FlashControl({Key? key}) : super(key: key);

  // 切换闪光灯
  Future<void> toggleFlash() async {
    final cameraState = CameraStateManager.instance;

    // 更新UI状态
    cameraState.toggleFlash();

    // TODO: 调用原生相机控制闪光灯
    debugPrint('闪光灯切换功能尚未实现');
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;
    final isFlashOn = cameraState.isFlashOn;

    return GestureDetector(
      onTap: toggleFlash,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            isFlashOn
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
      ),
    );
  }
}
