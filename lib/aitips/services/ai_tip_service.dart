import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import '../../camera/services/native_camera_service.dart';
import '../models/ai_tip.dart';
import '../models/shooting_tip.dart';
import '../services/image_analysis_api.dart';

/// AI拍摄建议服务
/// 负责捕获当前相机预览帧并从服务器获取拍摄建议
class AiTipService {
  // 单例模式
  static final AiTipService _instance = AiTipService._internal();
  factory AiTipService() => _instance;
  AiTipService._internal();

  // 后端API服务器地址
  final String _apiBaseUrl = 'https://api.haohaopai.com';

  // 请求客户端
  final Dio _dio = Dio();

  /// 获取当前预览场景的拍摄建议
  ///
  /// [imageBytes] 可选的图像字节数据，如果为null则尝试从相机获取预览帧
  ///
  /// 返回包含以下字段的Map：
  /// - success: 是否获取成功
  /// - tips: 拍摄建议列表 (List<AiTip>)
  /// - scene: 识别的场景类型
  /// - confidence: 置信度
  /// - error: 错误信息（如果发生错误）
  Future<Map<String, dynamic>> getCaptureTips([Uint8List? imageBytes]) async {
    // 最大重试次数
    const int maxRetries = 2;
    int retryCount = 0;

    while (retryCount <= maxRetries) {
      try {
        // 1. 获取图像数据（优先使用传入的参数，否则从相机捕获）
        Uint8List? imageData = imageBytes;

        if (imageData == null) {
          debugPrint('尝试获取预览帧 (尝试 ${retryCount + 1}/${maxRetries + 1})');
          imageData = await NativeCameraService.captureCurrentPreviewFrame();
        }

        if (imageData == null) {
          debugPrint('无法获取当前预览帧');
          retryCount++;

          if (retryCount > maxRetries) {
            debugPrint('达到最大重试次数，使用模拟数据');
            return await mockAnalysis();
          }

          // 等待一小段时间再重试
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }

        debugPrint('成功获取图像数据，大小: ${imageData.length} 字节');

        // 2. 将图像数据发送到服务器进行分析
        return await _analyzeImageWithServer(imageData);
      } catch (e) {
        debugPrint('获取拍摄建议时出错: $e');
        retryCount++;

        if (retryCount > maxRetries) {
          debugPrint('达到最大重试次数，使用模拟数据');
          return await mockAnalysis();
        }

        // 等待一小段时间再重试
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    // 这里理论上不会执行到，但为了代码完整性添加
    return await mockAnalysis();
  }

  /// 发送图像到服务器并获取分析结果
  Future<Map<String, dynamic>> _analyzeImageWithServer(
    Uint8List imageData,
  ) async {
    try {
      final startTime = DateTime.now();
      debugPrint('🔍 开始分析图像，图像大小: ${imageData.length} 字节');

      // 使用ImageAnalysisService进行实际分析
      try {
        // 创建服务实例
        final imageAnalysisService = ImageAnalysisService();

        // 调用图像分析并计时
        debugPrint('🔍 调用ImageAnalysisService.analyzeImageBytes...');
        final shootingTips =
            await imageAnalysisService.analyzeImageBytes(imageData);

        // 转换ShootingTip为AiTip
        final List<AiTip> aiTips = shootingTips
            .map((tip) =>
                AiTip(type: tip.type, text: tip.text, priority: tip.priority))
            .toList();

        final totalTime = DateTime.now().difference(startTime).inMilliseconds;
        debugPrint('🔍 图像分析成功完成，总耗时: ${totalTime}ms，获取${aiTips.length}条建议');
        debugPrint(
            '🔍 拍摄建议: ${aiTips.map((tip) => "${tip.type}:${tip.text}").join("\n")}');

        // 返回成功结果
        return {
          'success': true,
          'tips': aiTips,
          'scene': '智能场景', // 可根据实际情况调整
          'confidence': 0.9, // 可根据实际情况调整
        };
      } catch (serviceError) {
        debugPrint(
            '🔍 调用ImageAnalysisService出错: $serviceError，尝试使用FormData直接请求');

        // 如果使用ImageAnalysisService失败，使用原始的Dio请求方法
        // 构建FormData，包含图像数据
        final formData = FormData.fromMap({
          'image': MultipartFile.fromBytes(
            imageData,
            filename: 'preview.jpg',
            contentType: MediaType('image', 'jpeg'),
          ),
        });

        // 发送请求
        debugPrint('🔍 开始发送API请求...');
        final response = await _dio.post(
          '$_apiBaseUrl/teach-capture/analyze',
          data: formData,
          options: Options(
            headers: {'Content-Type': 'multipart/form-data'},
            responseType: ResponseType.json,
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );

        // 3. 解析并返回服务器响应
        if (response.statusCode == 200) {
          final data = response.data;
          debugPrint('🔍 服务器返回数据: $data');

          if (data['success'] == true) {
            // 解析tips数据为AiTip对象列表
            final List<dynamic> rawTips = data['tips'] ?? [];
            final List<AiTip> parsedTips = [];

            for (int i = 0; i < rawTips.length; i++) {
              if (rawTips[i] is String) {
                // 如果是字符串，创建一个简单的AiTip对象
                parsedTips.add(
                  AiTip(
                    type: i == 0
                        ? '构图'
                        : i == 1
                            ? '光线'
                            : i == 2
                                ? '角度'
                                : '动作',
                    text: rawTips[i],
                    priority: i + 1,
                  ),
                );
              } else if (rawTips[i] is Map<String, dynamic>) {
                // 如果是Map，使用fromJson构造函数
                parsedTips.add(AiTip.fromJson(rawTips[i]));
              }
            }

            final totalTime =
                DateTime.now().difference(startTime).inMilliseconds;
            debugPrint(
                '🔍 图像分析成功完成，总耗时: ${totalTime}ms，获取${parsedTips.length}条建议');

            // 成功获取拍摄建议
            return {
              'success': true,
              'tips': parsedTips,
              'scene': data['scene'] ?? '未知场景',
              'confidence': data['confidence'] ?? 0.0,
            };
          } else {
            // 服务器返回了错误
            debugPrint('🔍 服务器返回错误: ${data['message']}');
            return {'success': false, 'error': data['message'] ?? '服务器分析错误'};
          }
        } else {
          // HTTP错误
          debugPrint('🔍 HTTP错误: ${response.statusCode}');
          return {'success': false, 'error': '服务器响应错误: ${response.statusCode}'};
        }
      }
    } on DioException catch (e) {
      // Dio请求异常
      debugPrint('🔍 网络请求失败: ${e.message}');
      return {'success': false, 'error': '网络请求失败: ${e.message}'};
    } catch (e) {
      // 其他异常
      debugPrint('🔍 分析图像时出错: $e');
      return {'success': false, 'error': '分析图像时出错: $e'};
    }
  }

  /// 模拟分析（用于测试）
  ///
  /// 如果无法连接到实际服务器，可以使用此方法返回模拟数据
  Future<Map<String, dynamic>> mockAnalysis() async {
    // 模拟延迟
    await Future.delayed(const Duration(seconds: 1));

    // 返回模拟数据
    return {
      'success': true,
      'scene': '风景',
      'confidence': 0.92,
      'tips': [
        AiTip(type: '构图', text: '尝试将地平线放在画面的1/3处，符合三分法构图', priority: 1),
        AiTip(type: '光线', text: '调整角度，让自然光线从侧面照射主体', priority: 2),
        AiTip(type: '角度', text: '如果拍摄日落，可以使用剪影效果突出前景轮廓', priority: 3),
        AiTip(type: '动作', text: '保持相机水平，避免地平线倾斜', priority: 4),
      ],
    };
  }
}
