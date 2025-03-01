import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import '../services/image_analysis_service.dart';
import '../models/photo_metadata.dart';

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

  // 保存照片到相册
  Future<bool> saveToGallery(String imagePath) async {
    try {
      _setState(CameraState.saving);

      // 直接保存原始图片，不进行压缩
      final result = await ImageGallerySaver.saveFile(imagePath);
      final success = result['isSuccess'] == true;

      if (success) {
        // 添加到最近照片列表
        _addToRecentPhotos(imagePath);
      }

      _setState(CameraState.initial);
      return success;
    } catch (e) {
      debugPrint('保存照片出错: $e');
      _errorMessage = '保存照片失败';
      _setState(CameraState.error);
      return false;
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

  // 重置状态
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
}
