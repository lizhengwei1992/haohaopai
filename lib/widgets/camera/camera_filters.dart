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

/// 滤镜预览缩略图组件
class FilterPreviewThumbnail extends StatelessWidget {
  final Widget? cameraPreviewWidget;
  final FilterType filterType;

  const FilterPreviewThumbnail({
    Key? key,
    this.cameraPreviewWidget,
    required this.filterType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 创建一个基本容器（占位符）
    Widget container = Container(
      decoration: BoxDecoration(
        color: Colors.grey[850],
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Center(
        child: Icon(
          Icons.camera_alt,
          color: Colors.white70,
          size: 18,
        ),
      ),
    );

    // 如果有相机预览画面，则直接显示
    if (cameraPreviewWidget != null) {
      container = cameraPreviewWidget!;
    }

    // 应用滤镜效果
    return ColorFiltered(
      colorFilter: CameraFilters.getColorFilter(filterType),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: container,
      ),
    );
  }
}

/// 滤镜选择器组件
class FilterSelector extends StatefulWidget {
  final FilterType currentFilter;
  final Function(FilterType) onFilterChanged;
  final Widget? cameraPreviewWidget; // 添加相机预览画面参数

  const FilterSelector({
    Key? key,
    required this.currentFilter,
    required this.onFilterChanged,
    this.cameraPreviewWidget, // 相机预览画面
  }) : super(key: key);

  @override
  State<FilterSelector> createState() => _FilterSelectorState();
}

class _FilterSelectorState extends State<FilterSelector> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();

    // 延迟滚动到当前选中的滤镜位置
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedFilter();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // 滚动到当前选择的滤镜位置
  void _scrollToSelectedFilter() {
    if (!mounted) return;

    final int currentIndex = FilterType.values.indexOf(widget.currentFilter);
    final double itemWidth = 64.0; // 每个滤镜项的宽度(包含边距)

    // 计算滚动位置，使选中项居中
    final screenWidth = MediaQuery.of(context).size.width;
    final double scrollOffset =
        (currentIndex * itemWidth) - (screenWidth / 2) + (itemWidth / 2);

    // 确保滚动位置在有效范围内
    final double maxScroll = _scrollController.position.maxScrollExtent;
    final double targetOffset = scrollOffset.clamp(0.0, maxScroll);

    // 带动画滚动到目标位置
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // 阻止点击事件传递到下层
      behavior: HitTestBehavior.opaque,
      // 空的onTap回调，确保点击事件被消费
      onTap: () {},
      child: Container(
        height: 65, // 更紧凑的高度
        color: Colors.black.withOpacity(0.5),
        child: ListView.builder(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          itemCount: FilterType.values.length,
          itemBuilder: (context, index) {
            final filterType = FilterType.values[index];
            final isSelected = filterType == widget.currentFilter;

            return GestureDetector(
              onTap: () => widget.onFilterChanged(filterType),
              child: Container(
                width: 58, // 略微减小宽度
                margin: const EdgeInsets.symmetric(
                    horizontal: 3, vertical: 6), // 减小边距
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
                      flex: 3, // 设置比例为3
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: FilterPreviewThumbnail(
                          cameraPreviewWidget: widget.cameraPreviewWidget,
                          filterType: filterType,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 2, // 设置比例为2，文字部分的比例更高
                      child: Center(
                        child: Text(
                          CameraFilters.getFilterName(filterType),
                          style: TextStyle(
                            color: isSelected ? Colors.yellow : Colors.white,
                            fontSize: 10,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
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
