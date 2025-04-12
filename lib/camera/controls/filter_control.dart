import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/camera_service.dart';
import '../state/camera_state_manager.dart';

// 定义滤镜类型枚举
enum FilterType {
  none,
  natural,
  vivid,
  cold,
  warm,
  blackAndWhite,
  toggle, // 特殊值，用于切换滤镜选择器
}

/// 滤镜控制类
class FilterControl extends StatelessWidget {
  const FilterControl({Key? key}) : super(key: key);

  // 设置滤镜
  Future<void> setFilter(FilterType filter) async {
    final cameraState = CameraStateManager.instance;

    // 如果是切换滤镜选择器的请求
    if (filter == FilterType.toggle) {
      cameraState.showFilterSelector = !cameraState.showFilterSelector;
      return;
    }

    // 更新UI状态
    cameraState.currentFilter = filter;

    // 原本的NativeCameraController.setFilter()相关代码被移除
    debugPrint('滤镜设置功能尚未实现');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => setFilter(FilterType.toggle),
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/camera_fliter.svg',
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

/// 滤镜选择器
class FilterSelector extends StatelessWidget {
  const FilterSelector({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final cameraState = CameraStateManager.instance;

    // 滤镜选项
    final List<Map<String, dynamic>> filters = [
      {'type': FilterType.none, 'name': '无'},
      {'type': FilterType.natural, 'name': '自然'},
      {'type': FilterType.vivid, 'name': '鲜艳'},
      {'type': FilterType.cold, 'name': '冷色'},
      {'type': FilterType.warm, 'name': '暖色'},
      {'type': FilterType.blackAndWhite, 'name': '黑白'},
    ];

    return Container(
      height: 120,
      color: Colors.black54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          final bool isSelected = cameraState.currentFilter == filter['type'];
          final filterControl = FilterControl();

          return GestureDetector(
            onTap: () {
              filterControl.setFilter(filter['type'] as FilterType);
            },
            child: Container(
              width: 80,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isSelected ? Colors.yellow : Colors.transparent,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(4),
                    ),
                    // 这里可以添加预览图，目前使用占位符
                  ),
                  const SizedBox(height: 8),
                  Text(
                    filter['name'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.yellow : Colors.white,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
