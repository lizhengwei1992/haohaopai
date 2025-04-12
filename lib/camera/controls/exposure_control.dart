import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 曝光控制组件
class ExposureControl extends StatelessWidget {
  const ExposureControl({Key? key}) : super(key: key);

  // 调整曝光
  void adjustExposure() {
    // TODO: 实现曝光控制
    debugPrint('曝光控制功能尚未实现');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: adjustExposure,
      child: Container(
        width: 45,
        height: 45,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color.fromRGBO(100, 100, 100, 0.35),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/exposure.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              Colors.white,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
