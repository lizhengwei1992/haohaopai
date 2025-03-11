import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/camera_provider.dart';
import 'dart:io';

class CameraControls extends StatefulWidget {
  final VoidCallback onTeachPress;
  final VoidCallback onCapturePress;
  final VoidCallback onGalleryPress;
  final VoidCallback onSwitchCameraPress;
  final bool showingTips;
  final Function(String) onAspectRatioChange;
  final Function(double) onExposureChange;
  final Function(String) onFilterChange;

  const CameraControls({
    super.key,
    required this.onTeachPress,
    required this.onCapturePress,
    required this.onGalleryPress,
    required this.onSwitchCameraPress,
    this.showingTips = false,
    required this.onAspectRatioChange,
    required this.onExposureChange,
    required this.onFilterChange,
  });

  @override
  State<CameraControls> createState() => CameraControlsState();
}

class CameraControlsState extends State<CameraControls> {
  String _currentAspectRatio = '4:3';
  double _currentExposure = 0.0;
  String _currentFilter = '无';

  // 控制面板展开状态
  String? _expandedControl;

  // 拍摄比例选项
  final List<String> _aspectRatioOptions = ['4:3', '16:9', '1:1'];

  // 滤镜选项
  final List<String> _filters = ['无', '自然', '鲜艳', '冷色', '暖色', '黑白'];

  // 公共方法：关闭展开面板
  void closeExpandedPanel() {
    if (_expandedControl != null) {
      setState(() {
        _expandedControl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      // 移除SafeArea，使用Padding代替，允许按钮下移
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end, // 确保内容靠近底部
        mainAxisSize: MainAxisSize.min,
        children: [
          // 控制按钮行 - 包含展开的控制面板
          Padding(
            padding: const EdgeInsets.only(bottom: 30.0), // 调整底部间距
            child: _expandedControl != null
                ? _buildExpandedRow() // 展开状态显示扩展行
                : _buildControlButtonsRow(), // 正常状态显示三个按钮
          ),

          // 拍摄按钮行
          Padding(
            padding: const EdgeInsets.only(bottom: 15.0), // 保持底部间距
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 左侧预览相册按钮
                Consumer<CameraProvider>(
                  builder: (context, provider, child) {
                    final hasRecentPhotos = provider.recentPhotos.isNotEmpty;

                    return GestureDetector(
                      onTap: widget.onGalleryPress,
                      child: Container(
                        width: 40,
                        height: 40,
                        margin: const EdgeInsets.only(right: 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.5), width: 1),
                        ),
                        child: hasRecentPhotos
                            ? ClipOval(
                                child: Image.file(
                                  File(provider.recentPhotos.first.path),
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      Icons.photo_library,
                                      color: Colors.white,
                                      size: 20,
                                    );
                                  },
                                ),
                              )
                            : const Icon(
                                Icons.photo_library,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    );
                  },
                ),

                // 中间拍摄按钮
                _buildCaptureButton(),

                // 右侧切换相机按钮
                GestureDetector(
                  onTap: widget.onSwitchCameraPress,
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.only(left: 30),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.5), width: 1),
                    ),
                    child: const Icon(
                      Icons.flip_camera_ios_outlined,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 构建正常状态下的三个控制按钮行
  Widget _buildControlButtonsRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // 拍摄比例
        _buildControlButton(
          label: _currentAspectRatio,
          isSelected: false,
          onTap: () => _toggleControlPanel('aspectRatio'),
        ),

        // 曝光选择
        _buildControlButton(
          icon: Icons.brightness_6_outlined,
          isSelected: false,
          onTap: () => _toggleControlPanel('exposure'),
        ),

        // 滤镜选择
        _buildControlButton(
          icon: Icons.filter_b_and_w,
          isSelected: false,
          onTap: () => _toggleControlPanel('filter'),
        ),
      ],
    );
  }

  // 构建展开状态下的行
  Widget _buildExpandedRow() {
    switch (_expandedControl) {
      case 'aspectRatio':
        return _buildAspectRatioRow();
      case 'exposure':
        return _buildExposureRow();
      case 'filter':
        return _buildFilterRow();
      default:
        return _buildControlButtonsRow();
    }
  }

