import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/camera_service.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../services/album_service.dart';
import 'album_action.dart';

/// 拍照操作组件
class CaptureAction extends StatelessWidget {
  const CaptureAction({Key? key}) : super(key: key);

  // 拍照
  Future<void> capturePhoto(BuildContext context) async {
    final cameraService = CameraService.instance;
    final albumService = AlbumService();
    final nativeCameraController = cameraService.getGlobalCameraController();

    debugPrint('【Flutter拍照】1. 开始拍照流程');

    if (nativeCameraController != null) {
      try {
        // 使用原生相机拍照 - 增加超时处理
        debugPrint('【Flutter拍照】2. 调用原生相机拍照...');
        Uint8List? imageData;
        try {
          // 添加超时控制
          imageData = await nativeCameraController
              .capturePhoto()
              .timeout(const Duration(seconds: 10), onTimeout: () {
            debugPrint('【Flutter拍照】拍照操作超时（10秒）');
            throw TimeoutException('拍照操作超时');
          });
          debugPrint('【Flutter拍照】3. 原生拍照调用返回');
        } catch (e) {
          debugPrint('【Flutter拍照】拍照调用异常: $e');
          return; // 提前返回，防止继续执行
        }

        debugPrint('【Flutter拍照】4. 检查照片数据...');

        if (imageData != null && imageData.isNotEmpty) {
          debugPrint('【Flutter拍照】5. 拍照成功，获取到照片数据: ${imageData.length} 字节');

          // 保存照片到临时目录
          debugPrint('【Flutter拍照】6. 开始保存到临时目录');
          final tempDir = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          final tempPath = path.join(tempDir.path, 'photo_$timestamp.jpg');
          final tempFile = File(tempPath);
          try {
            await tempFile.writeAsBytes(imageData);
            debugPrint('【Flutter拍照】7. 已保存照片到临时路径: $tempPath');
          } catch (e) {
            debugPrint('【Flutter拍照】保存到临时文件失败: $e');
            return;
          }

          // 保存照片到好好拍相册
          debugPrint('【Flutter拍照】8. 开始保存照片到好好拍相册...');
          try {
            // 使用相册服务保存到好好拍相册
            final success = await albumService.savePhotoToAlbum(imageData);
            debugPrint('【Flutter拍照】9. 保存到好好拍相册${success ? '成功' : '失败'}');

            // 如果通过原生保存失败，尝试使用系统相册保存，确保图片至少被保存
            if (!success) {
              debugPrint('【Flutter拍照】通过原生方法保存失败，尝试使用系统相册');
              final result = await ImageGallerySaver.saveFile(tempPath);
              debugPrint('【Flutter拍照】系统相册保存结果: $result');
            }

            // 通知相册组件刷新
            try {
              // 使用全局刷新器刷新相册
              AlbumRefresher().refresh();
              debugPrint('【Flutter拍照】已通知相册组件刷新');
            } catch (e) {
              debugPrint('【Flutter拍照】通知相册组件刷新失败: $e');
            }

            // 清理临时文件
            try {
              await tempFile.delete();
              debugPrint('【Flutter拍照】已删除临时文件: $tempPath');
            } catch (e) {
              debugPrint('【Flutter拍照】删除临时文件失败: $e');
            }
          } catch (e) {
            debugPrint('【Flutter拍照】保存到相册时异常: $e');
          }
        } else {
          debugPrint('【Flutter拍照】拍照失败，未获取到照片数据或数据为空');
        }
      } catch (e) {
        debugPrint('【Flutter拍照】整个拍照流程出错: $e');
      }
    } else {
      debugPrint('【Flutter拍照】错误：无法获取相机控制器');
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => capturePhoto(context),
      child: Container(
        width: 70,
        height: 70,
        child: Stack(
          children: <Widget>[
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromRGBO(52, 137, 142, 1),
                    width: 3,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(70, 70)),
                ),
              ),
            ),
            Positioned(
              top: 0,
              left: 0,
              child: Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color.fromRGBO(8, 229, 235, 1),
                    width: 3,
                  ),
                  borderRadius:
                      const BorderRadius.all(Radius.elliptical(70, 70)),
                ),
              ),
            ),
            Positioned(
              top: 5,
              left: 5,
              child: Container(
                width: 60,
                height: 60,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment(0.11723876744508743, 0.9628744125366211),
                    end: Alignment(-0.908519446849823, 0.28769782185554504),
                    colors: [
                      Color.fromRGBO(121, 113, 181, 1),
                      Color.fromRGBO(32, 34, 67, 1),
                    ],
                  ),
                  borderRadius: BorderRadius.all(Radius.elliptical(60, 60)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
