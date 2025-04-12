import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';

/// 曝光控制组件
class ExposureControl extends StatelessWidget {
  const ExposureControl({Key? key}) : super(key: key);

  // 调整曝光
  void adjustExposure() {
    // 获取状态管理器
    final cameraState = CameraStateManager.instance;

    // 创建一个曝光调整对话框
    showExposureAdjustmentDialog(cameraState);
  }

  // 显示曝光调整对话框
  void showExposureAdjustmentDialog(CameraStateManager cameraState) {
    // 这里我们可以创建一个对话框，让用户调整曝光值
    // 目前只是打印日志，实际应用中可以实现UI交互
    debugPrint('当前曝光值: ${cameraState.currentExposureValue}');
    debugPrint(
        '曝光范围: ${cameraState.minExposureValue} 到 ${cameraState.maxExposureValue}');

    // 作为演示，我们将曝光值设置为0（默认值）
    cameraState.setExposure(0.0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: adjustExposure,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/exposure.svg',
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
