import 'package:flutter/foundation.dart';

/// AI拍摄建议模型
/// 表示从服务器返回的单条拍摄建议
class AiTip {
  /// 建议类型（如构图、光线、角度、动作等）
  final String type;

  /// 建议内容
  final String text;

  /// 优先级（用于排序显示）
  final int priority;

  const AiTip({required this.type, required this.text, required this.priority});

  /// 从JSON创建AiTip对象
  factory AiTip.fromJson(Map<String, dynamic> json) {
    return AiTip(
      type: json['type'] as String,
      text: json['text'] as String,
      priority: json['priority'] as int,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {'type': type, 'text': text, 'priority': priority};
  }

  @override
  String toString() {
    return 'AiTip{type: $type, text: $text, priority: $priority}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AiTip &&
        other.type == type &&
        other.text == text &&
        other.priority == priority;
  }

  @override
  int get hashCode => Object.hash(type, text, priority);
}
