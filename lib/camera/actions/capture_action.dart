import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../services/camera_service.dart';
import '../screens/image_preview_screen.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';

/// 拍照操作组件
class CaptureAction extends StatelessWidget {
  const CaptureAction({Key? key}) : super(key: key);

  // 拍照
  Future<void> capturePhoto(BuildContext context) async {
    final cameraService = CameraService.instance;
    final nativeCameraController = cameraService.getGlobalCameraController();

    debugPrint('【Flutter拍照】1. 开始拍照流程');

    if (nativeCameraController != null) {
      try {
        // 显示拍照指示器
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('正在拍照...'), duration: Duration(seconds: 1)),
          );
        }

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
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('拍照操作失败: $e')),
            );
          }
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
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('保存临时文件失败: $e')),
              );
            }
            return;
          }

          // 检查临时文件是否存在
          if (!await tempFile.exists()) {
            debugPrint('【Flutter拍照】临时文件创建失败，文件不存在');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('临时文件创建失败，文件不存在')),
              );
            }
            return;
          }

          // 检查临时文件大小
          final fileSize = await tempFile.length();
          debugPrint('【Flutter拍照】临时文件大小: $fileSize 字节');
          if (fileSize <= 0) {
            debugPrint('【Flutter拍照】临时文件大小为0，可能保存失败');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('临时文件大小为0，可能保存失败')),
              );
            }
            return;
          }

          // 直接保存到系统相册
          debugPrint('【Flutter拍照】8. 开始保存照片到系统相册...');
          try {
            // 先尝试使用临时文件路径保存
            var result = await ImageGallerySaver.saveFile(tempPath);
            debugPrint('【Flutter拍照】9. 保存到系统相册调用返回: $result');

            var success =
                result != null && result is Map && result['isSuccess'] == true;

            // 如果第一种方式失败，尝试使用二进制数据直接保存
            if (!success) {
              debugPrint('【Flutter拍照】通过文件路径保存失败，尝试使用二进制数据保存');
              result = await ImageGallerySaver.saveImage(imageData);
              debugPrint('【Flutter拍照】二进制数据保存结果: $result');
              success = result != null &&
                  result is Map &&
                  result['isSuccess'] == true;
            }

            debugPrint(
                '【Flutter拍照】10. 保存到系统相册${success ? '成功' : '失败'}, 完整结果: $result');

            // 显示短暂提示
            if (context.mounted) {
              if (success) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('照片已保存到相册'),
                      duration: Duration(seconds: 1)),
                );

                // 导航到照片预览页面
                debugPrint('【Flutter拍照】11. 即将打开预览界面...');
                if (context.mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ImagePreviewScreen(
                        imagePath: tempPath,
                        onShare: () {
                          // 实现分享功能
                          debugPrint('分享照片: $tempPath');
                          // TODO: 添加分享功能
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('分享功能即将上线')),
                          );
                        },
                        onDelete: () async {
                          // 删除临时文件
                          try {
                            await tempFile.delete();
                            debugPrint('已删除临时文件: $tempPath');
                          } catch (e) {
                            debugPrint('删除临时文件失败: $e');
                          }
                        },
                      ),
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('保存照片到相册失败')),
                );
                debugPrint(
                    '【Flutter拍照】保存到相册失败，可能原因: ${result['errorMessage'] ?? "未知错误"}');
              }
            }
          } catch (e) {
            debugPrint('【Flutter拍照】保存到系统相册时异常: $e');
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('保存照片到相册失败: $e')),
              );
            }
          }
        } else {
          debugPrint('【Flutter拍照】拍照失败，未获取到照片数据或数据为空');
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('拍照失败，未获取到照片数据或数据为空')),
            );
          }
        }
      } catch (e) {
        debugPrint('【Flutter拍照】整个拍照流程出错: $e');
        // 显示错误提示
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('拍照失败: $e')),
          );
        }
      }
    } else {
      debugPrint('【Flutter拍照】错误：无法获取相机控制器');
      // 模拟拍照
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('相机功能模拟：已拍摄照片')),
        );
      }
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
