import 'package:flutter/material.dart';

class CameraControls extends StatelessWidget {
  final VoidCallback onTeachPress;
  final VoidCallback onCapturePress;
  final bool showingTips;

  const CameraControls({
    super.key,
    required this.onTeachPress,
    required this.onCapturePress,
    required this.showingTips,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: Center(
              child: ElevatedButton(
                onPressed: showingTips ? onCapturePress : onTeachPress,
                style: ElevatedButton.styleFrom(
                  backgroundColor: showingTips ? Colors.green : Colors.blue,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
                child: Text(
                  showingTips ? '立即拍摄' : '教我拍',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
