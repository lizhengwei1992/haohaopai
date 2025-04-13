import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'native_camera_service.dart';

/// 教我拍功能服务类
/// 负责分析当前拍摄场景并提供拍摄建议
class TeachCaptureService {
  // 单例模式
  static final TeachCaptureService _instance = TeachCaptureService._internal();
  factory TeachCaptureService() => _instance;
  TeachCaptureService._internal();

  // 后端API服务器地址
  final String _apiBaseUrl = 'https://api.haohaopai.com';

  // 请求客户端
  final Dio _dio = Dio();

  /// 获取当前预览场景的拍摄建议
  ///
  /// 返回包含以下字段的Map：
  /// - success: 是否获取成功
  /// - tips: 拍摄建议列表
  /// - error: 错误信息（如果发生错误）
  Future<Map<String, dynamic>> getCaptureTips() async {
    try {
      // 1. 从相机捕获当前预览帧
      final imageData = await NativeCameraService.captureCurrentPreviewFrame();

      if (imageData == null) {
        return {'success': false, 'error': '无法获取当前预览帧'};
      }

      // 2. 将图像数据发送到服务器进行分析
      return await _analyzeImageWithServer(imageData);
    } catch (e) {
      debugPrint('获取拍摄建议时出错: $e');
      return {'success': false, 'error': '获取建议失败: $e'};
    }
  }

  /// 发送图像到服务器并获取分析结果
  Future<Map<String, dynamic>> _analyzeImageWithServer(
      Uint8List imageData) async {
    try {
      // 构建FormData，包含图像数据
      final formData = FormData.fromMap({
        'image': MultipartFile.fromBytes(
          imageData,
          filename: 'preview.jpg',
          contentType: MediaType('image', 'jpeg'),
        ),
      });

      // 发送请求
      final response = await _dio.post(
        '$_apiBaseUrl/teach-capture/analyze',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );

      // 3. 解析并返回服务器响应
      if (response.statusCode == 200) {
        final data = response.data;

        if (data['success'] == true) {
          // 成功获取拍摄建议
          return {
            'success': true,
            'tips': data['tips'] ?? [],
            'scene': data['scene'] ?? '未知场景',
            'confidence': data['confidence'] ?? 0.0,
          };
        } else {
          // 服务器返回了错误
          return {'success': false, 'error': data['message'] ?? '服务器分析错误'};
        }
      } else {
        // HTTP错误
        return {'success': false, 'error': '服务器响应错误: ${response.statusCode}'};
      }
    } on DioException catch (e) {
      // Dio请求异常
      return {'success': false, 'error': '网络请求失败: ${e.message}'};
    } catch (e) {
      // 其他异常
      return {'success': false, 'error': '分析图像时出错: $e'};
    }
  }

  /// 模拟分析（用于测试）
  ///
  /// 如果无法连接到实际服务器，可以使用此方法返回模拟数据
  Future<Map<String, dynamic>> _mockAnalysis() async {
    // 模拟延迟
    await Future.delayed(const Duration(seconds: 1));

    // 返回模拟数据
    return {
      'success': true,
      'scene': '风景',
      'confidence': 0.92,
      'tips': [
        '尝试将地平线放在画面的1/3处，符合三分法构图',
        '调整角度，让自然光线从侧面照射主体',
        '如果拍摄日落，可以使用剪影效果突出前景轮廓',
        '考虑使用广角镜头捕捉更广阔的景色',
        '保持相机水平，避免地平线倾斜'
      ]
    };
  }
}
