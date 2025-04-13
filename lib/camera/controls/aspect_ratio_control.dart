import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import '../state/camera_state_manager.dart';

/// 画面比例控制组件
class AspectRatioControl extends StatefulWidget {
  const AspectRatioControl({Key? key}) : super(key: key);

  @override
  State<AspectRatioControl> createState() => _AspectRatioControlState();
}

class _AspectRatioControlState extends State<AspectRatioControl> {
  // 可用的拍摄比例选项
  final List<String> _aspectRatioOptions = ['4:3', '1:1', '16:9'];

  // 设置拍摄比例
  void _setAspectRatio(String ratio) {
    final cameraState = CameraStateManager.instance;

    // 设置新的比例
    cameraState.setAspectRatio(ratio);

    // 关闭展开面板
    cameraState.isAspectRatioControlExpanded = false;

    debugPrint('拍摄比例已设置为: $ratio');
  }

  // 切换展开面板状态
  void _toggleExpanded() {
    final cameraState = CameraStateManager.instance;

    // 切换展开状态
    cameraState.isAspectRatioControlExpanded =
        !cameraState.isAspectRatioControlExpanded;

    // 如果开启了面板，监听屏幕点击事件以便关闭面板
    if (cameraState.isAspectRatioControlExpanded) {
      // 使用Future.delayed以确保展开面板已经显示出来
      Future.delayed(Duration.zero, () {
        // 监听全局点击，直到下一个帧渲染前
        GestureBinding.instance.pointerRouter
            .addGlobalRoute((PointerEvent event) {
          // 如果是点击事件（抬起手指时），关闭面板
          if (event is PointerUpEvent) {
            // 移除监听器，避免重复触发
            GestureBinding.instance.pointerRouter
                .removeGlobalRoute((PointerEvent event) {});

            // 确保面板仍然展开时才关闭
            if (cameraState.isAspectRatioControlExpanded) {
              // 使用Future.microtask确保在UI渲染后执行
              Future.microtask(() {
                cameraState.isAspectRatioControlExpanded = false;
              });
            }
          }
        });
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    return AnimatedBuilder(
      animation: cameraState,
      builder: (context, child) {
        return cameraState.isAspectRatioControlExpanded
            ? _buildExpandedPanel(context, cameraState.currentAspectRatio)
            : _buildAspectRatioButton(cameraState.currentAspectRatio);
      },
    );
  }

  // 构建比例按钮（未展开状态）
  Widget _buildAspectRatioButton(String currentRatio) {
    return GestureDetector(
      onTap: _toggleExpanded,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: Text(
            currentRatio,
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

  // 构建展开的比例选择面板
  Widget _buildExpandedPanel(BuildContext context, String currentRatio) {
    return Center(
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: 45,
        decoration: BoxDecoration(
          color: const Color.fromRGBO(120, 120, 120, 0.35),
          borderRadius: BorderRadius.circular(22.5),
        ),
        child: Row(
          children: [
            // 左侧当前选中项，黄色文本
            Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: Center(
                child: Text(
                  currentRatio,
                  style: const TextStyle(
                    color: Colors.yellow,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // 分隔线
            Container(
              width: 1,
              height: 30,
              color: Colors.white.withOpacity(0.3),
            ),

            // 右侧所有选项
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _aspectRatioOptions.map((ratio) {
                  final bool isSelected = ratio == currentRatio;

                  return GestureDetector(
                    onTap: () {
                      debugPrint('点击了比例选项: $ratio');
                      _setAspectRatio(ratio);
                    },
                    child: Container(
                      width: 45,
                      height: 45,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(22.5),
                      ),
                      child: Center(
                        child: Text(
                          ratio,
                          style: TextStyle(
                            color: isSelected ? Colors.yellow : Colors.white,
                            fontSize: 16,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
