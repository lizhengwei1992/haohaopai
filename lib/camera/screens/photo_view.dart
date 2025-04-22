import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../layout/layout_params.dart';
import 'album_screen.dart';

/// 照片全屏查看页面 - iOS风格
class PhotoViewScreen extends StatefulWidget {
  final String imagePath;
  final List<AssetEntity>? allPhotos;
  final int initialIndex;
  final Function()? onDelete;
  final Function()? onShare;

  const PhotoViewScreen({
    Key? key,
    required this.imagePath,
    this.allPhotos,
    this.initialIndex = 0,
    this.onDelete,
    this.onShare,
  }) : super(key: key);

  @override
  State<PhotoViewScreen> createState() => _PhotoViewScreenState();
}

class _PhotoViewScreenState extends State<PhotoViewScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;
  late List<AssetEntity> _photos;
  bool _isLoading = false;
  final Map<int, File?> _fileCache = {};
  final Map<int, Uint8List?> _thumbnailCache = {};
  bool _showInfo = false;

  // 预览参数
  late CameraLayoutParams _layoutParams;

  // 缩略图尺寸 - 调整为瘦长形状且更小
  final double _thumbnailHeight = 40.0;
  final double _thumbnailDefaultWidth = 30.0;
  final double _thumbnailSelectedWidth = 35.0;
  final double _thumbnailSpacing = 3.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();

    if (widget.allPhotos != null && widget.allPhotos!.isNotEmpty) {
      _photos = widget.allPhotos!;
      // 预加载文件和缩略图
      _preloadFiles();
      _preloadAllThumbnails();

      // 确保初始显示时，缩略图位置正确
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCurrentThumbnail(animate: false);
      });
    } else {
      _photos = [];
      _loadLatestPhoto();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layoutParams = CameraLayoutParams(context);
  }

  // 预加载文件
  Future<void> _preloadFiles() async {
    // 预加载更多文件以提高滑动性能
    final startIndex = (_currentIndex - 3).clamp(0, _photos.length - 1);
    final endIndex = (_currentIndex + 3).clamp(0, _photos.length - 1);

    for (int i = startIndex; i <= endIndex; i++) {
      _getFileAtIndex(i);
    }
  }

  // 预缓存所有缩略图
  Future<void> _preloadAllThumbnails() async {
    for (int i = 0; i < _photos.length; i++) {
      _getThumbnailAtIndex(i);
    }
  }

  // 获取指定索引的缩略图
  Future<Uint8List?> _getThumbnailAtIndex(int index) async {
    if (_thumbnailCache.containsKey(index) && _thumbnailCache[index] != null) {
      return _thumbnailCache[index];
    }

    if (index >= 0 && index < _photos.length) {
      try {
        final thumbnail = await _photos[index]
            .thumbnailDataWithSize(const ThumbnailSize(200, 200), quality: 100);
        _thumbnailCache[index] = thumbnail;
        return thumbnail;
      } catch (e) {
        debugPrint('获取照片缩略图失败: $e');
        return null;
      }
    }
    return null;
  }

  // 获取特定索引的文件
  Future<File?> _getFileAtIndex(int index) async {
    if (_fileCache.containsKey(index) && _fileCache[index] != null) {
      return _fileCache[index];
    }

    if (index >= 0 && index < _photos.length) {
      try {
        final file = await _photos[index].file;
        _fileCache[index] = file;
        return file;
      } catch (e) {
        debugPrint('获取照片文件失败: $e');
        return null;
      }
    }
    return null;
  }

  // 加载最新照片(如果没有提供照片列表)
  Future<void> _loadLatestPhoto() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 请求权限
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        debugPrint('没有相册访问权限');
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        onlyAll: false,
        type: RequestType.image,
      );

      // 查找"好好拍"相册
      AssetPathEntity? albumEntity;
      for (var album in albums) {
        if (album.name == "好好拍") {
          albumEntity = album;
          break;
        }
      }

      if (albumEntity != null) {
        // 获取相册中的所有照片
        final List<AssetEntity> photos =
            await albumEntity.getAssetListPaged(page: 0, size: 1000);
        if (mounted) {
          setState(() {
            _photos = photos;
            _isLoading = false;
          });
          // 预加载文件和缩略图
          _preloadFiles();
          _preloadAllThumbnails();

          // 确保初始显示时，缩略图位置正确
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentThumbnail(animate: false);
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('加载相册照片失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 滚动缩略图列表到当前选中的图片位置
  void _scrollToCurrentThumbnail({bool animate = true}) {
    if (_photos.isEmpty) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final itemTotalWidth = _thumbnailDefaultWidth + _thumbnailSpacing * 2;

    // 计算目标滚动位置，使当前图片居中
    final targetPosition = _currentIndex * itemTotalWidth -
        (screenWidth - _thumbnailSelectedWidth) / 2 +
        _thumbnailSpacing;

    // 确保不会滚动超出边界
    final maxScrollExtent = _thumbnailScrollController.position.maxScrollExtent;
    final scrollPosition = targetPosition.clamp(0.0, maxScrollExtent);

    if (_thumbnailScrollController.hasClients) {
      if (animate) {
        _thumbnailScrollController.animateTo(
          scrollPosition,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      } else {
        _thumbnailScrollController.jumpTo(scrollPosition);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_photos.isEmpty) {
      // 如果没有照片，只显示单张图片
      return _buildSinglePhotoView();
    }

    // 计算中心位置，使用layout_params中的预览框中心点
    final centerY = _layoutParams.previewCenterY;
    final previewHeight = _layoutParams.screenHeight * 0.9;
    final previewTopY = centerY - previewHeight / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFA0A9FC)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: GestureDetector(
        onVerticalDragEnd: (details) {
          // 下滑手势，显示相册页面
          if (details.primaryVelocity! > 300) {
            _showAlbumScreen();
          }
        },
        child: Stack(
          children: [
            // 主要照片区域 - 以相机预览框中心点为中心
            Positioned(
              top: previewTopY,
              left: 0,
              right: 0,
              height: previewHeight,
              child: PageView.builder(
                controller: _pageController,
                itemCount: _photos.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  // 滚动缩略图到当前位置
                  _scrollToCurrentThumbnail();
                  // 预加载文件
                  _preloadFiles();
                },
                itemBuilder: (context, index) {
                  return Center(
                    child: FutureBuilder<File?>(
                      future: _getFileAtIndex(index),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done &&
                            snapshot.data != null) {
                          return PhotoView(
                            imageProvider: FileImage(snapshot.data!),
                            minScale: PhotoViewComputedScale.contained * 0.8,
                            maxScale: PhotoViewComputedScale.covered * 2,
                            initialScale: PhotoViewComputedScale.contained,
                            heroAttributes: PhotoViewHeroAttributes(
                              tag: 'photo_view_${_photos[index].id}',
                            ),
                            backgroundDecoration:
                                const BoxDecoration(color: Colors.black),
                          );
                        } else {
                          return Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          );
                        }
                      },
                    ),
                  );
                },
              ),
            ),

            // 底部缩略图区域 - 向上移动50px
            Positioned(
              bottom: 100, // 原来是50px，现在改为100px
              left: 0,
              right: 0,
              child: Container(
                height: _thumbnailHeight + 10, // 高度包含上下内边距
                color: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: ListView.builder(
                  controller: _thumbnailScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _photos.length,
                  itemBuilder: (context, index) {
                    // 计算视差效果 - 距离中心点越远，尺寸越小、透明度越低
                    final distance = (index - _currentIndex).abs();
                    final isSelected = index == _currentIndex;
                    final scale = isSelected
                        ? 1.0
                        : (1.0 - distance * 0.15).clamp(0.7, 1.0);
                    final opacity = isSelected
                        ? 1.0
                        : (1.0 - distance * 0.2).clamp(0.5, 1.0);

                    return GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                        );
                      },
                      child: Container(
                        margin:
                            EdgeInsets.symmetric(horizontal: _thumbnailSpacing),
                        decoration: BoxDecoration(
                          border: isSelected
                              ? Border.all(
                                  color: Colors.white.withOpacity(0.8),
                                  width: 1)
                              : null,
                        ),
                        child: Opacity(
                          opacity: opacity,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeOutCubic,
                            width: isSelected
                                ? _thumbnailSelectedWidth
                                : _thumbnailDefaultWidth * scale,
                            height: isSelected
                                ? _thumbnailHeight
                                : _thumbnailHeight * scale,
                            child: _buildThumbnailImage(index),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 底部操作按钮 - 向上移动10px
            Positioned(
              bottom: 30, // 原来是20px，现在改为30px
              left: 0,
              right: 0,
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 30),
                color: Colors.transparent,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右两端对齐
                  children: [
                    // 左侧信息按钮
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _showInfo = !_showInfo;
                        });
                        // 显示空的图片信息
                        if (_showInfo) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('图片信息暂不可用')),
                          );
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        child: SvgPicture.asset(
                          'assets/icons/info.svg',
                          width: 15, // 缩小25%
                          height: 15, // 缩小25%
                        ),
                      ),
                    ),

                    // 右侧删除按钮
                    GestureDetector(
                      onTap: () {
                        if (_photos.length > 1) {
                          _deleteCurrentPhoto();
                        } else {
                          // 如果只有一张照片，使用原有的删除流程
                          _confirmDelete(context);
                        }
                      },
                      child: Container(
                        width: 30,
                        height: 30,
                        child: SvgPicture.asset(
                          'assets/icons/delete.svg',
                          width: 15, // 缩小25%
                          height: 15, // 缩小25%
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 优化的缩略图构建方法
  Widget _buildThumbnailImage(int index) {
    // 使用缓存的缩略图
    if (_thumbnailCache.containsKey(index) && _thumbnailCache[index] != null) {
      return Image.memory(
        _thumbnailCache[index]!,
        fit: BoxFit.cover,
        cacheHeight: 200,
        cacheWidth: 200,
      );
    }

    // 如果没有缓存，则加载并显示加载指示器
    return FutureBuilder<Uint8List?>(
      future: _getThumbnailAtIndex(index),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            cacheHeight: 200,
            cacheWidth: 200,
          );
        } else {
          // 使用渐变色占位符，模仿iOS风格
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.grey[800]!,
                  Colors.grey[600]!,
                ],
              ),
            ),
            child: Center(
              child: SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: Colors.white70,
                ),
              ),
            ),
          );
        }
      },
    );
  }

  // 构建单张照片视图
  Widget _buildSinglePhotoView() {
    // 计算中心位置，使用layout_params中的预览框中心点
    final centerY = _layoutParams.previewCenterY;
    final previewHeight = _layoutParams.screenHeight * 0.9;
    final previewTopY = centerY - previewHeight / 2;

    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFA0A9FC)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          // 照片查看区域 - 以相机预览框中心点为中心
          Positioned(
            top: previewTopY,
            left: 0,
            right: 0,
            height: previewHeight,
            child: PhotoView(
              imageProvider: FileImage(File(widget.imagePath)),
              minScale: PhotoViewComputedScale.contained * 0.8,
              maxScale: PhotoViewComputedScale.covered * 2,
              initialScale: PhotoViewComputedScale.contained,
              errorBuilder: (context, error, stackTrace) {
                return Center(
                  child: Text(
                    '无法加载图片',
                    style: TextStyle(color: Colors.white),
                  ),
                );
              },
              loadingBuilder: (context, event) => Center(
                child: SizedBox(
                  width: 20.0,
                  height: 20.0,
                  child: CircularProgressIndicator(
                    value: event == null
                        ? 0
                        : event.cumulativeBytesLoaded /
                            (event.expectedTotalBytes ?? 1),
                  ),
                ),
              ),
              backgroundDecoration: BoxDecoration(color: Colors.black),
              heroAttributes: PhotoViewHeroAttributes(
                  tag: 'photo_view_${widget.imagePath.hashCode}'),
            ),
          ),

          // 底部操作按钮 - 向上移动10px
          Positioned(
            bottom: 30, // 从20px改为30px
            left: 0,
            right: 0,
            child: Container(
              height: 50,
              padding: const EdgeInsets.symmetric(horizontal: 30),
              color: Colors.transparent,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween, // 左右两端对齐
                children: [
                  // 左侧信息按钮
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _showInfo = !_showInfo;
                      });
                      // 显示空的图片信息
                      if (_showInfo) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('图片信息暂不可用')),
                        );
                      }
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      child: SvgPicture.asset(
                        'assets/icons/info.svg',
                        width: 15, // 缩小25%
                        height: 15, // 缩小25%
                      ),
                    ),
                  ),

                  // 右侧删除按钮
                  GestureDetector(
                    onTap: () {
                      if (widget.onDelete != null) {
                        _confirmDelete(context);
                      }
                    },
                    child: Container(
                      width: 30,
                      height: 30,
                      child: SvgPicture.asset(
                        'assets/icons/delete.svg',
                        width: 15, // 缩小25%
                        height: 15, // 缩小25%
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 删除当前照片并切换到上一张
  Future<void> _deleteCurrentPhoto() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        int previousIndex = _currentIndex;
        final photo = _photos[_currentIndex];

        // 先移动到前一张照片（如果当前是第一张，则移动到下一张）
        if (_currentIndex > 0) {
          previousIndex = _currentIndex - 1;
        } else if (_photos.length > 1) {
          previousIndex = 0; // 仍然是第一张，但会删除当前的第一张
        }

        // 如果不是查看第一张，则先切换到前一张
        if (_currentIndex > 0) {
          _pageController.animateToPage(
            previousIndex,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeInOut,
          );
          await Future.delayed(const Duration(milliseconds: 210));
        }

        // 执行删除
        final result = await PhotoManager.editor.deleteWithIds([photo.id]);

        if (result.isNotEmpty) {
          // 刷新照片列表
          setState(() {
            _photos.removeAt(_currentIndex);

            // 如果删除的是第一张且有多张照片，保持当前索引为0
            // 如果删除的是其他照片，当前索引需要更新为前一张的索引
            if (_currentIndex > 0) {
              _currentIndex = previousIndex;
            }

            // 如果删除后没有照片了，返回
            if (_photos.isEmpty && context.mounted) {
              Navigator.pop(context);
              return;
            }
          });

          // 清除缓存
          _fileCache.clear();
          _thumbnailCache.clear();

          // 重新预加载
          _preloadFiles();
          _preloadAllThumbnails();

          // 滚动缩略图到当前位置
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToCurrentThumbnail(animate: false);
          });
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('删除照片失败')),
            );
          }
        }
      } catch (e) {
        debugPrint('删除照片失败: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除照片失败: $e')),
          );
        }
      }
    }
  }

  // 显示相册页面
  void _showAlbumScreen() {
    if (_photos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相册中没有照片')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumScreen(photos: _photos),
      ),
    );
  }

  // 确认删除对话框（单图模式）
  Future<void> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除照片'),
        content: const Text('确定要删除这张照片吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (result == true && widget.onDelete != null) {
      widget.onDelete!();
      if (context.mounted) {
        Navigator.pop(context); // 关闭照片查看页面
      }
    }
  }
}
