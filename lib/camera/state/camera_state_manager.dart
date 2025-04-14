import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../services/native_camera_service.dart';
import 'dart:async';

/// 全局相机状态管理器
class CameraStateManager extends ChangeNotifier {
  // 单例实例
  static final CameraStateManager _instance = CameraStateManager._internal();
  static CameraStateManager get instance => _instance;

  // 私有构造函数确保单例模式
  CameraStateManager._internal();

  // 相机初始化状态
  bool _isCameraInitialized = false;
  String _currentCameraType = 'back'; // 默认使用后置相机
  bool _isProcessingCameraChange = false;

  // 相机控制状态
  bool _isFlashOn = false;
  String _flashMode = 'auto'; // 闪光灯模式: 'auto' 或 'off'
  double _currentZoomLevel = 1.0;
  final ValueNotifier<double> currentZoomLevelNotifier =
      ValueNotifier<double>(1.0);
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 3.0;
  bool _showGridLines = false; // 确保默认关闭网格线
  String _currentAspectRatio = '4:3';
  bool _isAspectRatioControlExpanded = false; // 拍摄比例控制面板是否展开
  bool _isExposureControlExpanded = false; // 曝光控制面板是否展开
  double _baseScaleLevel = 1.0;
  bool _isCameraChanging = false;
  Map<String, dynamic> _cameraCapabilities = {};
  double _currentExposureValue = 0.0;
  double _minExposureValue = -2.0;
  double _maxExposureValue = 2.0;

  // Getters
  bool get isCameraInitialized => _isCameraInitialized;
  String get currentCameraType => _currentCameraType;
  bool get isProcessingCameraChange => _isProcessingCameraChange;
  bool get isFlashOn => _isFlashOn;
  String get flashMode => _flashMode;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;
  bool get showGridLines => _showGridLines;
  String get currentAspectRatio => _currentAspectRatio;
  bool get isAspectRatioControlExpanded => _isAspectRatioControlExpanded;
  bool get isExposureControlExpanded => _isExposureControlExpanded;
  double get baseScaleLevel => _baseScaleLevel;
  bool get isCameraChanging => _isCameraChanging;
  Map<String, dynamic> get cameraCapabilities => _cameraCapabilities;
  double get currentExposureValue => _currentExposureValue;
  double get minExposureValue => _minExposureValue;
  double get maxExposureValue => _maxExposureValue;

  // Setters
  set isCameraInitialized(bool value) {
    _isCameraInitialized = value;
    notifyListeners();
  }

  set currentCameraType(String value) {
    _currentCameraType = value;
    notifyListeners();
  }

  set isProcessingCameraChange(bool value) {
    _isProcessingCameraChange = value;
    notifyListeners();
  }

  set isFlashOn(bool value) {
    _isFlashOn = value;
    notifyListeners();
  }

  set flashMode(String value) {
    if (value == 'auto' || value == 'off') {
      _flashMode = value;
      notifyListeners();
    }
  }

  set currentZoomLevel(double value) {
    if (value < _minZoomLevel) {
      value = _minZoomLevel;
    } else if (value > _maxZoomLevel) {
      value = _maxZoomLevel;
    }
    _currentZoomLevel = value;
    currentZoomLevelNotifier.value = value;
    notifyListeners();
  }

  set minZoomLevel(double value) {
    _minZoomLevel = value;
    notifyListeners();
  }

  set maxZoomLevel(double value) {
    _maxZoomLevel = value;
    notifyListeners();
  }

  set showGridLines(bool value) {
    _showGridLines = value;
    debugPrint('网格线显示状态切换为: ${_showGridLines ? '开启' : '关闭'}');
    notifyListeners();
  }

  set currentAspectRatio(String value) {
    _currentAspectRatio = value;
    notifyListeners();
  }

  set isAspectRatioControlExpanded(bool value) {
    _isAspectRatioControlExpanded = value;
    // 确保同一时间只有一个控制面板展开
    if (value) {
      _isExposureControlExpanded = false;
    }
    notifyListeners();
  }

  set isExposureControlExpanded(bool value) {
    _isExposureControlExpanded = value;
    // 确保同一时间只有一个控制面板展开
    if (value) {
      _isAspectRatioControlExpanded = false;
    }
    notifyListeners();
  }

  set baseScaleLevel(double value) {
    _baseScaleLevel = value;
    notifyListeners();
  }

