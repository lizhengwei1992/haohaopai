import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:photo_manager/photo_manager.dart';
import '../services/image_analysis_service.dart';
import '../models/photo_metadata.dart';
import 'package:path/path.dart' as path;

enum CameraState {
  initial, // 初始状态
  analyzing, // 分析中
  showingTips, // 显示拍摄建议
  capturing, // 拍摄中
  saving, // 保存中
  error, // 错误状态
}

class CameraProvider with ChangeNotifier {
  // 服务
  final _imageAnalysisService = ImageAnalysisService();

  // 状态
  CameraState _state = CameraState.initial;
  CameraState get state => _state;

  // 拍摄建议
  final List<ShootingTip> _tips = [];
  List<ShootingTip> get tips => _tips;

  // 当前照片路径
  String? _currentPhotoPath;
  String? get currentPhotoPath => _currentPhotoPath;

  // 原始照片路径（用于高质量保存）
  String? _originalPhotoPath;
  String? get originalPhotoPath => _originalPhotoPath;

  // 最近拍摄的照片元数据
  final List<PhotoMetadata> _recentPhotos = [];
  List<PhotoMetadata> get recentPhotos => _recentPhotos;

  // 错误信息
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // 应用相册目录名称
  static const String appAlbumName = 'HaoHaoPai';

  // 更新状态
  void _setState(CameraState newState) {
    _state = newState;
    notifyListeners();
  }

  // 设置原始照片路径
  void setOriginalPhotoPath(String path) {
    _originalPhotoPath = path;
    notifyListeners();
  }

  // 分析图像并获取拍摄建议
  Future<void> analyzeImage(String imagePath) async {
    try {
      _setState(CameraState.analyzing);
      _currentPhotoPath = imagePath;

      // 调用AI分析服务
      final tips = await _imageAnalysisService.analyzeImage(imagePath);

      // 更新建议列表
      _tips.clear();
      _tips.addAll(tips);

      _setState(CameraState.showingTips);
    } catch (e) {
      debugPrint('分析图像出错: $e');
      _errorMessage = '无法分析图像，请重试';
      _setState(CameraState.error);
    }
  }

  // 保存照片到系统相册
  Future<void> saveToGallery(String imagePath) async {
    try {
      final saveTime = DateTime.now();
      debugPrint('保存照片到相册: $imagePath, 时间: $saveTime');

      // 保存到相册
      final AssetEntity? asset = await PhotoManager.editor.saveImageWithPath(
        imagePath,
        title: 'HaoHaoPai_${DateTime.now().millisecondsSinceEpoch}',
      );

      if (asset != null) {
        debugPrint('照片已成功保存到相册，ID: ${asset.id}');

        // 获取照片文件
        final assetFile = await asset.file;
        if (assetFile != null) {
          // 创建照片元数据并添加到最近照片列表
          final metadata = PhotoMetadata(
            path: assetFile.path,
            timestamp: asset.createDateTime,
            systemId: asset.id,
            isFromApp: true,
          );

          // 检查是否已存在相同系统ID的照片
          final existingIndex = _recentPhotos.indexWhere(
              (photo) => photo.systemId != null && photo.systemId == asset.id);

          if (existingIndex >= 0) {
            // 如果已存在，更新路径
            _recentPhotos[existingIndex] = metadata;
            debugPrint('更新已存在的照片元数据，系统ID: ${asset.id}');
          } else {
            // 添加到最近照片列表的开头
            _recentPhotos.insert(0, metadata);
            debugPrint('添加新照片到最近列表，系统ID: ${asset.id}');

            // 只保留最近10张照片
            if (_recentPhotos.length > 10) {
              _recentPhotos.removeLast();
            }
          }

          notifyListeners();
        } else {
          // 如果无法获取文件，使用原始路径创建元数据
          final metadata = PhotoMetadata(
            path: imagePath,
            timestamp: asset.createDateTime,
            systemId: asset.id,
            isFromApp: true,
          );

          _recentPhotos.insert(0, metadata);

          // 只保留最近10张照片
          if (_recentPhotos.length > 10) {
            _recentPhotos.removeLast();
          }

          notifyListeners();
          debugPrint('使用原始路径添加照片到最近列表，系统ID: ${asset.id}');
        }
      } else {
        debugPrint('保存照片到相册失败');
      }
    } catch (e) {
      debugPrint('保存照片到相册出错: $e');
      // 即使保存失败，也尝试将照片添加到最近列表
      try {
        final metadata = PhotoMetadata(
          path: imagePath,
          timestamp: DateTime.now(),
          isFromApp: true,
        );

        _recentPhotos.insert(0, metadata);

        // 只保留最近10张照片
        if (_recentPhotos.length > 10) {
          _recentPhotos.removeLast();
        }

        notifyListeners();
        debugPrint('保存失败但已添加照片到最近列表');
      } catch (e2) {
        debugPrint('添加照片到最近列表也失败: $e2');
      }
    }
  }

