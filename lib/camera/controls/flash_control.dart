import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';

/// 闪光灯控制组件
class FlashControl extends StatefulWidget {
  const FlashControl({Key? key}) : super(key: key);

  @override
  State<FlashControl> createState() => _FlashControlState();
}

class _FlashControlState extends State<FlashControl> {
  // 监听相机状态
  late final CameraStateManager _cameraState;

  @override
  void initState() {
    super.initState();
    _cameraState = CameraStateManager.instance;
    // 添加监听器
    _cameraState.addListener(_onCameraStateChanged);
  }

  @override
  void dispose() {
    // 移除监听器
    _cameraState.removeListener(_onCameraStateChanged);
    super.dispose();
  }

  // 当相机状态变化时刷新UI
  void _onCameraStateChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  // 切换闪光灯
  Future<void> toggleFlash() async {
    await _cameraState.toggleFlash();
    debugPrint('触发闪光灯切换: ${_cameraState.flashMode}');
  }

  @override
  Widget build(BuildContext context) {
    final flashMode = _cameraState.flashMode;

    debugPrint('构建闪光灯控制: $flashMode');

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
            flashMode == 'auto'
                ? 'assets/icons/camera_flash_auto.svg'
                : 'assets/icons/camera_flash_off.svg',
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