  set isCameraChanging(bool value) {
    _isCameraChanging = value;
    notifyListeners();
  }

  set cameraCapabilities(Map<String, dynamic> value) {
    _cameraCapabilities = value;
    notifyListeners();
  }

  set currentExposureValue(double value) {
    if (value < _minExposureValue) {
      value = _minExposureValue;
    } else if (value > _maxExposureValue) {
      value = _maxExposureValue;
    }
    _currentExposureValue = value;
    notifyListeners();
  }

  set minExposureValue(double value) {
    _minExposureValue = value;
    notifyListeners();
  }

  set maxExposureValue(double value) {
    _maxExposureValue = value;
    notifyListeners();
  }

  // 切换闪光灯状态
  Future<void> toggleFlash() async {
    // 在auto和off之间切换
    final newMode = _flashMode == 'auto' ? 'off' : 'auto';
    debugPrint('切换闪光灯模式: 从 $_flashMode 到 $newMode');

    try {
      final cameraController =
          NativeCameraService.instance.getGlobalCameraController();
      if (cameraController != null) {
        debugPrint('调用原生方法设置闪光灯模式: $newMode');
        final success = await cameraController.setFlashMode(newMode);
        debugPrint('设置闪光灯模式结果: $success');

        if (success) {
          _flashMode = newMode;
          _isFlashOn = newMode == 'auto'; // auto模式下isFlashOn为true，off模式下为false
          debugPrint('更新闪光灯状态: mode=$_flashMode, isOn=$_isFlashOn');
          notifyListeners();
        } else {
          debugPrint('设置闪光灯模式失败');
        }
      } else {
        debugPrint('相机控制器为空，无法设置闪光灯模式');
      }
    } catch (e) {
      debugPrint('切换闪光灯模式时出错: $e');
    }
  }

  // 切换网格线显示
  void toggleGridLines() {
    _showGridLines = !_showGridLines;
    debugPrint('网格线显示状态切换为: ${_showGridLines ? '开启' : '关闭'}');
    notifyListeners();
  }

  // 循环切换拍摄比例
  void toggleAspectRatio() {
    // 循环切换可用比例：4:3 -> 1:1 -> 16:9 -> 4:3
    final ratios = ['4:3', '1:1', '16:9'];
    final currentIndex = ratios.indexOf(_currentAspectRatio);
    final nextIndex = (currentIndex + 1) % ratios.length;
    _currentAspectRatio = ratios[nextIndex];
    notifyListeners();
  }

  /// 初始化相机设置
  /// 获取设备支持的相机参数并设置默认值
  Future<void> initializeCameraSettings() async {
    if (_isCameraInitialized) return; // 如果已初始化，直接返回

    try {
      // 获取相机能力
      final capabilities =
          await NativeCameraService.instance.getCameraCapabilities();

      debugPrint('获取到的相机能力: $capabilities');

      // 更新相机能力信息
      _cameraCapabilities = capabilities;

      // 获取原始相机类型列表
      final rawCameraTypes = _getRawCameraTypes();
      debugPrint('获取到的原始相机类型: $rawCameraTypes');

      // 检查是否支持超广角
      final hasUltraWide = rawCameraTypes.contains('ultraWide');
      debugPrint('是否支持超广角: $hasUltraWide');

      // 设置缩放范围（如果支持超广角，则下限可设为0.5）
      _minZoomLevel = hasUltraWide ? 0.5 : 1.0;
      debugPrint('设置缩放下限为: $_minZoomLevel');

      // 设置默认相机类型（优先使用后置相机）
      List<String> availableCameras = _getAvailableCameras();
      debugPrint('获取到的相机类型: $availableCameras');

      if (availableCameras.contains('back')) {
        _currentCameraType = 'back';
        debugPrint('使用后置相机作为默认相机');
      } else if (availableCameras.isNotEmpty) {
        _currentCameraType = availableCameras.first;
        debugPrint('使用第一个可用相机作为默认相机: $_currentCameraType');
      } else {
        debugPrint('没有可用的相机，仍然使用默认值: back');
      }

      // 设置默认拍摄比例
      _currentAspectRatio = capabilities['defaultAspectRatio'] ?? '4:3';

      // 设置缩放范围
      _maxZoomLevel = capabilities['maxZoomLevel']?.toDouble() ?? 3.0;
      // 默认缩放比例固定为 1.0，无论设备是否支持超广角
      _currentZoomLevel = 1.0;
      currentZoomLevelNotifier.value = _currentZoomLevel; // 确保初始值正确
      debugPrint('设置默认缩放比例为: 1.0');

      // 设置曝光范围
      _minExposureValue = capabilities['minExposureValue']?.toDouble() ?? -2.0;
      _maxExposureValue = capabilities['maxExposureValue']?.toDouble() ?? 2.0;
      _currentExposureValue = 0.0; // 默认曝光值

      // 设置默认闪光灯模式
      _flashMode = 'auto';
      _isFlashOn = true;
      final cameraController =
          NativeCameraService.instance.getGlobalCameraController();
      if (cameraController != null) {
        await cameraController.setFlashMode(_flashMode);
      }

      // 标记初始化完成
      _isCameraInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('初始化相机设置时出错: $e');
    }
  }