  // 构建拍摄比例展开行
  Widget _buildAspectRatioRow() {
    return Container(
      height: 50, // 保持与原始按钮行相同的高度
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25), // 圆形边角
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // 居中显示选项
        children: [
          // 拍摄比例选项
          ...List.generate(_aspectRatioOptions.length, (index) {
            final ratio = _aspectRatioOptions[index];
            final isSelected = _currentAspectRatio == ratio;

            return GestureDetector(
              onTap: () {
                setState(() {
                  _currentAspectRatio = ratio;
                  _expandedControl = null; // 选择后收起面板
                });
                widget.onAspectRatioChange(ratio);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                margin: const EdgeInsets.symmetric(horizontal: 5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Text(
                  ratio,
                  style: TextStyle(
                    color: isSelected ? Colors.black : Colors.white,
                    fontWeight:
                        isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // 构建曝光控制展开行
  Widget _buildExposureRow() {
    // 计算当前曝光值在范围内的位置（0-1之间）
    final normalizedValue = (_currentExposure + 2.0) / 4.0; // 从-2.0到2.0映射到0到1

    return Container(
      height: 50, // 保持与原始按钮行相同的高度
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25), // 圆形边角
      ),
      child: Row(
        children: [
          // 曝光控制条
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // 背景线
                Container(
                  height: 2,
                  color: Colors.white.withOpacity(0.3),
                ),

                // 左侧进度条
                if (_currentExposure < 0)
                  Positioned(
                    left: MediaQuery.of(context).size.width *
                        0.5 *
                        normalizedValue,
                    right: MediaQuery.of(context).size.width * 0.5,
                    child: Container(
                      height: 2,
                      color: Colors.yellow,
                    ),
                  ),

                // 右侧进度条
                if (_currentExposure > 0)
                  Positioned(
                    left: MediaQuery.of(context).size.width * 0.5,
                    right: MediaQuery.of(context).size.width *
                        0.5 *
                        (1 - normalizedValue),
                    child: Container(
                      height: 2,
                      color: Colors.yellow,
                    ),
                  ),

                // 中心点
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.yellow,
                  ),
                ),

                // 滑块
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2.0,
                    activeTrackColor: Colors.transparent,
                    inactiveTrackColor: Colors.transparent,
                    thumbColor: Colors.yellow,
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 8.0),
                    overlayColor: Colors.yellow.withOpacity(0.2),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 16.0),
                  ),
                  child: Slider(
                    value: normalizedValue,
                    onChanged: (value) {
                      // 将0-1的值转换回-2.0到2.0的曝光值
                      final newExposure = (value * 4.0) - 2.0;
                      setState(() {
                        _currentExposure = newExposure;
                      });
                      // 调用回调函数更新相机曝光
                      widget.onExposureChange(newExposure);
                    },
                    min: 0.0,
                    max: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // 显示当前曝光值
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              _currentExposure.toStringAsFixed(1),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 构建滤镜控制展开行
  Widget _buildFilterRow() {
    return Container(
      height: 50, // 保持与原始按钮行相同的高度
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.symmetric(horizontal: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(25), // 圆形边角
      ),
      child: Row(
        children: [
          // 滤镜选项
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _filters.length,
              itemBuilder: (context, index) {
                final filter = _filters[index];
                final isSelected = filter == _currentFilter;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _currentFilter = filter;
                      _expandedControl = null; // 选择后收起面板
                    });
                    widget.onFilterChange(filter);
                  },
                  child: Container(
                    width: 40,
                    height: 40,
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? Colors.white
                          : Colors.grey.withOpacity(0.3),
                      border: isSelected
                          ? Border.all(color: Colors.yellow, width: 2)
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        filter,
                        style: TextStyle(
                          color: isSelected ? Colors.black : Colors.white,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.normal,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // 切换控制面板的展开/收起状态
  void _toggleControlPanel(String? controlName) {
    setState(() {
      _expandedControl = controlName;
    });
  }

  Widget _buildControlButton({
    IconData? icon,
    String? label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, // 缩小按钮尺寸
        height: 40, // 缩小按钮尺寸
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.white.withOpacity(0.2)
              : Colors.black.withOpacity(0.7),
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.white.withOpacity(0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Center(
          child: icon != null
              ? Icon(
                  icon,
                  color: Colors.white,
                  size: 18, // 缩小图标尺寸
                )
              : Text(
                  label ?? '',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10, // 缩小文字尺寸
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: widget.showingTips ? widget.onCapturePress : widget.onTeachPress,
      child: Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Center(
          child: Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
