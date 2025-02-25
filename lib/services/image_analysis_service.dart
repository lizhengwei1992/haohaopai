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
  static const String _analysisPrompt =
      "你是一个专业人像摄影指导师，请根据用户上传的照片，严格按照JSON格式输出分析结果，包含以下4个键：\n"
      "{\n"
      "  \"构图\": \"先描述当前构图问题，再给出具体改进方法（如三分法/留白/背景简化等）\",\n"
      "  \"角度\": \"分析拍摄角度问题，推荐新角度及调整理由（如仰拍显高/平视自然等）\",\n"
      "  \"光线\": \"判断光线方向和质量问题，提出补光/时间/位置调整方案\",\n"
      "  \"动作\": \"提供2-3个可操作动作指令（如肢体动作+眼神方向+拍摄方式）\"\n"
      "}\n\n"
      "要求：\n"
      "1. 每个值必须用中文双引号包裹\n"
      "2. 禁止使用Markdown格式\n"
      "3. 语言口语化，举例说明（如：背景有垃圾桶→建议侧移3步用墙面遮挡）\n"
      "4. 每条建议包含问题诊断和解决方案";

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
                {'type': 'text', 'text': _analysisPrompt},
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
        ShootingTip(type: '角度', text: '当前光线偏暗,建议调整角度避免逆光', priority: 2),
        ShootingTip(type: '光线', text: '尝试降低拍摄角度,突出主体', priority: 3),
        ShootingTip(type: '动作', text: '尝试自然微笑并略微侧身,增加照片活力', priority: 4),
      ];
    }
  }

  List<ShootingTip> _parseAIResponse(String content) {
    try {
      // 使用正则表达式提取符合格式的JSON内容
      final regex = RegExp(
        r'\{[\s\S]*?"构图":[\s\S]*?"角度":[\s\S]*?"光线":[\s\S]*?"动作":[\s\S]*?\}',
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
      for (final key in ['构图', '光线', '角度', '动作']) {
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
      ShootingTip(type: '动作', text: '尝试自然微笑并略微侧身,增加照片活力', priority: 4),
    ];
  }
}