  /// 获取原始的相机类型列表（包括wide, ultraWide, telephoto等）
  List<String> _getRawCameraTypes() {
    // 从supportedCameraTypes字段获取
    final camerasData = _cameraCapabilities['supportedCameraTypes'];
    if (camerasData == null || !(camerasData is List)) {
      // 尝试从cameraTypes字段获取（向后兼容）
      final oldCamerasData = _cameraCapabilities['cameraTypes'];
      if (oldCamerasData == null || !(oldCamerasData is List)) {
        debugPrint('未找到相机类型信息，使用默认值: [wide]');
        return ['wide']; // 默认值
      }
      return List<String>.from(oldCamerasData);
    }
    return List<String>.from(camerasData);
  }

  /// 获取可用的相机类型列表
  List<String> _getAvailableCameras() {
    // 首先尝试从supportedCameraTypes字段获取
    final camerasData = _cameraCapabilities['supportedCameraTypes'];
    if (camerasData == null || !(camerasData is List)) {
      // 然后尝试从cameraTypes字段获取（向后兼容）
      final oldCamerasData = _cameraCapabilities['cameraTypes'];
      if (oldCamerasData == null || !(oldCamerasData is List)) {
        debugPrint('未找到相机类型信息，使用默认值: [back]');
        return ['back']; // 默认值
      }
      return List<String>.from(oldCamerasData);
    }

    // 将原生相机类型转换为Flutter端使用的类型
    final List<dynamic> nativeCameraTypes = camerasData;
    final Set<String> mappedCameraTypes = {};

    for (final cameraType in nativeCameraTypes) {
      if (cameraType == 'front') {
        mappedCameraTypes.add('front');
      } else if (cameraType == 'wide' ||
          cameraType == 'ultraWide' ||
          cameraType == 'telephoto') {
        // 所有后置相机类型都映射为'back'
        mappedCameraTypes.add('back');
      }
    }

    debugPrint('可用相机类型: $mappedCameraTypes');

    // 确保至少有一个相机类型
    if (mappedCameraTypes.isEmpty) {
      return ['back']; // 默认值
    }

    return mappedCameraTypes.toList();
  }

  /// 获取可用的相机类型列表（公开方法）
  List<String> getAvailableCameras() {
    return _getAvailableCameras();
  }

