import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'auth_provider.dart';
import '../home/home.dart';

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
                    // 增加与第三方登录的距离
                    const SizedBox(height: 40),
                    // Apple登录
                    InkWell(
                      onTap: () async {
                        final authProvider =
                            Provider.of<AuthProvider>(context, listen: false);
                        final success =
                            await authProvider.loginWithThirdParty('apple');

                        if (success) {
                          print('Apple登录成功: 用户名=${authProvider.userName}');

                          // 登录成功，导航到主页并清除导航栈
                          if (context.mounted) {
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(
                                  builder: (context) => const ProfileScreen()),
                              (route) => false,
                            );
                          }
                        } else {
                          // 登录失败，显示提示
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Apple登录失败，请重试')),
                            );
                          }
                        }
                      },
                      child: Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.apple,
                            color: Colors.black, size: 40),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      '使用Apple账号登录',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
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
