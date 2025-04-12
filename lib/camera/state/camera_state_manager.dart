import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../controls/filter_control.dart';

/// 全局相机状态管理器
class CameraStateManager extends ChangeNotifier {
  // 单例实例
  static final CameraStateManager _instance = CameraStateManager._internal();
  static CameraStateManager get instance => _instance;

  // 私有构造函数确保单例模式
  CameraStateManager._internal();

  // 相机控制状态
  bool _isFlashOn = false;
  double _currentZoomLevel = 1.0;
  double _minZoomLevel = 1.0;
  double _maxZoomLevel = 3.0;
  bool _showGridLines = false;
  String _currentAspectRatio = '4:3';
  FilterType _currentFilter = FilterType.none;
  bool _showFilterSelector = false;
  double _baseScaleLevel = 1.0;
  bool _isCameraChanging = false;
  Map<String, dynamic> _cameraCapabilities = {};

  // 焦点相关
  Offset? _focusPoint;
  bool _showFocusPoint = false;
  bool _focusSuccess = false;

  // Getters
  bool get isFlashOn => _isFlashOn;
  double get currentZoomLevel => _currentZoomLevel;
  double get minZoomLevel => _minZoomLevel;
  double get maxZoomLevel => _maxZoomLevel;
  bool get showGridLines => _showGridLines;
  String get currentAspectRatio => _currentAspectRatio;
  FilterType get currentFilter => _currentFilter;
  bool get showFilterSelector => _showFilterSelector;
  double get baseScaleLevel => _baseScaleLevel;
  bool get isCameraChanging => _isCameraChanging;
  Map<String, dynamic> get cameraCapabilities => _cameraCapabilities;
  Offset? get focusPoint => _focusPoint;
  bool get showFocusPoint => _showFocusPoint;
  bool get focusSuccess => _focusSuccess;

  // Setters
  set isFlashOn(bool value) {
    _isFlashOn = value;
    notifyListeners();
  }

  set currentZoomLevel(double value) {
    if (value < _minZoomLevel) {
      value = _minZoomLevel;
    } else if (value > _maxZoomLevel) {
      value = _maxZoomLevel;
    }
    _currentZoomLevel = value;
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
    notifyListeners();
  }

  set currentAspectRatio(String value) {
    _currentAspectRatio = value;
    notifyListeners();
  }

  set currentFilter(FilterType value) {
    _currentFilter = value;
    notifyListeners();
  }

  set showFilterSelector(bool value) {
    _showFilterSelector = value;
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

  set focusPoint(Offset? value) {
    _focusPoint = value;
    notifyListeners();
  }

  set showFocusPoint(bool value) {
    _showFocusPoint = value;
    notifyListeners();
  }

  set focusSuccess(bool value) {
    _focusSuccess = value;
    notifyListeners();
  }

  // 更新焦点
  void updateFocus(Offset? point, bool show, bool success) {
    _focusPoint = point;
    _showFocusPoint = show;
    _focusSuccess = success;
    notifyListeners();
  }

  // 隐藏焦点点
  void hideFocusPoint() {
    _showFocusPoint = false;
    notifyListeners();
  }

  // 切换闪光灯状态
  void toggleFlash() {
    _isFlashOn = !_isFlashOn;
    notifyListeners();
  }

  // 切换网格线显示
  void toggleGridLines() {
    _showGridLines = !_showGridLines;
    notifyListeners();
  }

  // 切换滤镜选择器显示
  void toggleFilterSelector() {
    _showFilterSelector = !_showFilterSelector;
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
}
