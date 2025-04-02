import 'package:flutter/material.dart';
import 'package:haohaopai/login/phone_login_page.dart';
import 'package:provider/provider.dart';
import 'package:haohaopai/login/auth_provider.dart';
import 'package:haohaopai/screens/camera_screen.dart';
import 'package:haohaopai/screens/profile/profile_screen.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 背景图片
          Positioned.fill(
            child: Image.asset(
              'assets/images/login.png',
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // 将整个屏幕分为上中下三部分
                const Spacer(),

                // 标题居中
                Center(
                  child: Column(
                    children: [
                      const Text(
                        '好好拍',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '一键教你拍出大片',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 底部登录部分
                Column(
                  children: [
                    // 手机号登录按钮
                    Center(
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width * 0.5,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const PhoneLoginPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                          ),
                          child:
                              const Text('登录', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                    ),
                    // 增加与第三方登录的距离
                    const SizedBox(height: 40),
                    // 第三方登录选项
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // 微信登录
                        InkWell(
                          onTap: () {
                            // 微信登录逻辑（暂不实现）
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('微信登录功能暂未实现')),
                            );
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Color(0xFF07C160),
                              shape: BoxShape.circle,
                            ),
                            child:
                                const Icon(Icons.wechat, color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 30),
                        // Apple登录 - 颜色反转
                        InkWell(
                          onTap: () async {
                            final authProvider = Provider.of<AuthProvider>(
                                context,
                                listen: false);
                            final success =
                                await authProvider.loginWithThirdParty('apple');

                            if (success) {
                              print('Apple登录成功: 用户名=${authProvider.userName}');

                              // 登录成功，导航到个人资料界面并清除导航栈
                              if (context.mounted) {
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const ProfileScreen()),
                                  (route) => false,
                                );
                              }
                            } else {
                              // 登录失败，显示提示
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Apple登录失败，请重试')),
                                );
                              }
                            }
                          },
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.apple, color: Colors.black),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
