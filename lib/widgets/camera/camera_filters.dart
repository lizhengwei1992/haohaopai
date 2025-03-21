import 'package:flutter/material.dart';

/// 相机滤镜类型
enum FilterType {
  none,
  sepia,
  grayscale,
  vintage,
  cold,
  warm,
  dramatic,
  bright,
  dark,
}

/// 相机滤镜管理类
class CameraFilters {
  /// 获取滤镜名称
  static String getFilterName(FilterType type) {
    switch (type) {
      case FilterType.none:
        return '原始';
      case FilterType.sepia:
        return '复古';
      case FilterType.grayscale:
        return '黑白';
      case FilterType.vintage:
        return '怀旧';
      case FilterType.cold:
        return '冷色';
      case FilterType.warm:
        return '暖色';
      case FilterType.dramatic:
        return '戏剧';
      case FilterType.bright:
        return '明亮';
      case FilterType.dark:
        return '暗调';
    }
  }

  /// 获取滤镜的ColorFilter
  static ColorFilter getColorFilter(FilterType type) {
    switch (type) {
      case FilterType.none:
        return const ColorFilter.mode(Colors.transparent, BlendMode.srcOver);
      case FilterType.sepia:
        return const ColorFilter.matrix([
          0.393,
          0.769,
          0.189,
          0,
          0,
          0.349,
          0.686,
          0.168,
          0,
          0,
          0.272,
          0.534,
          0.131,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.grayscale:
        return const ColorFilter.matrix([
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.vintage:
        return const ColorFilter.matrix([
          0.9,
          0.5,
          0.1,
          0,
          0,
          0.3,
          0.8,
          0.1,
          0,
          0,
          0.2,
          0.3,
          0.5,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.cold:
        return const ColorFilter.matrix([
          1.0,
          0.0,
          0.0,
          0,
          0,
          0.0,
          1.0,
          0.0,
          0,
          0,
          0.0,
          0.2,
          1.2,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.warm:
        return const ColorFilter.matrix([
          1.1,
          0.0,
          0.0,
          0,
          10,
          0.0,
          1.0,
          0.0,
          0,
          0,
          0.0,
          0.0,
          0.8,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.dramatic:
        return const ColorFilter.matrix([
          0.9,
          0.2,
          0.0,
          0,
          0,
          0.0,
          0.9,
          0.2,
          0,
          0,
          0.0,
          0.0,
          0.9,
          0,
          0,
          0,
          0,
          0,
          1.2,
          -20,
        ]);
      case FilterType.bright:
        return const ColorFilter.matrix([
          1.2,
          0.0,
          0.0,
          0,
          15,
          0.0,
          1.2,
          0.0,
          0,
          15,
          0.0,
          0.0,
          1.2,
          0,
          15,
          0,
          0,
          0,
          1,
          0,
        ]);
      case FilterType.dark:
        return const ColorFilter.matrix([
          0.8,
          0.0,
          0.0,
          0,
          -10,
          0.0,
          0.8,
          0.0,
          0,
          -10,
          0.0,
          0.0,
          0.8,
          0,
          -10,
          0,
          0,
          0,
          1,
          0,
        ]);
    }
  }
}

/// 滤镜选择器组件
class FilterSelector extends StatelessWidget {
  final FilterType currentFilter;
  final Function(FilterType) onFilterChanged;

  const FilterSelector({
    Key? key,
    required this.currentFilter,
    required this.onFilterChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 阻止点击事件传递到下层
      behavior: HitTestBehavior.opaque,
      // 空的onTap回调，确保点击事件被消费
      onTap: () {},
      child: Container(
        height: 80,
        color: Colors.black.withOpacity(0.5),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: FilterType.values.length,
          itemBuilder: (context, index) {
            final filterType = FilterType.values[index];
            final isSelected = filterType == currentFilter;

            return GestureDetector(
              onTap: () => onFilterChanged(filterType),
              child: Container(
                width: 60,
                margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
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
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: ColorFiltered(
                          colorFilter: CameraFilters.getColorFilter(filterType),
                          child: Container(
                            color: Colors.grey[800],
                            child: const Center(
                              child: Icon(
                                Icons.camera_alt,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      CameraFilters.getFilterName(filterType),
                      style: TextStyle(
                        color: isSelected ? Colors.yellow : Colors.white,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// 应用滤镜的相机预览组件
class FilteredCameraPreview extends StatelessWidget {
  final Widget child;
  final FilterType filterType;

  const FilteredCameraPreview({
    Key? key,
    required this.child,
    required this.filterType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 如果没有选择滤镜，直接返回原始预览
    if (filterType == FilterType.none) {
      return child;
    }

    // 应用滤镜
    return ColorFiltered(
      colorFilter: CameraFilters.getColorFilter(filterType),
      child: child,
    );
  }
}
