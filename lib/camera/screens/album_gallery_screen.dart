import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'image_preview_screen.dart';

/// 相册浏览页面
class AlbumGalleryScreen extends StatelessWidget {
  final List<AssetEntity> photos;

  const AlbumGalleryScreen({
    Key? key,
    required this.photos,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('好好拍相册', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(2),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 2,
          crossAxisSpacing: 2,
        ),
        itemCount: photos.length,
        itemBuilder: (context, index) {
          final photo = photos[index];
          return GestureDetector(
            onTap: () => _showPhoto(context, photo),
            child: _buildPhotoThumbnail(photo),
          );
        },
      ),
    );
  }

  // 构建照片缩略图
  Widget _buildPhotoThumbnail(AssetEntity photo) {
    return FutureBuilder<Uint8List?>(
      future: photo.thumbnailData,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done &&
            snapshot.data != null) {
          return Image.memory(
            snapshot.data!,
            fit: BoxFit.cover,
          );
        } else {
          return Container(
            color: Colors.grey[800],
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
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

  // 显示照片详情
  Future<void> _showPhoto(BuildContext context, AssetEntity photo) async {
    try {
      // 获取原始照片文件路径
      final file = await photo.file;
      if (file != null && context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ImagePreviewScreen(
              imagePath: file.path,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('打开照片出错: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('无法打开照片: $e')),
        );
      }
    }
  }
}
