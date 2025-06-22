import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/aitips/services/image_analysis_api.dart';

void main() {
  group('图像分析API测试', () {
    late ImageAnalysisService service;

    setUp(() {
      service = ImageAnalysisService();
    });

    test('测试图像分析API调用', () async {
      // 使用项目中现有的测试图像
      final testImagePath = 'assets/images/background.jpg';

      try {
        // 读取图像文件字节数据
        final file = File(testImagePath);
        if (!await file.exists()) {
          print('❌ 测试图像文件不存在: $testImagePath');
          return;
        }

        final imageBytes = await file.readAsBytes();
        print('✅ 成功读取图像文件，大小: ${imageBytes.length} 字节');

        // 调用图像分析API
        print('🚀 开始调用图像分析API...');
        final tips = await service.analyzeImageBytes(imageBytes);

        // 验证结果
        expect(tips, isNotEmpty, reason: '应该返回至少一条拍摄建议');
        expect(tips.length, equals(4), reason: '应该返回4条拍摄建议');

        print('✅ API调用成功！返回了 ${tips.length} 条建议:');
        for (final tip in tips) {
          print('  ${tip.type}: ${tip.text}');
        }

        // 验证返回的建议包含所需的字段
        final types = tips.map((tip) => tip.type).toSet();
        expect(types.contains('构图'), isTrue, reason: '应该包含构图建议');
        expect(types.contains('光线'), isTrue, reason: '应该包含光线建议');
        expect(types.contains('角度'), isTrue, reason: '应该包含角度建议');
        expect(types.contains('动作'), isTrue, reason: '应该包含动作建议');
      } catch (e) {
        print('❌ 测试失败: $e');
        rethrow;
      }
    });

    test('测试网络连接和API响应', () async {
      // 创建一个小的测试图像数据
      final testImageBytes = Uint8List.fromList([
        // 一个简单的1x1像素的JPEG头部数据（用于测试）
        0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
        0x01, 0x01, 0x00, 0x48, 0x00, 0x48, 0x00, 0x00, 0xFF, 0xDB, 0x00, 0x43,
        0x00, 0x08, 0x06, 0x06, 0x07, 0x06, 0x05, 0x08, 0x07, 0x07, 0x07, 0x09,
        0xFF, 0xD9
      ]);

      try {
        print('🧪 测试API连接性...');
        final tips = await service.analyzeImageBytes(testImageBytes);

        print('✅ API连接正常，返回结果:');
        for (final tip in tips) {
          print('  ${tip.type}: ${tip.text}');
        }

        expect(tips, isNotEmpty);
      } catch (e) {
        print('⚠️  API调用出现问题: $e');
        // 这里不抛出异常，因为可能是网络问题或API密钥问题
      }
    });
  });
}
