import 'package:flutter/material.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:math';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _phoneNumber;
  String? _userName;
  String? _loginType; // "phone", "apple"
  String? _userIdentifier; // 用于保存用户唯一标识

  bool get isLoggedIn => _isLoggedIn;
  String? get phoneNumber => _phoneNumber;
  String? get userName => _userName;
  String? get loginType => _loginType;
  String? get userIdentifier => _userIdentifier;

  // 生成随机昵称 (8个英文字母)
  String _generateRandomNickname() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
    Random random = Random();
    String result = '';
    for (int i = 0; i < 8; i++) {
      result += chars[random.nextInt(chars.length)];
    }
    return result;
  }

  // 获取或生成用户昵称
  Future<String> _getUserNickname(String userIdentifier) async {
    // 检查是否已有保存的昵称
    final prefs = await SharedPreferences.getInstance();
    final savedNickname = prefs.getString('nickname_$userIdentifier');

    if (savedNickname != null && savedNickname.isNotEmpty) {
      print("使用已保存的昵称: $savedNickname");
      return savedNickname;
    }

    // 生成新昵称并保存
    final newNickname = _generateRandomNickname();
    await prefs.setString('nickname_$userIdentifier', newNickname);
    print("为用户 $userIdentifier 生成新昵称: $newNickname");
    return newNickname;
  }

  // 初始化，读取保存的登录状态
  Future<void> init() async {
    await loadLoginState();
  }

  // 读取保存的登录状态
  Future<void> loadLoginState() async {
    final prefs = await SharedPreferences.getInstance();

    _isLoggedIn = prefs.getBool('isLoggedIn') ?? false;
    _phoneNumber = prefs.getString('phoneNumber');
    _userName = prefs.getString('userName');
    _loginType = prefs.getString('loginType');
    _userIdentifier = prefs.getString('userIdentifier');

    notifyListeners();
  }

  // 保存登录状态
  Future<void> saveLoginState() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool('isLoggedIn', _isLoggedIn);

    if (_phoneNumber != null) {
      await prefs.setString('phoneNumber', _phoneNumber!);
    }

    if (_userName != null) {
      await prefs.setString('userName', _userName!);
    }

    if (_loginType != null) {
      await prefs.setString('loginType', _loginType!);
    }

    if (_userIdentifier != null) {
      await prefs.setString('userIdentifier', _userIdentifier!);
    }
  }

  // 清除登录状态
  Future<void> clearLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('isLoggedIn');
    await prefs.remove('phoneNumber');
    await prefs.remove('userName');
    await prefs.remove('loginType');
    await prefs.remove('userIdentifier');
  }

  // 获取用户名显示
  String getFormattedUserName() {
    if (_userName != null) {
      return _userName!;
    } else {
      return "游客";
    }
  }

  // 更新用户昵称
  Future<void> updateUserName(String newName) async {
    if (!_isLoggedIn) return;

    _userName = newName;

    // 如果用户已登录，更新昵称存储
    if (_userIdentifier != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('nickname_$_userIdentifier', newName);
      print("更新用户昵称: $newName");
    }

    // 保存到通用的登录状态存储
    await saveLoginState();

    notifyListeners();
  }

  // 使用手机号和验证码登录
  Future<bool> loginWithPhone(String phone, String code) async {
    // 模拟登录验证 - 实际应用中应该调用API
    if (phone == '17364538218' && code == '123456') {
      _isLoggedIn = true;
      _phoneNumber = phone;
      _loginType = "phone";
      _userIdentifier = "phone_$phone";

      // 为用户获取或生成昵称
      _userName = await _getUserNickname(_userIdentifier!);

      // 保存登录状态
      await saveLoginState();

      notifyListeners();
      return true;
    }
    return false;
  }

  // 使用Apple账号登录
  Future<bool> loginWithApple() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      _isLoggedIn = true;
      _loginType = "apple";
      _userIdentifier = credential.userIdentifier;

      // 为用户获取或生成昵称
      _userName = await _getUserNickname(_userIdentifier!);

      print("Apple登录成功，昵称: $_userName");

      // 保存登录状态
      await saveLoginState();

      notifyListeners();
      return true;
    } catch (e) {
      print("Apple登录失败: $e");
      return false;
    }
  }

  // 使用第三方账号登录
  Future<bool> loginWithThirdParty(String provider) async {
    if (provider == 'apple') {
      return await loginWithApple();
    }
    // 其他第三方登录方式
    return false;
  }

  // 登出
  Future<void> logout() async {
    _isLoggedIn = false;
    _phoneNumber = null;
    _userName = null;
    _loginType = null;
    _userIdentifier = null;

    // 清除保存的登录状态
    await clearLoginState();

    notifyListeners();
  }
}
