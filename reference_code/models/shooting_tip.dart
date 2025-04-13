class ShootingTip {
  final String type;
  final String text;
  final int priority;

  ShootingTip({
    required this.type,
    required this.text,
    required this.priority,
  });

  factory ShootingTip.fromJson(Map<String, dynamic> json) {
    return ShootingTip(
      type: json['type'] as String,
      text: json['text'] as String,
      priority: json['priority'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'text': text,
      'priority': priority,
    };
  }
}