  /// 切换相机（前置/后置）
  Future<void> switchCamera() async {
    debugPrint('调用switchCamera方法');
    debugPrint('当前相机类型: $_currentCameraType');

    List<String> availableCameras = _getAvailableCameras();
    debugPrint('可用相机类型: $availableCameras, 数量: ${availableCameras.length}');

    if (_isProcessingCameraChange) {
      debugPrint('相机切换已在进行中，忽略本次请求');
      return; // 防止多次点击
    }

    _isProcessingCameraChange = true;
    notifyListeners();
    debugPrint('开始切换相机');

    try {
      if (availableCameras.length <= 1) {
        // 只有一个相机，无法切换
        debugPrint('只有一个相机可用，无法切换');
        _isProcessingCameraChange = false;
        notifyListeners();
        return;
      }

      // 切换相机类型
      final isFront = _currentCameraType == 'front';
      final toFront = !isFront;
      debugPrint(
          '当前相机: ${isFront ? "前置" : "后置"}, 切换至: ${toFront ? "前置" : "后置"}');

      // 获取相机控制器
      final cameraController =
          NativeCameraService.instance.getGlobalCameraController();
      if (cameraController != null) {
        // 切换相机
        debugPrint('调用原生方法切换相机');
        final success = await cameraController.switchCamera(toFront: toFront);
        debugPrint('切换相机结果: $success');

        if (success) {
          _currentCameraType = toFront ? 'front' : 'back';
          debugPrint('相机类型已更新: $_currentCameraType');

          // 在事件处理时会将isProcessingCameraChange设为false
          // 如果没有收到事件，5秒后自动重置状态
          Future.delayed(const Duration(seconds: 5), () {
            if (_isProcessingCameraChange) {
              debugPrint('未收到相机切换完成事件，自动重置状态');
              _isProcessingCameraChange = false;
              notifyListeners();
            }
          });
        } else {
          // 切换失败，重置状态
          debugPrint('切换相机失败');
          _isProcessingCameraChange = false;
          notifyListeners();
        }
      } else {
        debugPrint('相机控制器为空，无法切换相机');
        _isProcessingCameraChange = false;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('切换相机时出错: $e');
      _isProcessingCameraChange = false;
      notifyListeners();
    }
  }

  /// 设置曝光值
  Future<void> setExposure(double value) async {
    // 确保值在范围内
    if (value < _minExposureValue) {
      value = _minExposureValue;
    } else if (value > _maxExposureValue) {
      value = _maxExposureValue;
    }

    try {
      final cameraController =
          NativeCameraService.instance.getGlobalCameraController();
      if (cameraController != null) {
        // 调用原生方法设置曝光值
        final success = await cameraController.setExposureLevel(value);
        if (success) {
          debugPrint('设置曝光值成功: $value');
        } else {
          debugPrint('设置曝光值失败');
        }

        // 无论原生调用是否成功，更新本地状态
        _currentExposureValue = value;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('设置曝光值时出错: $e');
    }
  }

  /// 设置缩放级别
  Future<void> setZoom(double value) async {
    // 确保值在范围内
    if (value < _minZoomLevel) {
      value = _minZoomLevel;
    } else if (value > _maxZoomLevel) {
      value = _maxZoomLevel;
    }

    // 判断是否切换相机类型
    bool isCameraTypeChange = (value < 1.0 && _currentZoomLevel >= 1.0) ||
        (_currentZoomLevel < 1.0 && value >= 1.0);

    if (isCameraTypeChange) {
      // 如果正在切换，则忽略新的请求以防止冲突
      if (_isCameraChanging) {
        debugPrint('相机正在切换中，忽略新的缩放请求: $value');
        return;
      }
      // 设置相机变化状态
      _isCameraChanging = true;
      notifyListeners();
      debugPrint('相机类型变换开始: 目标缩放 $value');
    }

    try {
      final cameraController =
          NativeCameraService.instance.getGlobalCameraController();
      if (cameraController != null) {
        // 直接调用原生方法，不再使用超时
        final success = await cameraController.setSystemLikeZoom(value);

        if (success) {
          // 注意：只在原生调用成功时更新本地缩放值
          // isCameraChanging 状态由原生事件回调重置
          _currentZoomLevel = value;
          currentZoomLevelNotifier.value = value;
          notifyListeners();
          debugPrint('原生setSystemLikeZoom调用成功，请求缩放: $value');
        } else {
          debugPrint('原生setSystemLikeZoom调用失败');
          // 如果原生调用失败，重置 isCameraChanging 状态
          if (isCameraTypeChange) {
            _isCameraChanging = false;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint('设置缩放级别时出错: $e');
      // 出错时也重置 isCameraChanging 状态
      if (isCameraTypeChange) {
        _isCameraChanging = false;
        notifyListeners();
      }
    }
    // finally 块被移除，isCameraChanging 由事件或错误处理重置
  }

  /// 设置拍摄比例
  void setAspectRatio(String ratio) {
    if (['4:3', '1:1', '16:9'].contains(ratio)) {
      _currentAspectRatio = ratio;
      notifyListeners();
    }
  }

  /// 重置所有相机设置为默认值
  Future<void> resetToDefaults() async {
    _isFlashOn = true;
    _flashMode = 'auto';
    _currentZoomLevel = 1.0;
    currentZoomLevelNotifier.value = _currentZoomLevel;
    _showGridLines = false;
    _currentAspectRatio = '4:3';
    _currentExposureValue = 0.0;

    // 应用设置到相机
    final cameraController =
        NativeCameraService.instance.getGlobalCameraController();
    if (cameraController != null) {
      await cameraController.setFlashMode(_flashMode);
      await cameraController.setSystemLikeZoom(_currentZoomLevel);
    }

    notifyListeners();
  }
}
