import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  // 默认设置
  bool _saveToGallery = true;
  bool _showGridLines = true;
  bool _enableLocation = false;
  int _imageQuality = 85; // 图片压缩质量 (0-100)

  // Getters
  bool get saveToGallery => _saveToGallery;
  bool get showGridLines => _showGridLines;
  bool get enableLocation => _enableLocation;
  int get imageQuality => _imageQuality;

  // 构造函数 - 加载保存的设置
  SettingsProvider() {
    _loadSettings();
  }

  // 从SharedPreferences加载设置
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _saveToGallery = prefs.getBool('saveToGallery') ?? true;
      _showGridLines = prefs.getBool('showGridLines') ?? true;
      _enableLocation = prefs.getBool('enableLocation') ?? false;
      _imageQuality = prefs.getInt('imageQuality') ?? 85;

      notifyListeners();
    } catch (e) {
      debugPrint('加载设置出错: $e');
    }
  }

  // 保存设置到SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setBool('saveToGallery', _saveToGallery);
      await prefs.setBool('showGridLines', _showGridLines);
      await prefs.setBool('enableLocation', _enableLocation);
      await prefs.setInt('imageQuality', _imageQuality);
    } catch (e) {
      debugPrint('保存设置出错: $e');
    }
  }

  // 更新设置
  void setSaveToGallery(bool value) {
    _saveToGallery = value;
    _saveSettings();
    notifyListeners();
  }

  void setShowGridLines(bool value) {
    _showGridLines = value;
    _saveSettings();
    notifyListeners();
  }

  void setEnableLocation(bool value) {
    _enableLocation = value;
    _saveSettings();
    notifyListeners();
  }

  void setImageQuality(int value) {
    if (value >= 0 && value <= 100) {
      _imageQuality = value;
      _saveSettings();
      notifyListeners();
    }
  }

  // 重置所有设置为默认值
  Future<void> resetSettings() async {
    _saveToGallery = true;
    _showGridLines = true;
    _enableLocation = false;
    _imageQuality = 85;

    await _saveSettings();
    notifyListeners();
  }
}
