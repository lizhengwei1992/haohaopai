import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';

class ShootingTip {
  final String type;
  final String text;
  final int priority;

  ShootingTip({required this.type, required this.text, required this.priority});

  factory ShootingTip.fromJson(Map<String, dynamic> json) {
    return ShootingTip(
      type: json['type'],
      text: json['text'],
      priority: json['priority'],
    );
  }
}

class CameraProvider with ChangeNotifier {
  final List<ShootingTip> _tips = [];
  List<ShootingTip> get tips => _tips;

  final _dio = Dio();

  Future<void> analyzeImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      // TODO: 替换为实际的API地址
      final response = await _dio.post(
        'YOUR_API_ENDPOINT',
        data: {'image_base64': base64Image, 'device_info': 'flutter_app'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> tipsJson = response.data['tips'];
        _tips.clear();
        _tips.addAll(
          tipsJson.map((json) => ShootingTip.fromJson(json)).toList(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint(e.toString());
      // 模拟数据用于测试
      _tips.clear();
      _tips.addAll([
        ShootingTip(type: '构图', text: '建议将主体置于九宫格右下交点', priority: 1),
        ShootingTip(type: '光线', text: '当前光线偏暗,建议调整角度避免逆光', priority: 2),
        ShootingTip(type: '角度', text: '尝试降低拍摄角度,突出主体', priority: 3),
      ]);
      notifyListeners();
    }
  }
}
