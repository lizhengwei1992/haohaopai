import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/album_service.dart';
import '../screens/album_gallery_screen.dart';

/// 相册操作组件
class AlbumAction extends StatefulWidget {
  const AlbumAction({Key? key}) : super(key: key);

  @override
  State<AlbumAction> createState() => _AlbumActionState();
}

class _AlbumActionState extends State<AlbumAction> {
  // 相册服务
  final AlbumService _albumService = AlbumService();

  // 最新照片
  AssetEntity? _latestPhoto;

  // 是否正在加载
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLatestPhoto();
  }

  // 加载最新照片
  Future<void> _loadLatestPhoto() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final latestPhoto = await _albumService.getLatestPhoto();

      if (mounted) {
        setState(() {
          _latestPhoto = latestPhoto;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('加载最新照片失败: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 打开相册
  void openAlbum(BuildContext context) async {
    // 如果相册中有照片，打开相册浏览界面
    if (_latestPhoto != null) {
      final photos = await _albumService.getAllPhotos();
      if (context.mounted && photos.isNotEmpty) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlbumGalleryScreen(photos: photos),
          ),
        ).then((_) => _loadLatestPhoto()); // 返回时刷新
      }
    } else {
      // 如果没有照片，显示提示
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('"好好拍"相册中还没有照片')),
        );
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
    return FutureBuilder<Uint8List?>(
      future:
          _latestPhoto!.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.hasData &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
            width: 56,
            height: 56,
          );
        } else {
          return Center(
            child: SvgPicture.asset(
              'assets/icons/photo_album.svg',
              width: 45,
              height: 45,
            ),
          );
        }
      },
    );
  }
}
