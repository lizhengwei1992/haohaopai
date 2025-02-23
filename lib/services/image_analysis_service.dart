import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';

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

class ImageAnalysisService {
  final _dio = Dio();

  Future<List<ShootingTip>> analyzeImage(String imagePath) async {
    try {
      final bytes = await File(imagePath).readAsBytes();
      final base64Image = base64Encode(bytes);

      _dio.options.headers['Authorization'] =
          'Bearer sk-413e167d4c744d3f89d0bc0b7dcc3ea8';
      _dio.options.headers['Content-Type'] = 'application/json';

      final response = await _dio.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        data: {
          'model': 'qwen-vl-plus',
          'response_format': {'type': 'json_object'},
          'messages': [
            {
              'role': 'user',
              'content': [
                {
                  'type': 'text',
                  'text':
                      '请分析这张图片的构图、光线和拍摄角度，给出具体的改进建议，每个方面一条建议。建议应该具体且实用。请按照json格式输出，格式为：{"构图": "建议内容", "光线": "建议内容", "角度": "建议内容"}',
                },
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
                },
              ],
            },
          ],
        },
      );

      if (response.statusCode == 200 && response.data['choices'] != null) {
        final content = response.data['choices'][0]['message']['content'];
        debugPrint('AI返回内容: $content');
        // 解析AI返回的JSON内容
        final tips = _parseAIResponse(content);
        return tips;
      }
      throw Exception('Failed to analyze image');
    } catch (e) {
      debugPrint(e.toString());
      // 模拟数据保持不变
      return [
        ShootingTip(type: '构图', text: '建议将主体置于九宫格右下交点', priority: 1),
        ShootingTip(type: '光线', text: '当前光线偏暗,建议调整角度避免逆光', priority: 2),
        ShootingTip(type: '角度', text: '尝试降低拍摄角度,突出主体', priority: 3),
      ];
    }
  }

  List<ShootingTip> _parseAIResponse(String content) {
    try {
      // 使用正则表达式提取符合格式的JSON内容
      final regex = RegExp(
        r'\{[\s\S]*?"构图":[\s\S]*?"光线":[\s\S]*?"角度":[\s\S]*?\}',
      );
      final match = regex.firstMatch(content);

      if (match == null) {
        debugPrint('未找到符合格式的JSON内容');
        return _getDefaultTips();
      }

      final jsonString = match.group(0);
      debugPrint('提取的JSON内容: $jsonString');

      final Map<String, dynamic> jsonContent = json.decode(jsonString!);
      final tips = <ShootingTip>[];
      int priority = 1;

      // 解析JSON并创建ShootingTip对象
      for (final key in ['构图', '光线', '角度']) {
        if (jsonContent.containsKey(key)) {
          tips.add(
            ShootingTip(
              type: key,
              text: jsonContent[key],
              priority: priority++,
            ),
          );
        }
      }

      return tips.isNotEmpty ? tips : _getDefaultTips();
    } catch (e) {
      debugPrint('Error parsing AI response: ${e.toString()}');
      return _getDefaultTips();
    }
  }

  // 添加默认建议的辅助方法
  List<ShootingTip> _getDefaultTips() {
    return [
      ShootingTip(type: '构图', text: '建议将主体置于九宫格右下交点', priority: 1),
      ShootingTip(type: '光线', text: '当前光线偏暗,建议调整角度避免逆光', priority: 2),
      ShootingTip(type: '角度', text: '尝试降低拍摄角度,突出主体', priority: 3),
    ];
  }
}
