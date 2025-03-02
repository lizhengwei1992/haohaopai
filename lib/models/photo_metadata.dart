import 'package:flutter/foundation.dart';

/// 照片元数据类
/// 存储照片的路径、拍摄时间和可选的地理位置信息
class PhotoMetadata {
  /// 照片文件路径
  final String path;

  /// 拍摄时间戳
  final DateTime timestamp;

  /// 可选的纬度
  final double? latitude;

  /// 可选的经度
  final double? longitude;

  /// 可选的位置描述
  final String? locationName;

  /// 系统相册中的ID
  final String? systemId;

  /// 是否由应用拍摄
  final bool isFromApp;

  /// 构造函数
  PhotoMetadata({
    required this.path,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.locationName,
    this.systemId,
    this.isFromApp = false,
  });

  /// 从JSON创建实例
  factory PhotoMetadata.fromJson(Map<String, dynamic> json) {
    return PhotoMetadata(
      path: json['path'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      locationName: json['locationName'] as String?,
      systemId: json['systemId'] as String?,
      isFromApp: json['isFromApp'] as bool? ?? false,
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'path': path,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'locationName': locationName,
      'systemId': systemId,
      'isFromApp': isFromApp,
    };
  }

  /// 创建副本并更新部分属性
  PhotoMetadata copyWith({
    String? path,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? locationName,
    String? systemId,
    bool? isFromApp,
  }) {
    return PhotoMetadata(
      path: path ?? this.path,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationName: locationName ?? this.locationName,
      systemId: systemId ?? this.systemId,
      isFromApp: isFromApp ?? this.isFromApp,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PhotoMetadata &&
        other.path == path &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => path.hashCode ^ timestamp.hashCode;
}