  // 查找并存储照片在系统相册中的ID
  Future<void> _findAndStorePhotoId(String filePath, DateTime saveTime) async {
    try {
      // 确保有权限访问相册
      final permitted = await PhotoManager.requestPermissionExtend();
      if (!permitted.isAuth) {
        debugPrint('无权限访问相册，无法获取照片ID');
        return;
      }

      // 等待一小段时间确保照片已保存到系统相册
      await Future.delayed(const Duration(milliseconds: 500));

      // 获取所有相册
      final albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );

      // 获取文件名和时间戳部分用于匹配
      final fileName = path.basename(filePath);
      final fileNameWithoutExt = path.basenameWithoutExtension(filePath);
      final timeStampPart = _extractTimeStamp(fileNameWithoutExt);

      debugPrint('尝试查找照片: $fileName, 时间戳部分: $timeStampPart, 保存时间: $saveTime');

      bool found = false;
      AssetEntity? matchedAsset;

      // 在所有相册中查找
      for (final album in albums) {
        // 只获取最近的照片
        final assets = await album.getAssetListRange(start: 0, end: 20);

        for (final asset in assets) {
          // 检查创建时间是否接近（允许5秒误差）
          final timeDifference =
              asset.createDateTime.difference(saveTime).inSeconds.abs();

          if (timeDifference < 5) {
            debugPrint(
                '找到时间匹配的照片: ${asset.id}, 创建时间: ${asset.createDateTime}, 时间差: $timeDifference秒');
            matchedAsset = asset;
            found = true;
            break;
          }

          // 如果时间不匹配，尝试通过文件名匹配
          final assetFile = await asset.file;
          if (assetFile != null) {
            final assetFileName = path.basename(assetFile.path);
            final assetTimeStamp = _extractTimeStamp(
                path.basenameWithoutExtension(assetFile.path));

            debugPrint('检查资产: $assetFileName, 时间戳部分: $assetTimeStamp');

            // 如果时间戳部分匹配
            if (timeStampPart.isNotEmpty &&
                assetTimeStamp.isNotEmpty &&
                (timeStampPart == assetTimeStamp ||
                    timeStampPart.contains(assetTimeStamp) ||
                    assetTimeStamp.contains(timeStampPart))) {
              debugPrint('找到文件名匹配的照片: ${asset.id}, 文件名: $assetFileName');
              matchedAsset = asset;
              found = true;
              break;
            }
          }
        }

        if (found) break;
      }

      // 如果找到匹配的照片
      if (found && matchedAsset != null) {
        // 创建照片元数据并添加到最近照片列表
        final assetFile = await matchedAsset.file;
        if (assetFile != null) {
          final metadata = PhotoMetadata(
            path: assetFile.path,
            timestamp: matchedAsset.createDateTime,
            systemId: matchedAsset.id,
            isFromApp: true,
          );

          // 添加到最近照片列表的开头
          _recentPhotos.insert(0, metadata);

          // 只保留最近10张照片
          if (_recentPhotos.length > 10) {
            _recentPhotos.removeLast();
          }

          notifyListeners();
          debugPrint('已添加照片到最近列表，系统ID: ${matchedAsset.id}');
        }
      } else {
        debugPrint('未找到匹配的照片');
      }
    } catch (e) {
      debugPrint('查找并存储照片ID出错: $e');
    }
  }

  // 从文件名中提取时间戳部分
  String _extractTimeStamp(String fileName) {
    // 尝试提取数字部分，通常是时间戳
    final regex = RegExp(r'(\d+)');
    final match = regex.firstMatch(fileName);
    return match?.group(0) ?? '';
  }

  // 获取应用照片目录
  Future<Directory> _getAppPhotoDirectory() async {
    final Directory appDocDir = await getApplicationDocumentsDirectory();
    final Directory photoDir = Directory('${appDocDir.path}/$appAlbumName');

    // 确保目录存在
    if (!await photoDir.exists()) {
      await photoDir.create(recursive: true);
    }

    return photoDir;
  }

  // 加载应用相册中的照片
  Future<void> loadAppPhotos() async {
    try {
      final Directory photoDir = await _getAppPhotoDirectory();
      final List<FileSystemEntity> files = await photoDir.list().toList();

      // 过滤出图片文件并按修改时间排序
      final List<File> imageFiles = files
          .whereType<File>()
          .where((file) =>
              file.path.toLowerCase().endsWith('.jpg') ||
              file.path.toLowerCase().endsWith('.jpeg') ||
              file.path.toLowerCase().endsWith('.png'))
          .toList();

      // 按修改时间排序（最新的在前）
      imageFiles.sort((a, b) {
        return b.statSync().modified.compareTo(a.statSync().modified);
      });

      // 清空当前列表
      _recentPhotos.clear();

      // 添加照片到列表
      for (final file in imageFiles) {
        final metadata = PhotoMetadata(
          path: file.path,
          timestamp: file.statSync().modified,
        );
        _recentPhotos.add(metadata);

        // 只保留最近10张照片
        if (_recentPhotos.length >= 10) break;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('加载应用相册照片出错: $e');
    }
  }

  // 添加到最近照片列表
  void _addToRecentPhotos(String path) {
    final metadata = PhotoMetadata(path: path, timestamp: DateTime.now());

    _recentPhotos.insert(0, metadata);

    // 只保留最近10张照片
    if (_recentPhotos.length > 10) {
      _recentPhotos.removeLast();
    }

    notifyListeners();
  }

  // 重置状态 - 只重置拍摄状态，不影响最近照片列表
  void reset() {
    _state = CameraState.initial;
    _tips.clear();
    _currentPhotoPath = null;
    _originalPhotoPath = null;
    _errorMessage = '';
    notifyListeners();
  }

  // 清除错误
  void clearError() {
    _errorMessage = '';
    _setState(CameraState.initial);
  }

  // 从最近照片列表中删除指定路径的照片
  Future<void> removePhoto(String path) async {
    // 查找照片元数据
    final photoIndex = _recentPhotos.indexWhere((photo) => photo.path == path);
    final photoMetadata = photoIndex >= 0 ? _recentPhotos[photoIndex] : null;

    // 从列表中移除
    if (photoIndex >= 0) {
      _recentPhotos.removeAt(photoIndex);
      notifyListeners();
    }

    try {
      // 1. 删除应用目录中的文件
      final file = File(path);
      if (file.existsSync()) {
        file.deleteSync();
        debugPrint('已从应用目录删除照片: $path');
      }

      // 2. 尝试从系统相册删除
      bool deleted = false;

      // 如果有存储的系统ID，优先使用ID删除
      if (photoMetadata?.systemId != null) {
        debugPrint('使用系统ID删除照片: ${photoMetadata!.systemId}');
        final result =
            await PhotoManager.editor.deleteWithIds([photoMetadata.systemId!]);
        deleted = result.isNotEmpty;

        if (deleted) {
          debugPrint('已通过系统ID从相册删除照片');
        } else {
          debugPrint('通过系统ID删除照片失败，尝试其他方法');
        }
      }

      // 如果通过ID删除失败，尝试通过文件路径匹配删除
      if (!deleted) {
        await _deleteFromSystemGallery(path);
      }

      // 删除后重新加载相册，确保预览显示最新照片
      loadAppPhotos();
    } catch (e) {
      debugPrint('删除照片文件出错: $e');
    }
  }

  // 从系统相册删除照片
  Future<void> _deleteFromSystemGallery(String filePath) async {
    try {
      // 请求权限
      final PermissionState result =
          await PhotoManager.requestPermissionExtend();
      if (!result.hasAccess) {
        debugPrint('没有获得相册访问权限，无法删除系统相册中的照片');
        return;
      }

      // 获取文件名和创建时间，用于匹配
      final String fileName = path.basename(filePath);
      final File file = File(filePath);
      final DateTime fileModTime =
          file.existsSync() ? file.statSync().modified : DateTime.now();

      debugPrint('尝试删除系统相册中的照片: $fileName');

      // 获取所有相册
      final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
        type: RequestType.image,
      );

      if (albums.isEmpty) {
        debugPrint('未找到相册');
        return;
      }

      // 遍历所有相册查找匹配的照片
      bool deleted = false;
      for (final album in albums) {
        debugPrint('搜索相册: ${album.name}');

        // 获取相册中的照片
        final List<AssetEntity> assets =
            await album.getAssetListRange(start: 0, end: 100);

        // 按时间排序，最新的在前面
        assets.sort((a, b) => b.createDateTime.compareTo(a.createDateTime));

        // 查找匹配的照片
        for (final asset in assets) {
          // 检查创建时间是否接近（允许5秒误差）
          final timeDiff =
              asset.createDateTime.difference(fileModTime).inSeconds.abs();
          if (timeDiff <= 5) {
            // 获取文件以进一步确认
            final File? assetFile = await asset.file;
            if (assetFile != null) {
              final String assetFileName = path.basename(assetFile.path);

              debugPrint('找到可能匹配的照片: $assetFileName, 时间差: $timeDiff秒');

              // 尝试删除
              final result =
                  await PhotoManager.editor.deleteWithIds([asset.id]);
              if (result.isNotEmpty) {
                debugPrint('已从系统相册删除照片: ${assetFile.path}');
                deleted = true;
                break;
              } else {
                debugPrint('从系统相册删除照片失败: ${assetFile.path}');
              }
            }
          }
        }

        if (deleted) break;
      }

      if (!deleted) {
        // 如果按时间匹配没找到，尝试按文件名匹配
        debugPrint('按时间匹配未找到照片，尝试按文件名匹配');

        for (final album in albums) {
          final List<AssetEntity> assets =
              await album.getAssetListRange(start: 0, end: 100);

          for (final asset in assets) {
            final File? assetFile = await asset.file;
            if (assetFile != null) {
              final String assetFileName = path.basename(assetFile.path);

              // 如果文件名包含相同的时间戳部分，则可能是同一张照片
              if (fileName.contains('.png') && assetFileName.contains('.jpg') ||
                  fileName.contains('.jpg') && assetFileName.contains('.png')) {
                // 提取时间戳部分进行比较
                final fileNameWithoutExt = fileName.split('.').first;
                final assetFileNameWithoutExt = assetFileName.split('.').first;

                if (fileNameWithoutExt == assetFileNameWithoutExt ||
                    fileNameWithoutExt.contains(assetFileNameWithoutExt) ||
                    assetFileNameWithoutExt.contains(fileNameWithoutExt)) {
                  debugPrint('找到文件名匹配的照片: $assetFileName');

                  final result =
                      await PhotoManager.editor.deleteWithIds([asset.id]);
                  if (result.isNotEmpty) {
                    debugPrint('已从系统相册删除照片: ${assetFile.path}');
                    deleted = true;
                    break;
                  } else {
                    debugPrint('从系统相册删除照片失败: ${assetFile.path}');
                  }
                }
              }
            }
          }

          if (deleted) break;
        }
      }

      if (!deleted) {
        debugPrint('未找到匹配的照片，无法从系统相册删除');
      }
    } catch (e) {
      debugPrint('从系统相册删除照片出错: $e');
    }
  }

  // 添加照片到最近照片列表
  void addPhotoToRecentList(PhotoMetadata metadata) {
    // 检查是否已存在相同路径的照片
    final existingIndex =
        _recentPhotos.indexWhere((photo) => photo.path == metadata.path);

    if (existingIndex >= 0) {
      // 如果已存在，更新元数据
      _recentPhotos[existingIndex] = metadata;
      debugPrint('更新已存在的照片元数据，路径: ${metadata.path}');
    } else {
      // 添加到最近照片列表的开头
      _recentPhotos.insert(0, metadata);
      debugPrint('添加新照片到最近列表，路径: ${metadata.path}');

      // 只保留最近10张照片
      if (_recentPhotos.length > 10) {
        _recentPhotos.removeLast();
      }
    }

    notifyListeners();
  }
}
