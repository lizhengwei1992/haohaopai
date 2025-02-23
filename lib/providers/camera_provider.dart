import 'package:flutter/material.dart';
import '../services/image_analysis_service.dart';

class CameraProvider with ChangeNotifier {
  final List<ShootingTip> _tips = [];
  List<ShootingTip> get tips => _tips;

  final _imageAnalysisService = ImageAnalysisService();

  Future<void> analyzeImage(String imagePath) async {
    try {
      final tips = await _imageAnalysisService.analyzeImage(imagePath);
      _tips.clear();
      _tips.addAll(tips);
      notifyListeners();
    } catch (e) {
      debugPrint(e.toString());
      rethrow;
    }
  }
}
