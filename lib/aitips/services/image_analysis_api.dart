import 'package:dio/dio.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../models/shooting_tip.dart';

class ImageAnalysisService {
  final _dio = Dio();
  static const String _analysisPrompt =
      """你是资深摄影师。看这张相机取景画面，从以下四个方面各给出一条最关键、可直接执行的改进建议，每条不超过40字，只给动作、不解释原因。

严格输出JSON：{"构图与画面布局":"...","主体与焦点":"...","光线与曝光":"...","色彩与对比":"..."}""";

  // 直接使用图像字节数据进行分析（无需保存文件）
  Future<List<ShootingTip>> analyzeImageBytes(Uint8List imageBytes) async {
    final startTime = DateTime.now();
    debugPrint('📊 AI分析开始: ${startTime.toString()}');

    try {
      // 压缩图片到合适尺寸，降低上传体积与 image token，加速分析
      final compressedBytes = await _compressForAnalysis(imageBytes);
      debugPrint(
          '📊 图片压缩: ${imageBytes.length} → ${compressedBytes.length} 字节 (${(compressedBytes.length / imageBytes.length * 100).toStringAsFixed(0)}%)，耗时 ${DateTime.now().difference(startTime).inMilliseconds}ms');

      // 压缩后的字节转换为base64
      final base64Image = base64Encode(compressedBytes);
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
          'model': 'qwen3-vl-plus', // 使用最新的视觉理解模型
          'response_format': {'type': 'json_object'},
          'max_tokens': 500, // 限制输出长度，控制响应时间
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

      // 降级到默认建议
      return _getDefaultTips();
    }
  }

  /// 压缩图片用于分析：最长边缩到 1024、JPEG 质量 75
  /// 场景理解无需原始分辨率，压缩可降低上传体积、image token 与延迟
  Future<Uint8List> _compressForAnalysis(Uint8List bytes) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 1024,
        minHeight: 1024,
        quality: 75,
        format: CompressFormat.jpeg,
        autoCorrectionAngle: true,
      );
      return result.isNotEmpty ? result : bytes;
    } catch (e) {
      // 压缩失败时退回原图，保证链路不中断
      debugPrint('📊 图片压缩失败，使用原图: $e');
      return bytes;
    }
  }

  List<ShootingTip> _parseAIResponse(String content) {
    try {
      // 使用正则表达式提取符合格式的JSON内容
      // 匹配新的4个字段：构图与画面布局、主体与焦点、光线与曝光、色彩与对比
      final regex = RegExp(
        r'\{[\s\S]*?"构图与画面布局":[\s\S]*?"主体与焦点":[\s\S]*?"光线与曝光":[\s\S]*?"色彩与对比":[\s\S]*?\}',
      );
      final match = regex.firstMatch(content);

      if (match == null) {
        debugPrint('📊 未找到符合格式的JSON内容');
        debugPrint('📊 原始内容预览: ${content.length > 200 ? content.substring(0, 200) : content}');
        return _getDefaultTips();
      }

      final jsonString = match.group(0);
      debugPrint('📊 成功提取符合格式的JSON内容');

      final Map<String, dynamic> jsonContent = json.decode(jsonString!);
      final tips = <ShootingTip>[];
      int priority = 1;

      // 解析JSON并创建ShootingTip对象（按照新提示词的字段顺序）
      for (final key in ['构图与画面布局', '主体与焦点', '光线与曝光', '色彩与对比']) {
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
      debugPrint('📊 错误详情: $e');
      return _getDefaultTips();
    }
  }

  // 添加默认建议的辅助方法（更新为新的4个维度）
  List<ShootingTip> _getDefaultTips() {
    return [
      const ShootingTip(type: '构图与画面布局', text: '建议将主体置于九宫格右下交点，注意背景简洁', priority: 1),
      const ShootingTip(type: '主体与焦点', text: '确保主体清晰突出，避免背景干扰', priority: 2),
      const ShootingTip(type: '光线与曝光', text: '当前光线偏暗，建议调整角度避免逆光或增加补光', priority: 3),
      const ShootingTip(type: '色彩与对比', text: '调整色彩饱和度增强画面表现力', priority: 4),
    ];
  }
}
