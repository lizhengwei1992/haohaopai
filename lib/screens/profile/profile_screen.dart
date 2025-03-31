import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/camera_provider.dart';
import '../../login/auth_provider.dart';
import '../../login/login_page.dart';
import '../../screens/settings/settings_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String nickname = "昵称";
  String? avatarPath;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02051F),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          // 获取拍摄次数
          final shootingCount = cameraProvider.shootingCount;
          // 计算百分比（这里只是示意，实际计算可以后续实现）
          final percentage = 25.0; // 假设剩余25%

          return SingleChildScrollView(
            child: Column(
              children: [
                // 顶部带背景图的部分
                _buildHeaderSection(shootingCount, percentage),

                // 相册部分
                _buildPhotoGallerySection(cameraProvider),
              ],
            ),
          );
        },
      ),
    );
  }

  // 顶部带背景的部分
  Widget _buildHeaderSection(int shootingCount, double percentage) {
    // 计算设备尺寸以更好地适配
    final screenHeight = MediaQuery.of(context).size.height;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // 动态计算header高度，但不超过屏幕的一定比例
    final headerHeight = (screenHeight * 0.35).clamp(220.0, 280.0);

    return SizedBox(
      height: headerHeight,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片
          Image.asset(
            'assets/images/background.jpg',
            fit: BoxFit.cover,
          ),

          // 内容层
          Positioned.fill(
            child: Column(
              children: [
                // 状态栏高度
                SizedBox(height: statusBarHeight),

                // 头像、昵称和设置按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 24, 0),
                  child: Row(
                    children: [
                      // 头像
                      GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 50, // 缩小尺寸
                          height: 50, // 缩小尺寸
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.withOpacity(0.5),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.8), width: 2),
                            image: avatarPath != null
                                ? DecorationImage(
                                    image: FileImage(File(avatarPath!)),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                          ),
                          child: avatarPath == null
                              ? const Center(
                                  child: Text(
                                    "点击编辑",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                    ),
                                  ),
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(width: 14),

                      // 昵称
                      GestureDetector(
                        onTap: _editNickname,
                        child: Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 18, // 缩小字体
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),

                      const Spacer(),

                      // 设置按钮
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const SettingsScreen()),
                          );
                        },
                        child: SvgPicture.asset(
                          'assets/icons/setting.svg',
                          width: 24, // 略微缩小
                          height: 24, // 略微缩小
                          colorFilter: const ColorFilter.mode(
                              Colors.white, BlendMode.srcIn),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 余额和剩余次数显示区域
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16), // 减少顶部外边距
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12), // 缩小内边距
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      // 左侧显示百分比圆环 - 更立体的效果
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 60, // 进一步缩小
                            height: 60, // 进一步缩小
                            child: Stack(
                              children: [
                                // 中心黑色圆
                                Center(
                                  child: Container(
                                    width: 50, // 进一步缩小
                                    height: 50, // 进一步缩小
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.black,
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.5),
                                          spreadRadius: 1,
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                // 主要进度圆环
                                Center(
                                  child: SizedBox(
                                    width: 60, // 进一步缩小
                                    height: 60, // 进一步缩小
                                    child: CircularProgressIndicator(
                                      value: percentage / 100,
                                      backgroundColor:
                                          Colors.grey.withOpacity(0.3),
                                      valueColor:
                                          const AlwaysStoppedAnimation<Color>(
                                              Color(0xFF69BDFC)),
                                      strokeWidth: 6, // 减小宽度
                                      strokeCap: StrokeCap.round,
                                    ),
                                  ),
                                ),
                                // 内部数字显示
                                Center(
                                  child: Text(
                                    "$shootingCount",
                                    style: const TextStyle(
                                      fontSize: 20, // 进一步缩小字体
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4), // 减小间距
                          // 剩余次数文字显示
                          const Text(
                            "剩余次数",
                            style: TextStyle(
                              fontSize: 10, // 缩小字体
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),

                      // 中间的分隔线 - 加粗
                      Container(
                        height: 60, // 减少高度
                        width: 2, // 加粗的分隔线
                        margin:
                            const EdgeInsets.symmetric(horizontal: 20), // 减少间距
                        color: Colors.white.withOpacity(0.5),
                      ),

                      // 右侧显示账户余额和充值按钮
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min, // 确保不会超出父视图
                          children: [
                            const Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  "¥",
                                  style: TextStyle(
                                    fontSize: 18, // 缩小字体
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  "0.69",
                                  style: TextStyle(
                                    fontSize: 26, // 缩小字体
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4), // 减小间距
                            const Text(
                              "账户余额",
                              style: TextStyle(
                                fontSize: 12, // 缩小字体
                                color: Colors.white70,
                              ),
                            ),
                            const SizedBox(height: 10), // 减少间距
                            SizedBox(
                              width: double.infinity,
                              height: 32, // 降低高度
                              child: ElevatedButton(
                                onPressed: () {
                                  // 充值功能
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('充值功能即将上线')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      const Color(0xFFCD923D), // 橙色按钮
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(100, 28), // 缩小按钮
                                  padding: EdgeInsets.zero, // 去掉内边距
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(16), // 减小圆角
                                  ),
                                ),
                                child: const Text('充值',
                                    style: TextStyle(fontSize: 13)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 相册部分
  Widget _buildPhotoGallerySection(CameraProvider cameraProvider) {
    final recentPhotos = cameraProvider.recentPhotos;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Text(
            "相册",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        recentPhotos.isEmpty
            ? Container(
                height: 200,
                alignment: Alignment.center,
                child: const Text(
                  "暂无照片",
                  style: TextStyle(color: Colors.white70),
                ),
              )
            : GridView.count(
                physics: const NeverScrollableScrollPhysics(),
                shrinkWrap: true,
                crossAxisCount: 3,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
                children: recentPhotos.map((photo) {
                  return _buildPhotoItem(photo.path);
                }).toList(),
              ),
        const SizedBox(height: 20), // 底部留白
      ],
    );
  }

  // 照片项
  Widget _buildPhotoItem(String photoPath) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(photoPath),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.more_horiz,
                size: 16,
                color: Colors.white,
              ),
              onPressed: () {
                // 显示更多选项
              },
            ),
          ),
        ),
      ],
    );
  }

  // 选择头像图片
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        avatarPath = pickedFile.path;
      });
    }
  }

  // 编辑昵称
  void _editNickname() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF02051F),
        title: const Text('编辑昵称', style: TextStyle(color: Colors.white)),
        content: TextField(
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: '输入昵称',
            hintStyle: TextStyle(color: Colors.white70),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.white70),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.blue),
            ),
          ),
          onChanged: (value) {
            setState(() {
              nickname = value.isEmpty ? '昵称' : value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white70)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('确定', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }
}
