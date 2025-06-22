import 'package:flutter/material.dart';
import '../models/ai_tip.dart';

/// AI拍摄建议卡片组件
/// 用于显示单个拍摄建议的详细内容
class AiTipCard extends StatelessWidget {
  /// 拍摄建议
  final AiTip tip;

  /// 关闭回调
  final VoidCallback onClose;

  const AiTipCard({Key? key, required this.tip, required this.onClose})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width * 0.8,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _getTipColor(tip.type),
                ),
                child: Center(
                  child: Text(
                    tip.type,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${tip.type}建议',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: onClose),
            ],
          ),
          const Divider(),
          // 内容
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(tip.text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  // 根据tip类型获取颜色
  Color _getTipColor(String type) {
    switch (type) {
      case '构图':
        return Colors.blue;
      case '光线':
        return Colors.orange;
      case '角度':
        return Colors.green;
      case '动作':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
