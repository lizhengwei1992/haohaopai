import 'package:flutter/material.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _phoneNumber;

  bool get isLoggedIn => _isLoggedIn;
  String? get phoneNumber => _phoneNumber;

  // 使用手机号和验证码登录
  Future<bool> loginWithPhone(String phone, String code) async {
    // 模拟登录验证 - 实际应用中应该调用API
    if (phone == '17364538218' && code == '123456') {
      _isLoggedIn = true;
      _phoneNumber = phone;
      notifyListeners();
      return true;
    }
    return false;
  }

  // 使用第三方账号登录（微信或Apple）
  Future<bool> loginWithThirdParty(String provider) async {
    // 模拟第三方登录 - 实际应用中应该调用第三方SDK
    // 这里永远返回false，因为我们没有实现实际的第三方登录
    return false;
  }

  // 登出
  void logout() {
    _isLoggedIn = false;
    _phoneNumber = null;
    notifyListeners();
  }
}
