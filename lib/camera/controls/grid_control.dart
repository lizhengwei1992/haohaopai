import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../state/camera_state_manager.dart';

/// 网格控制按钮 - 用于控制相机预览的九宫格显示
class GridControl extends StatefulWidget {
  const GridControl({Key? key}) : super(key: key);

  @override
  State<GridControl> createState() => _GridControlState();
}

class _GridControlState extends State<GridControl> {
  bool _isGridActive = false;

  @override
  void initState() {
    super.initState();
    // 初始化时从全局状态获取网格状态
    _isGridActive = CameraStateManager.instance.showGridLines;

    // 添加监听器以响应全局状态变化
    CameraStateManager.instance.addListener(_updateFromGlobalState);
  }

  @override
  void dispose() {
    // 移除监听器
    CameraStateManager.instance.removeListener(_updateFromGlobalState);
    super.dispose();
  }

  // 更新本地状态以反映全局状态
  void _updateFromGlobalState() {
    final newState = CameraStateManager.instance.showGridLines;
    if (_isGridActive != newState) {
      setState(() {
        _isGridActive = newState;
      });
    }
  }

  // 切换网格显示状态
  void _toggleGrid() {
    // 更新全局状态
    CameraStateManager.instance.toggleGridLines();

    // 更新本地状态 (不需要setState，因为会通过监听器更新)
    _isGridActive = CameraStateManager.instance.showGridLines;

    // 打印调试信息
    debugPrint('GridControl: 网格状态切换为 $_isGridActive');
    debugPrint(
        'GridControl: 使用图标 ${_isGridActive ? "grid_on.svg" : "grid_off.svg"}');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleGrid,
      child: Container(
        width: 45,
        height: 45,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            // 根据网格状态显示不同图标
            _isGridActive
                ? 'assets/icons/grid_on.svg'
                : 'assets/icons/grid_off.svg',
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
