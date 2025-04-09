import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../login/auth_provider.dart';
import '../login/login_page.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02051F),
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF02051F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: ListView(
        children: [
          _buildSectionHeader(context, '账户'),

          // 退出登录按钮
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: ListTile(
              title: const Text('退出登录', style: TextStyle(color: Colors.white)),
              trailing: const Icon(Icons.logout, color: Colors.red),
              onTap: () {
                // 显示确认对话框
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    backgroundColor: const Color(0xFF121530),
                    title: const Text('退出登录',
                        style: TextStyle(color: Colors.white)),
                    content: const Text('确定要退出当前账号吗？',
                        style: TextStyle(color: Colors.white70)),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('取消',
                            style: TextStyle(color: Colors.white70)),
                      ),
                      TextButton(
                        onPressed: () {
                          // 退出登录
                          final authProvider =
                              Provider.of<AuthProvider>(context, listen: false);
                          authProvider.logout();

                          // 关闭对话框
                          Navigator.pop(context);

                          // 退出到登录页
                          Navigator.of(context).pushAndRemoveUntil(
                            MaterialPageRoute(
                                builder: (context) => const LoginPage()),
                            (route) => false,
                          );
                        },
                        child: const Text('确定',
                            style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 32),

          // 版本信息
          const Center(
            child: Text('好好拍 v1.0.0',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.9),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
