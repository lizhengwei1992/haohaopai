import 'package:flutter/material.dart';
import '../../services/index.dart';

class ShootingTips extends StatefulWidget {
  final bool isVisible;
  final VoidCallback? onClose;

  const ShootingTips({
    Key? key,
    this.isVisible = false,
    this.onClose,
  }) : super(key: key);

  @override
  State<ShootingTips> createState() => _ShootingTipsState();
}

class _ShootingTipsState extends State<ShootingTips>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  final TeachCaptureService _teachService = TeachCaptureService();
  bool _isLoading = false;
  bool _hasError = false;
  String _errorMessage = '';
  List<String> _tips = [];
  String _scene = '';

  @override
  void initState() {
    super.initState();

    // 创建动画控制器
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    // 创建动画
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    // 根据初始可见性设置动画状态
    if (widget.isVisible) {
      _animationController.value = 1.0;
    } else {
      _animationController.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(ShootingTips oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 当可见性发生变化时更新动画
    if (widget.isVisible != oldWidget.isVisible) {
      if (widget.isVisible) {
        _animationController.forward();
        // 当显示时，加载拍摄建议
        _loadShootingTips();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // 加载拍摄建议
  Future<void> _loadShootingTips() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = '';
    });

    try {
      // 调用教我拍服务获取建议
      final result = await _teachService.getCaptureTips();

      if (mounted) {
        setState(() {
          _isLoading = false;

          if (result['success'] == true) {
            _tips = List<String>.from(result['tips']);
            _scene = result['scene'] as String? ?? '未知场景';
            _hasError = false;
          } else {
            _hasError = true;
            _errorMessage = result['error'] as String? ?? '获取建议失败';
            _tips = [];
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _errorMessage = '获取建议时出错: $e';
          _tips = [];
        });
      }
    }
  }

  // 重新加载拍摄建议
  void _reloadTips() {
    _loadShootingTips();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Positioned(
          bottom: 100 + (1.0 - _animation.value) * 100,
          left: 20,
          right: 20,
          child: Opacity(
            opacity: _animation.value,
            child: child!,
          ),
        );
      },
      child: Card(
        color: Colors.black.withOpacity(0.7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb, color: Colors.yellow.shade300),
                      const SizedBox(width: 8),
                      Text(
                        _scene.isEmpty ? '拍摄建议' : '场景: $_scene',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // 重新加载按钮
                      IconButton(
                        icon: const Icon(Icons.refresh, color: Colors.white70),
                        onPressed: _isLoading ? null : _reloadTips,
                        tooltip: '重新获取建议',
                      ),
                      // 关闭按钮
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: widget.onClose,
                        tooltip: '关闭建议',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (_isLoading) ...[
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ] else if (_hasError) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Column(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.redAccent, size: 32),
                        const SizedBox(height: 8),
                        Text(
                          _errorMessage,
                          style: const TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                        TextButton(
                          onPressed: _reloadTips,
                          child: const Text('重试',
                              style: TextStyle(color: Colors.blueAccent)),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if (_tips.isEmpty) ...[
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(
                    child: Text(
                      '无法为当前场景提供建议',
                      style: TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ] else ...[
                const Divider(color: Colors.white24),
                const SizedBox(height: 8),
                for (int i = 0; i < _tips.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${i + 1}. ',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _tips[i],
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
