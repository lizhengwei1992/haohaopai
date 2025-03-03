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
  State<CameraControls> createState() => _CameraControlsState();
}

class _CameraControlsState extends State<CameraControls> {
  String _currentAspectRatio = '4:3';
  double _currentExposure = 0.0;
  String _currentFilter = '无';

  // 拍摄比例选项
  final List<Map<String, dynamic>> _aspectRatioOptions = [
    {'value': '4:3', 'label': '4:3', 'icon': Icons.crop_7_5},
    {'value': '16:9', 'label': '16:9', 'icon': Icons.crop_16_9},
    {'value': '1:1', 'label': '1:1', 'icon': Icons.crop_square},
  ];

  final List<String> _filters = ['无', '自然', '鲜艳', '冷色', '暖色', '黑白'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 控制按钮行 - 只保留三个按钮
            Padding(
              padding: const EdgeInsets.only(bottom: 5.0, top: 10.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 拍摄比例
                  _buildControlButton(
                    icon: _getAspectRatioIcon(),
                    label: _currentAspectRatio,
                    onTap: _showAspectRatioSelector,
                  ),

                  // 曝光选择
                  _buildControlButton(
                    icon: Icons.brightness_6_outlined,
                    label: '曝光',
                    onTap: _showExposureSelector,
                  ),

                  // 滤镜选择
                  _buildControlButton(
                    icon: Icons.filter_b_and_w,
                    label: '滤镜',
                    onTap: _showFilterSelector,
                  ),
                ],
              ),
            ),

            // 拍摄按钮行
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0, top: 5.0),
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
      ),
    );
  }

  // 根据当前拍摄比例获取对应的图标
  IconData _getAspectRatioIcon() {
    switch (_currentAspectRatio) {
      case '16:9':
        return Icons.crop_16_9;
      case '1:1':
        return Icons.crop_square;
      case '4:3':
      default:
        return Icons.crop_7_5;
    }
  }

  Widget _buildControlButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
            ),
          ),
        ],
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

  void _showAspectRatioSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '选择拍摄比例',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 80,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _aspectRatioOptions.length,
                  itemBuilder: (context, index) {
                    final option = _aspectRatioOptions[index];
                    final isSelected = option['value'] == _currentAspectRatio;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _currentAspectRatio = option['value'];
                        });
                        widget.onAspectRatioChange(option['value']);
                        Navigator.pop(context);
                      },
                      child: Container(
                        width: 80,
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              option['icon'],
                              color: isSelected ? Colors.black : Colors.white,
                              size: 30,
                            ),
                            const SizedBox(height: 5),
                            Text(
                              option['label'],
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExposureSelector() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '调整曝光',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        '-2.0',
                        style: TextStyle(color: Colors.white),
                      ),
                      Expanded(
                        child: Slider(
                          value: _currentExposure,
                          min: -2.0,
                          max: 2.0,
                          divisions: 40,
                          activeColor: Colors.white,
                          inactiveColor: Colors.grey,
                          onChanged: (value) {
                            setState(() {
                              _currentExposure = value;
                            });
                          },
                          onChangeEnd: (value) {
                            this.setState(() {
                              _currentExposure = value;
                            });
                            widget.onExposureChange(value);
                            Navigator.pop(context);
                          },
                        ),
                      ),
                      const Text(
                        '+2.0',
                        style: TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showFilterSelector() {
    _showBottomSelector(
      title: '选择滤镜',
      options: _filters,
      currentValue: _currentFilter,
      onSelected: (filter) {
        setState(() {
          _currentFilter = filter;
        });
        widget.onFilterChange(filter);
      },
    );
  }

  void _showBottomSelector({
    required String title,
    required List<String> options,
    required String currentValue,
    required Function(String) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black.withOpacity(0.8),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final isSelected = option == currentValue;

                    return GestureDetector(
                      onTap: () {
                        onSelected(option);
                        Navigator.pop(context);
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Center(
                          child: Text(
                            option,
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
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
      },
    );
  }
}
