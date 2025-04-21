import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../layout/layout_params.dart';
import 'album_screen.dart';

/// 照片全屏查看页面
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

class _PhotoViewScreenState extends State<PhotoViewScreen> {
  late PageController _pageController;
  late int _currentIndex;
  late List<AssetEntity> _photos;
  bool _isLoading = false;
  final Map<int, File?> _fileCache = {};
  final Map<int, Uint8List?> _thumbnailCache = {};
  bool _showInfo = false;

  // 预览参数
  late CameraLayoutParams _layoutParams;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);

    if (widget.allPhotos != null && widget.allPhotos!.isNotEmpty) {
      _photos = widget.allPhotos!;
      // 预加载文件
      _preloadFiles();
      // 预缓存所有缩略图
      _preloadAllThumbnails();
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
        setState(() {
          _photos = photos;
          _isLoading = false;
        });
        // 预加载文件
        _preloadFiles();
        // 预缓存所有缩略图
        _preloadAllThumbnails();
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载相册照片失败: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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

    // 计算中心位置
    final centerY = _layoutParams.previewCenterY;
    final previewTopY = centerY - (_layoutParams.screenHeight * 0.9) / 2;

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
            // 照片查看区域
            Positioned(
              top: previewTopY,
              left: 0,
              right: 0,
              height: _layoutParams.screenHeight * 0.9,
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                builder: (BuildContext context, int index) {
                  return PhotoViewGalleryPageOptions.customChild(
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
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 2,
                    initialScale: PhotoViewComputedScale.contained,
                  );
                },
                itemCount: _photos.length,
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 20.0,
                    height: 20.0,
                    child: CircularProgressIndicator(
                      value: event == null
                          ? 0
                          : event.cumulativeBytesLoaded /
                              (event.expectedTotalBytes ?? 1),
                      color: Colors.white,
                    ),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                  // 预加载前后的图片
                  _preloadFiles();
                },
              ),
            ),

            // 缩略图预览区域（底部）
            Positioned(
              bottom: 100, // 向上移动20px
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                color: Colors.black.withOpacity(0.5),
                child: _buildThumbnailRow(),
              ),
            ),

            // 底部操作按钮
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
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
                        width: 40,
                        height: 40,
                        child: SvgPicture.asset(
                          'assets/icons/info.svg',
                          width: 20,
                          height: 20,
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
                        width: 40,
                        height: 40,
                        child: SvgPicture.asset(
                          'assets/icons/delete.svg',
                          width: 20,
                          height: 20,
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

  // 构建缩略图横向列表，当前选中的缩略图始终在中间
  Widget _buildThumbnailRow() {
    if (_photos.isEmpty) {
      return const SizedBox.shrink();
    }

    // 计算需要的偏移量，让当前图片总是在中间
    final screenWidth = MediaQuery.of(context).size.width;
    final itemWidth = 45.0; // 缩略图宽度
    final selectedItemWidth = 55.0; // 选中的缩略图宽度
    final spacing = 4.0; // 间距

    // 计算列表视口中心位置
    final centerX = screenWidth / 2;

    // 计算滚动位置，使当前照片的缩略图在中间
    final scrollOffset =
        (_photos.length - 1 - _currentIndex) * (itemWidth + spacing) -
            centerX +
            selectedItemWidth / 2;

    // 使用 IndexedStack 预加载所有缩略图组件
    return Container(
      height: 60,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => true, // 禁止自动滚动
        child: ListView.builder(
          controller: ScrollController(
              initialScrollOffset: scrollOffset > 0 ? scrollOffset : 0),
          scrollDirection: Axis.horizontal,
          reverse: true, // 反向列表，最新的照片在最右边
          itemCount: _photos.length,
          physics: const ClampingScrollPhysics(), // 限制滚动范围
          padding: const EdgeInsets.symmetric(horizontal: 15),
          itemBuilder: (context, index) {
            // 计算真实索引（因为反向列表）
            final photoIndex = index;
            final isSelected = photoIndex == _currentIndex;

            return GestureDetector(
              onTap: () {
                _pageController.animateToPage(
                  photoIndex,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              child: Container(
                width: isSelected ? selectedItemWidth : itemWidth,
                height: isSelected ? 55 : 45,
                margin: EdgeInsets.symmetric(
                  horizontal: spacing,
                  vertical: isSelected ? 0 : 5,
                ),
                decoration: BoxDecoration(
                  border: isSelected
                      ? Border.all(color: const Color(0xFFA0A9FC), width: 2)
                      : null,
                ),
                child: _buildThumbnailImage(photoIndex),
              ),
            );
          },
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

    // 如果没有缓存，则加载
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
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
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
    // 计算中心位置
    final centerY = _layoutParams != null
        ? _layoutParams.previewCenterY
        : MediaQuery.of(context).size.height / 2;
    final previewTopY =
        centerY - (MediaQuery.of(context).size.height * 0.9) / 2;

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
          // 照片查看区域
          Positioned(
            top: previewTopY,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.9,
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

          // 底部操作按钮
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
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
                      width: 40,
                      height: 40,
                      child: SvgPicture.asset(
                        'assets/icons/info.svg',
                        width: 24,
                        height: 24,
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
                      width: 40,
                      height: 40,
                      child: SvgPicture.asset(
                        'assets/icons/delete.svg',
                        width: 24,
                        height: 24,
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
