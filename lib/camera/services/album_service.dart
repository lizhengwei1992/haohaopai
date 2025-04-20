import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// 相册管理服务
class AlbumService {
  // 单例模式
  static final AlbumService _instance = AlbumService._internal();
  factory AlbumService() => _instance;
  AlbumService._internal();

  // 相册名称
  static const String albumName = "好好拍";

  // Method Channel
  static const MethodChannel _channel =
      MethodChannel('com.haohaopai.app/album');

  // 缓存的相册
  AssetPathEntity? _albumEntity;

  // 是否已初始化
  bool _isInitialized = false;

  /// 初始化相册服务（使用原生代码创建相册）
  Future<bool> initAlbum() async {
    if (_isInitialized) {
      return true;
    }

    try {
      // 请求权限
      final PermissionState ps = await PhotoManager.requestPermissionExtend();
      if (!ps.hasAccess) {
        debugPrint('没有相册访问权限');
        return false;
      }

      // 直接调用原生方法创建相册
      final bool success =
          await _channel.invokeMethod('createAlbum', albumName);

      if (success) {
        debugPrint('相册创建或已存在: $albumName');
        _isInitialized = true;

        // 尝试获取相册引用
        await _findAlbum();
        return true;
      } else {
        debugPrint('创建相册失败');
        return false;
      }
    } catch (e) {
      debugPrint('初始化相册服务出错: $e');
      return false;
    }
  }

  /// 仅查找相册，不创建
  Future<AssetPathEntity?> _findAlbum() async {
    // 如果已经缓存了相册实体，直接返回
    if (_albumEntity != null) {
      return _albumEntity;
    }

    // 获取所有相册
    final List<AssetPathEntity> albums = await PhotoManager.getAssetPathList(
      onlyAll: false,
      type: RequestType.image,
    );

    // 查找名为"好好拍"的相册
    for (var album in albums) {
      if (album.name == albumName) {
        _albumEntity = album;
        debugPrint('找到好好拍相册');
        return album;
      }
    }

    debugPrint('未找到好好拍相册');
    return null;
  }

  /// 获取相册中的最新照片
  Future<AssetEntity?> getLatestPhoto() async {
    // 确保初始化
    if (!_isInitialized) {
      await initAlbum();
    }

    // 确保相册引用有效
    if (_albumEntity == null) {
      await _findAlbum();
    }

    // 如果找不到相册，返回null
    if (_albumEntity == null) {
      return null;
    }

    try {
      // 获取相册中的第一张照片（最新的）
      final List<AssetEntity> assets =
          await _albumEntity!.getAssetListRange(start: 0, end: 1);
      return assets.isNotEmpty ? assets.first : null;
    } catch (e) {
      debugPrint('获取最新照片失败: $e');
      return null;
    }
  }

  /// 获取相册中的所有照片
  Future<List<AssetEntity>> getAllPhotos() async {
    // 确保初始化
    if (!_isInitialized) {
      await initAlbum();
    }

    // 确保相册引用有效
    if (_albumEntity == null) {
      await _findAlbum();
    }

    // 如果找不到相册，返回空列表
    if (_albumEntity == null) {
      return [];
    }

    try {
      return await _albumEntity!.getAssetListPaged(page: 0, size: 1000);
    } catch (e) {
      debugPrint('获取所有照片失败: $e');
      return [];
    }
  }

  /// 保存照片到好好拍相册 - 直接使用原生方法
  Future<bool> savePhotoToAlbum(Uint8List imageData) async {
    try {
      debugPrint('进入savePhotoToAlbum方法');

      // 确保初始化
      if (!_isInitialized) {
        debugPrint('相册服务尚未初始化，正在初始化...');
        final initResult = await initAlbum();
        if (!initResult) {
          debugPrint('相册服务初始化失败，无法保存照片');
          return false;
        }
      }

      debugPrint('准备调用原生方法保存照片，数据大小: ${imageData.length} 字节');
      debugPrint('Method Channel名称: ${_channel.name}');

      try {
        // 直接调用原生方法保存照片到指定相册
        final result = await _channel.invokeMethod(
          'savePhotoToAlbum',
          {
            'imageData': imageData,
            'albumName': albumName,
          },
        );

        // 检查结果类型
        final bool success = result is bool ? result : false;
        debugPrint(
            '原生savePhotoToAlbum调用返回: $success (原始结果类型: ${result.runtimeType})');

        // 保存成功后刷新缓存的相册引用
        if (success) {
          debugPrint('照片保存成功，清除缓存并刷新相册引用');
          _albumEntity = null; // 清除缓存，下次获取时会刷新
          await _findAlbum();
          debugPrint('照片已成功保存到"好好拍"相册');
        } else {
          debugPrint('原生保存照片方法返回失败');
        }

        return success;
      } on PlatformException catch (e) {
        debugPrint(
            '保存照片平台异常: code=${e.code}, message=${e.message}, details=${e.details}');
        return false;
      } on MissingPluginException catch (e) {
        debugPrint('缺少插件异常: ${e.message}');
        return false;
      }
    } catch (e) {
      debugPrint('保存照片出错（详细）: $e');
      return false;
    }
  }
}
