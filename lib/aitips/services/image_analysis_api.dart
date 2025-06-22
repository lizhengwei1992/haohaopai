import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../models/shooting_tip.dart';

class ImageAnalysisService {
  final _dio = Dio();
  static const String _analysisPrompt =
      "你是一个专业人像摄影指导师，请根据用户上传的照片，严格按照JSON格式输出分析结果，包含以下4个键：\n"
      "{\n"
      "  \"构图\": \"以九宫格为基本框架提供构图建议，比如人物在九宫格的哪个位置，背景是否简洁，是否需要留白等\",\n"
      "  \"角度\": \"直接给出拍摄角度的建议（如仰拍显高/平视自然等）\",\n"
      "  \"光线\": \"判断光线方向和质量问题，直接提出补光/时间/位置调整方案\",\n"
      "  \"动作\": \"提供1个可操作动作指令（如肢体动作+眼神方向+拍摄方式）\"\n"
      "}\n\n"
      "要求：\n"
      "1. 每个值必须用中文双引号包裹\n"
      "2. 禁止使用Markdown格式\n"
      "3. 语言精炼，每条意见最多50个字）";

  // 直接使用图像字节数据进行分析（无需保存文件）
  Future<List<ShootingTip>> analyzeImageBytes(Uint8List imageBytes) async {
    final startTime = DateTime.now();
    debugPrint('📊 AI分析开始: ${startTime.toString()}');

    try {
      // 直接使用字节数据转换为base64
      final base64Image = base64Encode(imageBytes);
      debugPrint(
          '📊 图像转base64完成: ${DateTime.now().difference(startTime).inMilliseconds}ms');

      _dio.options.headers['Authorization'] =
          'Bearer sk-413e167d4c744d3f89d0bc0b7dcc3ea8';
      _dio.options.headers['Content-Type'] = 'application/json';

      final requestStartTime = DateTime.now();
      debugPrint(
          '📊 API请求开始: ${requestStartTime.difference(startTime).inMilliseconds}ms');

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

      debugPrint(
          '📊 AI API响应时间: ${DateTime.now().difference(requestStartTime).inMilliseconds}ms');

      if (response.statusCode == 200 && response.data['choices'] != null) {
        final content = response.data['choices'][0]['message']['content'];
        debugPrint('📊 AI返回原始内容长度: ${content.length} 字符');

        // 解析AI返回的JSON内容
        final tips = _parseAIResponse(content);

        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('📊 AI分析总耗时: ${totalTime}ms');

        return tips;
      }
      throw Exception('Failed to analyze image');
    } catch (e) {
      final totalTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('📊 AI分析失败，总耗时: ${totalTime}ms');
      debugPrint('分析出错: $e');

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
        debugPrint('📊 未找到符合格式的JSON内容');
        return _getDefaultTips();
      }

      final jsonString = match.group(0);
      debugPrint('📊 成功提取符合格式的JSON内容');

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

      debugPrint('📊 成功解析${tips.length}条拍摄建议');
      return tips.isNotEmpty ? tips : _getDefaultTips();
    } catch (e) {
      debugPrint('📊 解析AI响应出错: ${e.toString()}');
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
