import 'package:flutter/material.dart';

class TipsOverlay extends StatelessWidget {
  final VoidCallback onDismiss;

  const TipsOverlay({
    Key? key,
    required this.onDismiss,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: GestureDetector(
        onTap: onDismiss,
        child: Container(
          color: Colors.black.withOpacity(0.7),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.symmetric(horizontal: 30),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '相机操作提示',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildTipItem(
                      icon: Icons.zoom_in,
                      text: '捏合缩放或使用缩放控制器调整焦距',
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.touch_app,
                      text: '点击屏幕对焦',
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.camera_alt,
                      text: '在iOS设备上，支持智能切换多个摄像头',
                    ),
                    const SizedBox(height: 12),
                    _buildTipItem(
                      icon: Icons.camera_enhance,
                      text: '0.5x到5x之间缩放时，会自动切换物理摄像头',
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: onDismiss,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 45),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('我知道了'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTipItem({required IconData icon, required String text}) {
    return Row(
      children: [
        Icon(icon, size: 24, color: Colors.blue),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 14),
          ),
        ),
      ],
    );
  }
}
