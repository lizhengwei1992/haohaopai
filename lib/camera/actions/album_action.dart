import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 相册操作组件
class AlbumAction extends StatelessWidget {
  const AlbumAction({Key? key}) : super(key: key);

  // 打开相册
  void openAlbum(BuildContext context) {
    // TODO: 实现打开相册功能
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('打开相册功能尚未实现')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => openAlbum(context),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFFA0A9FC),
            width: 1.5,
          ),
        ),
        child: Center(
          child: SvgPicture.asset(
            'assets/icons/photo_album.svg',
            width: 45,
            height: 45,
          ),
        ),
      ),
    );
  }
}
