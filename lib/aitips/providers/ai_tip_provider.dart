import 'package:flutter/foundation.dart';
import 'package:haohaopai/aitips/models/ai_tip.dart';
import 'package:haohaopai/aitips/models/shooting_tip.dart';
import 'package:haohaopai/aitips/services/ai_tip_service.dart';

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
class AiTipProvider with ChangeNotifier {
  final _aiTipService = AiTipService();

  // 用于检查Provider是否已被销毁
  bool _disposed = false;

  // 当前状态
  AiTipState _state = AiTipState.initial;
  AiTipState get state => _state;

  // 拍摄建议列表
  List<ShootingTip> _tips = [];
  List<ShootingTip> get tips => _tips;

  // 错误信息
  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  // 是否正在分析
  bool get isAnalyzing => _state == AiTipState.analyzing;

  // 是否正在进行教我拍流程
  bool get isProcessing => isAnalyzing || _tips.isNotEmpty;

  /// 分析图像并获取拍摄建议
  Future<void> analyzeImage(Uint8List imageBytes) async {
    if (isProcessing) return;

    try {
      // 重置之前的数据
      _tips.clear();
      _errorMessage = '';

      // 更新状态为分析中
      _setState(AiTipState.analyzing);

      debugPrint('📸 教我拍流程开始 - 状态已设置为分析中');
      debugPrint('📸 图像数据大小: ${imageBytes.length} 字节');

      // 获取拍摄建议（传递截图数据）
      final result = await _aiTipService.getCaptureTips(imageBytes);

      if (result['success'] == true) {
        // 解析结果
        final tipsListRaw = result['tips'] as List<dynamic>;
        _tips = tipsListRaw.map((tip) {
          if (tip is AiTip) {
            // 如果是AiTip，转换为ShootingTip
            return ShootingTip(
                type: tip.type, text: tip.text, priority: tip.priority);
          } else {
            // 如果是其他类型（比如Map），先转换为AiTip再转换为ShootingTip
            final aiTip = AiTip.fromJson(tip);
            return ShootingTip(
                type: aiTip.type, text: aiTip.text, priority: aiTip.priority);
          }
        }).toList();

        debugPrint('📸 成功获取${_tips.length}条拍摄建议');

        // 更新状态为显示建议
        _setState(AiTipState.showingTips);
      } else {
        // 处理错误
        _errorMessage = result['error'] as String? ?? '未知错误';
        _setState(AiTipState.error);
        debugPrint('📸 获取拍摄建议失败: $_errorMessage');
      }
    } catch (e) {
      // 处理异常
      _errorMessage = '分析图像时出错: $e';
      _setState(AiTipState.error);
      debugPrint('📸 教我拍流程异常: $_errorMessage');
    }
  }

  /// 关闭拍摄建议
  void dismissTips() {
    _tips.clear();
    _setState(AiTipState.initial);
  }

  /// 强制停止当前流程
  void forceStop() {
    reset();
  }

  /// 重置状态
  void reset() {
    if (_disposed) return; // 如果已销毁，不更新状态
    _state = AiTipState.initial;
    _tips.clear();
    _errorMessage = '';
    notifyListeners();
  }

  /// 设置状态
  void _setState(AiTipState newState) {
    if (_disposed) return; // 如果已销毁，不更新状态
    _state = newState;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
