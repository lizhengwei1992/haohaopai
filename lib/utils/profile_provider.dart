import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileProvider with ChangeNotifier {
  String? _avatarPath;
  String? _backgroundImagePath;

  // Getters
  String? get avatarPath => _avatarPath;
  String? get backgroundImagePath => _backgroundImagePath;

  // 构造函数 - 加载保存的设置
  ProfileProvider() {
    _loadProfile();
  }

  // 从SharedPreferences加载个人资料
  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      _avatarPath = prefs.getString('avatarPath');
      _backgroundImagePath = prefs.getString('backgroundImagePath');

      notifyListeners();
    } catch (e) {
      debugPrint('加载个人资料出错: $e');
    }
  }

  // 保存个人资料到SharedPreferences
  Future<void> _saveProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      if (_avatarPath != null) {
        await prefs.setString('avatarPath', _avatarPath!);
      } else {
        await prefs.remove('avatarPath');
      }

      if (_backgroundImagePath != null) {
        await prefs.setString('backgroundImagePath', _backgroundImagePath!);
      } else {
        await prefs.remove('backgroundImagePath');
      }
    } catch (e) {
      debugPrint('保存个人资料出错: $e');
    }
  }

  // 更新头像
  Future<void> setAvatarPath(String? path) async {
    _avatarPath = path;
    await _saveProfile();
    notifyListeners();
  }

  // 更新背景图片
  Future<void> setBackgroundImagePath(String? path) async {
    _backgroundImagePath = path;
    await _saveProfile();
    notifyListeners();
  }

  // 清除个人资料
  Future<void> clearProfile() async {
    _avatarPath = null;
    _backgroundImagePath = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('avatarPath');
    await prefs.remove('backgroundImagePath');

    notifyListeners();
  }
}
