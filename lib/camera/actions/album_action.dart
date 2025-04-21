import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/album_service.dart';
import '../screens/album_screen.dart';
import '../screens/photo_view.dart';

// 全局相册刷新器，提供一个可以从外部调用的刷新方法
class AlbumRefresher {
  static final AlbumRefresher _instance = AlbumRefresher._internal();
  factory AlbumRefresher() => _instance;
  AlbumRefresher._internal();

  Function? refreshCallback;

  void refresh() {
    if (refreshCallback != null) {
      refreshCallback!();
    }
  }
}

/// 相册操作组件
class AlbumAction extends StatefulWidget {
  const AlbumAction({Key? key}) : super(key: key);

  @override
  State<AlbumAction> createState() => _AlbumActionState();
}

class _AlbumActionState extends State<AlbumAction> with WidgetsBindingObserver {
  // 相册服务
  final AlbumService _albumService = AlbumService();

  // 最新照片
  AssetEntity? _latestPhoto;

  // 是否正在加载
  bool _isLoading = true;

  // 缩略图缓存
  Uint8List? _thumbnailCache;

  // 上次更新时间
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 添加应用生命周期观察者，用于处理应用从后台返回前台时刷新相册
    WidgetsBinding.instance.addObserver(this);

    // 注册刷新回调
    AlbumRefresher().refreshCallback = _loadLatestPhoto;

    _loadLatestPhoto();
  }

  @override
  void dispose() {
    // 移除观察者
    WidgetsBinding.instance.removeObserver(this);

    // 移除刷新回调
    if (AlbumRefresher().refreshCallback == _loadLatestPhoto) {
      AlbumRefresher().refreshCallback = null;
    }

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 当应用恢复到前台时，检查并刷新相册
    if (state == AppLifecycleState.resumed) {
      // 检查距离上次更新是否已经过去了至少2秒
      final now = DateTime.now();
      if (now.difference(_lastUpdateTime).inSeconds > 2) {
        _loadLatestPhoto();
      }
    }
  }

  // 加载最新照片
  Future<void> _loadLatestPhoto() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 确保相册已初始化
      await _albumService.initAlbum();

      // 获取最新照片
      final latestPhoto = await _albumService.getLatestPhoto();
      debugPrint('加载最新照片: ${latestPhoto != null ? "成功" : "无照片"}');

      if (mounted) {
        if (latestPhoto != null) {
          // 尝试预加载缩略图，提高用户体验
          try {
            _thumbnailCache = await latestPhoto.thumbnailDataWithSize(
              const ThumbnailSize(200, 200),
            );
            debugPrint('缩略图加载成功: ${_thumbnailCache?.length ?? 0} 字节');
          } catch (e) {
            debugPrint('缩略图加载失败: $e');
            _thumbnailCache = null;
          }
        }

        setState(() {
          _latestPhoto = latestPhoto;
          _isLoading = false;
          _lastUpdateTime = DateTime.now();
        });
      }
    } catch (e) {
      debugPrint('加载最新照片失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _lastUpdateTime = DateTime.now();
        });
      }
    }
  }

  // 打开相册
  void openAlbum(BuildContext context) async {
    if (_isLoading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('相册加载中，请稍候...')),
      );
      return;
    }

    // 如果相册中有照片，打开照片预览
    if (_latestPhoto != null) {
      try {
        // 获取所有照片作为滑动浏览的数据源
        final photos = await _albumService.getAllPhotos();

        if (context.mounted && photos.isNotEmpty) {
          // 获取第一张照片(最新照片)的文件路径
          final file = await _latestPhoto!.file;
          if (file != null) {
            // 直接导航到照片查看页面
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => PhotoViewScreen(
                  imagePath: file.path,
                  allPhotos: photos,
                  initialIndex: 0, // 默认显示最新的照片
                  onDelete: () async {
                    try {
                      // 删除照片
                      final result = await PhotoManager.editor
                          .deleteWithIds([_latestPhoto!.id]);
                      if (result.isNotEmpty && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('照片已删除')),
                        );
                        // 刷新缓存
                        _thumbnailCache = null;
                        _loadLatestPhoto();
                      }
                    } catch (e) {
                      debugPrint('删除照片失败: $e');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('删除照片失败: $e')),
                        );
                      }
                    }
                  },
                  onShare: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('分享功能即将上线')),
                    );
                  },
                ),
              ),
            ).then((_) => _loadLatestPhoto()); // 返回时刷新
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('相册加载失败，请重试')),
          );
        }
      } catch (e) {
        debugPrint('打开相册失败: $e');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('无法打开相册: $e')),
          );
        }
      }
    } else {
      // 如果没有照片，显示提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('"好好拍"相册中还没有照片')),
        );

        // 尝试再次加载，以防有新照片
        _loadLatestPhoto();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openAlbum(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA0A9FC),
            width: 1.5,
          ),
        ),
        child: _isLoading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFA0A9FC),
                  ),
                ),
              )
            : _latestPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _buildThumbnail(),
                  )
                : Center(
                    child: SvgPicture.asset(
                      'assets/icons/photo_album.svg',
                      width: 45,
                      height: 45,
                    ),
                  ),
      ),
    );
  }

  // 构建缩略图
  Widget _buildThumbnail() {
    // 如果已经有缓存的缩略图，直接使用
    if (_thumbnailCache != null) {
      return Image.memory(
        _thumbnailCache!,
        fit: BoxFit.cover,
        width: 56,
        height: 56,
        errorBuilder: (context, error, stackTrace) {
          debugPrint('显示缓存缩略图出错: $error');
          // 如果缓存图片显示出错，尝试重新加载
          return _buildThumbnailLoader();
        },
      );
    }

    // 否则重新加载
    return _buildThumbnailLoader();
  }

  // 构建缩略图加载器
  Widget _buildThumbnailLoader() {
    return FutureBuilder<Uint8List?>(
      future:
          _latestPhoto!.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          // 更新缓存
          _thumbnailCache = snapshot.data;
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 56,
            height: 56,
          );
        } else if (snapshot.hasError) {
          debugPrint('缩略图加载错误: ${snapshot.error}');
          return Center(
            child: SvgPicture.asset(
              'assets/icons/photo_album.svg',
              width: 45,
              height: 45,
            ),
          );
        } else {
          return Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFFA0A9FC),
              ),
            ),
          );
        }
      },
    );
  }

  // 手动刷新相册
  void refreshAlbum() {
    _loadLatestPhoto();
  }
}
