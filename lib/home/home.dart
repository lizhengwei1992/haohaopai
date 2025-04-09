import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/settings_provider.dart';
import '../login/auth_provider.dart';
import 'settings_screen.dart';
import '../camera/camera_screen.dart';
import 'messages_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String nickname = "昵称";
  String? avatarPath;
  String? backgroundImagePath;

  @override
  void initState() {
    super.initState();
    // 在初始化时加载用户信息
    _loadUserInfo();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 当依赖变化时（如Provider状态更新）重新加载信息
    _loadUserInfo();
  }

  void _loadUserInfo() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.isLoggedIn) {
      print(
          "个人资料页面 - 加载用户信息: 登录类型=${authProvider.loginType}, 用户名=${authProvider.userName}");
      setState(() {
        nickname = authProvider.getFormattedUserName();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010417),
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeaderSection(),
              const SizedBox(height: 10), // 添加间距，使分隔线下移
              Container(
                height: 2, // 加粗一倍
                margin: const EdgeInsets.symmetric(horizontal: 20.0),
                color: Colors.white.withOpacity(0.3),
              ),
              _buildAlbumLabel(),
              Expanded(
                child: Center(
                  child: Text(
                    "相册功能(TODO)",
                    style: TextStyle(color: Colors.white.withOpacity(0.7)),
                  ),
                ),
              ),
            ],
          ),

          // 底部中央悬浮相机按钮
          Positioned(
            bottom: 50, // 将bottom值从30增加到50，使按钮向上移动
            left: 0,
            right: 0,
            child: Center(
              child: _buildCameraButton(),
            ),
          ),
        ],
      ),
    );
  }

  // 构建相机按钮
  Widget _buildCameraButton() {
    return GestureDetector(
      onTap: () async {
        // 跳转到相机界面
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => const CameraScreen(),
          ),
        );
      },
      child: Container(
          width: 74,
          height: 74,
          child: Stack(children: <Widget>[
            Positioned(
                top: 0,
                left: 0,
                child: Container(
                    width: 74,
                    height: 74,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color.fromRGBO(254, 254, 254, 1),
                        width: 0.5,
                      ),
                      gradient: const LinearGradient(
                          begin: Alignment(6.123234262925839e-17, 1),
                          end: Alignment(-1, 6.123234262925839e-17),
                          colors: [
                            Color.fromRGBO(101, 115, 237, 1),
                            Color.fromRGBO(20, 210, 230, 1)
                          ]),
                      borderRadius:
                          const BorderRadius.all(Radius.elliptical(74, 74)),
                    ))),
            Positioned(
                top: 10,
                left: 10,
                child: Container(
                    width: 54,
                    height: 54,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                          begin: Alignment(6.123234262925839e-17, 1),
                          end: Alignment(-1, 6.123234262925839e-17),
                          colors: [
                            Color.fromRGBO(10, 13, 42, 1),
                            Color.fromRGBO(69, 67, 119, 1)
                          ]),
                      borderRadius: BorderRadius.all(Radius.elliptical(54, 54)),
                    ))),
            // 相机图标
            const Positioned(
              top: 26,
              left: 26,
              child: Icon(
                Icons.camera_alt_rounded,
                color: Color.fromRGBO(190, 196, 252, 1),
                size: 24,
              ),
            ),
          ])),
    );
  }

  Widget _buildHeaderSection() {
    final screenHeight = MediaQuery.of(context).size.height;
    final avatarPosition = screenHeight * 0.10; // 进一步降低比例，头像位置更上移
    final statsCardPosition = avatarPosition + 120; // 增加间距，避免重叠
    final headerHeight = statsCardPosition + 90; // 整个头部区域高度

    return SizedBox(
      height: headerHeight, // 整个头部区域高度
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 背景图片 - 修改位置，使其覆盖整个上半部分
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0, // 延伸到整个头部区域底部
            child: GestureDetector(
              onTap: _pickBackgroundImage,
              child: backgroundImagePath != null
                  ? Image.file(
                      File(backgroundImagePath!),
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter, // 使背景图片从顶部开始显示
                    )
                  : Image.asset(
                      'assets/images/background.jpg',
                      fit: BoxFit.cover,
                      alignment: Alignment.topCenter, // 使背景图片从顶部开始显示
                    ),
            ),
          ),

          // 渐变遮罩 - 与背景图片相同位置
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0, // 延伸到整个头部区域底部
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.black.withOpacity(0.7),
                  ],
                ),
              ),
            ),
          ),

          // 顶部操作栏 - 调整位置、大小和间距
          Positioned(
            top: MediaQuery.of(context).padding.top + 10, // 加上状态栏高度
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // 移除返回按钮
                  const Spacer(),
                  // 消息按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MessagesScreen(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/messages.svg',
                      width: 27.5, // 缩放25%
                      height: 27.5, // 缩放25%
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24), // 保持间距
                  // 设置按钮
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                    child: SvgPicture.asset(
                      'assets/icons/setting.svg',
                      width: 13.75, // 缩小50%（从27.5调整为13.75）
                      height: 13.75, // 缩小50%（从27.5调整为13.75）
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 头像和昵称 - 位置上移
          Positioned(
            top: avatarPosition,
            left: 0,
            right: 0,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _pickAvatar,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.withOpacity(0.3),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.3),
                        width: 1,
                      ),
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
                                fontSize: 10,
                              ),
                            ),
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _editNickname,
                  child: Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      print(
                          "个人资料页面 - Consumer构建: 是否登录=${authProvider.isLoggedIn}, 用户名=${authProvider.userName}");
                      if (authProvider.isLoggedIn) {
                        // 使用最新的用户名并更新状态
                        nickname = authProvider.getFormattedUserName();
                        return Text(
                          nickname,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        );
                      }
                      return Text(
                        nickname,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // 底部统计卡片 - 位置上移
          Positioned(
            top: statsCardPosition, // 减少了间距，上移了位置
            left: 20,
            right: 20,
            child: _buildStatsCard(),
          ),
        ],
      ),
    );
  }

  // 相册标签
  Widget _buildAlbumLabel() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 6), // 减少上下边距
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          "相册",
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // 账户余额卡片
  Widget _buildStatsCard() {
    return Container(
      height: 90, // 增加高度使卡片更高一些
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12), // 改为稍微方正一点的圆角
      ),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 60, // 调整宽度
                  height: 60, // 调整高度
                  child: Stack(
                    children: [
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withOpacity(0.5),
                        ),
                      ),
                      Center(
                        child: SizedBox(
                          width: 60,
                          height: 60,
                          child: CircularProgressIndicator(
                            value: 25.0 / 100,
                            backgroundColor: Colors.grey.withOpacity(0.2),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Color(0xFF69BDFC)),
                            strokeWidth: 4,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Text(
                              "0",
                              style: TextStyle(
                                fontSize: 16, // 调整字体大小
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              "剩余次数",
                              style: TextStyle(
                                fontSize: 9, // 调整字体大小
                                color: Colors.white70,
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
          Container(
            height: 60, // 调整分隔线高度
            width: 1,
            color: Colors.white.withOpacity(0.3),
          ),
          Expanded(
            flex: 1,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        "¥",
                        style: TextStyle(
                          fontSize: 16, // 调整字体大小
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(width: 2),
                      Text(
                        "0.69",
                        style: TextStyle(
                          fontSize: 24, // 调整字体大小
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    "账户余额",
                    style: TextStyle(
                      fontSize: 12, // 调整字体大小
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 8), // 增加间距
                  SizedBox(
                    height: 28, // 调整按钮高度
                    width: 80, // 调整按钮宽度
                    child: ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('充值功能即将上线')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFCD923D),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6), // 调整为方一点的圆角
                        ),
                      ),
                      child: const Text(
                        '充值',
                        style: TextStyle(fontSize: 14), // 调整字体大小
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 选择头像
  Future<void> _pickAvatar() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        avatarPath = image.path;
      });
    }
  }

  // 编辑昵称
  void _editNickname() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录后再修改昵称')),
      );
      return;
    }

    // 获取当前昵称作为初始值
    String newNickname = authProvider.getFormattedUserName();

    // 显示修改昵称对话框
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('修改昵称'),
        content: TextField(
          decoration: const InputDecoration(
            hintText: '请输入新昵称',
          ),
          onChanged: (value) {
            newNickname = value.trim();
          },
          controller: TextEditingController(text: newNickname),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (newNickname.isNotEmpty) {
                // 使用AuthProvider更新昵称
                await authProvider.updateUserName(newNickname);

                // 更新UI显示
                setState(() {
                  nickname = newNickname;
                });

                // 显示成功提示
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('昵称修改成功')),
                  );
                }
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  // 选择背景图片
  Future<void> _pickBackgroundImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        backgroundImagePath = image.path;
      });
    }
  }
}
