import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';

/// 相机切换控制组件
class CameraSwitchControl extends StatefulWidget {
  const CameraSwitchControl({Key? key}) : super(key: key);

  @override
  State<CameraSwitchControl> createState() => _CameraSwitchControlState();
}

class _CameraSwitchControlState extends State<CameraSwitchControl> {
  // 监听相机状态
  late final CameraStateManager _cameraState;
  bool _isProcessing = false;

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
      setState(() {
        _isProcessing = _cameraState.isProcessingCameraChange;
      });
    }
  }

  // 切换前后摄像头
  Future<void> switchCamera() async {
    if (_isProcessing) {
      debugPrint('摄像头切换正在进行中，忽略本次点击');
      return;
    }

    debugPrint('触发摄像头切换');
    await _cameraState.switchCamera();
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
        child: _isProcessing
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              )
            : Center(
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
