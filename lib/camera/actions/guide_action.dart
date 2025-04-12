import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 教我拍操作组件
class GuideAction extends StatelessWidget {
  const GuideAction({Key? key}) : super(key: key);

  // 打开教我拍功能
  void openGuide(BuildContext context) {
    // TODO: 实现打开教我拍功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开教我拍功能尚未实现')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openGuide(context),
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.transparent,
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/magic.svg',
            width: 96,
            height: 96,
          ),
        ),
      ),
    );
  }
}
