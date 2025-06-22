import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../../aitips/providers/ai_tip_provider.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';

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

    // Capture screenshot
    RenderRepaintBoundary boundary = cameraPreviewKey.currentContext!
        .findRenderObject() as RenderRepaintBoundary;
    ui.Image image = await boundary.toImage(pixelRatio: 1.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final buffer = byteData!.buffer.asUint8List();
    image.dispose();

    // 开始分析图像
    debugPrint('💡 开始教我拍流程');
    aiTipProvider.analyzeImage(buffer);
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
