import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../aitips/providers/ai_tip_provider.dart';
import '../services/native_camera_service.dart';

/// 教我拍操作组件
class GuideAction extends StatelessWidget {
  final GlobalKey cameraPreviewKey;

  const GuideAction({Key? key, required this.cameraPreviewKey})
      : super(key: key);

  // 打开教我拍功能
  Future<void> openGuide(BuildContext context) async {
    // 获取AI提示提供者
    final aiTipProvider = Provider.of<AiTipProvider>(context, listen: false);

    debugPrint('💡 点击教我拍按钮');

    // 如果已经在处理中，不再重复执行
    if (aiTipProvider.isProcessing) {
      debugPrint('💡 教我拍按钮点击被忽略：当前已在处理中');
      return;
    }

    // 从原生相机捕获当前预览帧
    debugPrint('💡 开始从原生相机捕获预览帧');
    final imageBytes = await NativeCameraService.captureCurrentPreviewFrame();

    if (imageBytes == null) {
      debugPrint('💡 捕获预览帧失败：未获取到图像数据');
      // TODO: 可以在这里显示错误提示
      return;
    }

    debugPrint('💡 成功捕获预览帧，大小: ${imageBytes.length} 字节');

    // 开始分析图像
    debugPrint('💡 开始教我拍流程');
    aiTipProvider.analyzeImage(imageBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AiTipProvider>(
      builder: (context, provider, child) {
        // 根据处理状态决定按钮是否可点击及样式
        final bool isProcessing = provider.isProcessing;

        if (isProcessing) {
          debugPrint('💡 教我拍按钮状态: 处理中（不可点击）');
        }

        return GestureDetector(
          onTap: isProcessing ? null : () => openGuide(context),
          child: Container(
            width: 96,
            height: 96,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.transparent,
            ),
            child: Center(
              child: Opacity(
                opacity: isProcessing ? 0.5 : 1.0, // 处理中时降低透明度
                child: SvgPicture.asset(
                  'assets/icons/magic.svg',
                  width: 96,
                  height: 96,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
