import 'package:flutter/foundation.dart';
import 'ai_tip.dart';

/// 拍摄建议模型
/// 用于图像分析API返回的拍摄建议
class ShootingTip {
  /// 建议类型（如构图、光线、角度、动作等）
  final String type;

  /// 建议内容
  final String text;

  /// 优先级（用于排序显示）
  final int priority;

  const ShootingTip(
      {required this.type, required this.text, required this.priority});

  /// 从JSON创建ShootingTip对象
  factory ShootingTip.fromJson(Map<String, dynamic> json) {
    return ShootingTip(
      type: json['type'] as String,
      text: json['text'] as String,
      priority: json['priority'] as int,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text, 'priority': priority};
  }

  /// 转换为AiTip
  AiTip toAiTip() {
    return AiTip(type: type, text: text, priority: priority);
  }

  @override
  String toString() {
    return 'ShootingTip{type: $type, text: $text, priority: $priority}';
  }
}
