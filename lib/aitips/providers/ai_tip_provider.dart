import 'package:flutter/foundation.dart';
import '../models/ai_tip.dart';
import '../services/ai_tip_service.dart';

/// AI拍摄建议状态
enum AiTipState {
  /// 初始状态
  initial,

  /// 正在分析图像
  analyzing,

  /// 显示拍摄建议
  showingTips,

  /// 发生错误
  error,
}

/// AI拍摄建议提供者
/// 负责管理教我拍功能的状态和数据
class AiTipProvider with ChangeNotifier {
  // 服务实例
  final _aiTipService = AiTipService();

  // 当前状态
  AiTipState _state = AiTipState.initial;
  AiTipState get state => _state;

  // 拍摄建议列表
  List<AiTip> _tips = [];
  List<AiTip> get tips => _tips;

  // 识别的场景
  String _scene = '';
  String get scene => _scene;

  // 置信度
  double _confidence = 0.0;
  double get confidence => _confidence;

  // 错误信息
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // 是否正在进行教我拍流程
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;

  /// 重置状态
  void reset() {
    _state = AiTipState.initial;
    _tips.clear();
    _scene = '';
    _confidence = 0.0;
    _errorMessage = '';
    _isProcessing = false;
    notifyListeners();
  }

  /// 设置状态
  void _setState(AiTipState newState) {
    _state = newState;
    notifyListeners();
  }

  /// 分析图像并获取拍摄建议
  Future<void> analyzeImage() async {
    try {
      // 重置之前的数据
      _tips.clear();
      _errorMessage = '';

      // 更新状态为分析中
      _setState(AiTipState.analyzing);
      _isProcessing = true;
      notifyListeners(); // 确保通知监听器状态变化

      debugPrint('📸 教我拍流程开始 - 状态已设置为分析中');

      // 获取拍摄建议
      debugPrint('📸 开始调用AI服务获取拍摄建议...');
      final startTime = DateTime.now();
      final result = await _aiTipService.getCaptureTips();
      final elapsedTime = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('📸 获取拍摄建议完成，耗时: ${elapsedTime}ms，结果: ${result['success']}');

      if (result['success'] == true) {
        // 解析结果
        final tipsList = result['tips'] as List<AiTip>;
        _tips = tipsList;
        _scene = result['scene'] as String? ?? '未知场景';
        _confidence = result['confidence'] as double? ?? 0.0;

        debugPrint('📸 成功获取${_tips.length}条拍摄建议:');
        for (final tip in _tips) {
          debugPrint('📸 - ${tip.type}: ${tip.text}');
        }

        // 更新状态为显示建议
        _setState(AiTipState.showingTips);
        debugPrint('📸 状态已更新为显示建议');

        // 设置一个定时器，在显示建议一段时间后自动完成
        // 这样用户可以看到建议，然后界面会自动恢复到正常状态
        Future.delayed(const Duration(seconds: 5), () {
          if (_state == AiTipState.showingTips) {
            debugPrint('📸 5秒后自动完成教我拍流程');
            complete();
          }
        });
      } else {
        // 处理错误
        _errorMessage = result['error'] as String? ?? '未知错误';
        _setState(AiTipState.error);
        debugPrint('📸 获取拍摄建议失败: $_errorMessage');

        // 重置处理状态
        _isProcessing = false;

        // 错误状态下，短暂显示后自动重置
        Future.delayed(const Duration(seconds: 3), () {
          if (_state == AiTipState.error) {
            debugPrint('📸 3秒后自动重置教我拍状态');
            reset();
          }
        });
      }
    } catch (e) {
      // 处理异常
      _errorMessage = '分析图像时出错: $e';
      _setState(AiTipState.error);
      debugPrint('📸 教我拍流程异常: $_errorMessage');

      // 重置处理状态
      _isProcessing = false;

      // 错误状态下，短暂显示后自动重置
      Future.delayed(const Duration(seconds: 3), () {
        if (_state == AiTipState.error) {
          debugPrint('📸 3秒后自动重置教我拍状态');
          reset();
        }
      });
    }

    notifyListeners();
  }

  /// 完成教我拍流程
  void complete() {
    _isProcessing = false;
    _setState(AiTipState.initial);
    notifyListeners();
  }

  /// 强制停止当前流程（用于页面切换等场景）
  void forceStop() {
    if (_state == AiTipState.analyzing || _isProcessing) {
      debugPrint('📸 强制停止教我拍流程 - 当前状态: $_state, 处理中: $_isProcessing');
    }

    // 完全重置所有状态，确保页面切换时干净
    debugPrint('📸 完全重置教我拍状态，确保页面切换时状态干净');
    reset();
  }

  /// 获取当前最重要的拍摄建议
  AiTip? get primaryTip {
    if (_tips.isEmpty) return null;

    // 按优先级排序并返回第一个
    final sortedTips = List<AiTip>.from(_tips);
    sortedTips.sort((a, b) => a.priority.compareTo(b.priority));
    return sortedTips.first;
  }
}
