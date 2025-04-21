import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'photo_view.dart';

/// 相册页面
class AlbumScreen extends StatelessWidget {
  final List<AssetEntity> photos;

  const AlbumScreen({
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
            builder: (context) => PhotoViewScreen(
              imagePath: file.path,
              allPhotos: photos,
              initialIndex: photos.indexOf(photo),
              onDelete: () async {
                try {
                  // 删除照片
                  final result =
                      await PhotoManager.editor.deleteWithIds([photo.id]);
                  if (result.isNotEmpty) {
                    // 如果删除成功，显示提示
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('照片已删除')),
                      );
                    }
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
              },
              onShare: () {
                // 这里可以添加分享功能
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('分享功能即将上线')),
                );
              },
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
