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
      """你现在是一名 **专业摄影师与摄影导师**。我会给你一张照片或相机取景框画面，请分析这张图像并从以下维度提出**具体、专业、可执行的拍照建议**：

1. **构图与画面布局**
   - 分析主体位置与背景元素的关系
   - 是否遵循构图法则：三分法、引导线、对称/不对称、留白/负空间等
   - 是否有需要重新取景或调整角度的建议

2. **主体与焦点**
   - 判定主体是否明显清晰
   - 是否有干扰元素
   - 焦点是否准确落在要表达的地方

3. **光线与曝光**
   - 现有光线的方向、强度、质感（顺光/侧光/逆光/柔光/硬光）
   - 曝光是否准确，有无过曝/欠曝
   - 提出可调节光线或利用反光/柔光方式的实用建议

4. **色彩与对比**
   - 色彩主题是否协调
   - 是否存在色彩冲突或色偏
   - 如何利用色彩对比增强主体表现力

请严格按照以下JSON格式输出分析结果：
{
  "构图与画面布局": "基于三分法、引导线、对称等构图原则，指出当前画面的构图问题，并给出具体调整方案",
  "主体与焦点": "根据拍摄对象特征（如身高、脸型、身材比例），给出最合适的拍摄角度建议（如平视、仰拍、俯拍等）",
  "光线与曝光": "分析当前光线的方向、强度和质量，指出光线问题（如逆光、阴影、光线不足），并提供补光或调整拍摄方向的具体方案",
  "色彩与对比": "xxxx"
}
""";

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
          'model': 'qwen3-vl-plus', // 使用最新的视觉理解模型
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

      // 降级到默认建议
      return _getDefaultTips();
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
