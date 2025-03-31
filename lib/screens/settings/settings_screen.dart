import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_theme.dart';
import '../../login/auth_provider.dart';
import '../../login/login_page.dart';

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
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              _buildSectionHeader(context, '相机设置'),

              // 网格线开关
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('默认打开网格线',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text('每次打开相机时自动显示网格线',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  value: settings.showGridLines,
                  onChanged: (value) => settings.setShowGridLines(value),
                  activeColor: AppTheme.primaryColor,
                ),
              ),

              // 闪光灯设置
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: const Text('闪光灯默认设置',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text('每次启动应用时的闪光灯状态',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  trailing: DropdownButton<String>(
                    value: '关闭',
                    dropdownColor: const Color(0xFF02051F),
                    style: const TextStyle(color: Colors.white),
                    icon:
                        const Icon(Icons.arrow_drop_down, color: Colors.white),
                    underline: Container(
                      height: 1,
                      color: Colors.white.withOpacity(0.3),
                    ),
                    onChanged: (String? newValue) {
                      // TODO: 实现闪光灯默认设置
                    },
                    items: <String>['自动', '开启', '关闭']
                        .map<DropdownMenuItem<String>>((
                      String value,
                    ) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),

              _buildSectionHeader(context, '存储设置'),

              // 保存到相册开关
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('自动保存到相册',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text('拍照后自动保存到系统相册',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  value: settings.saveToGallery,
                  onChanged: (value) => settings.setSaveToGallery(value),
                  activeColor: AppTheme.primaryColor,
                ),
              ),

              _buildSectionHeader(context, '位置信息'),

              // 位置信息开关
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SwitchListTile(
                  title: const Text('记录位置信息',
                      style: TextStyle(color: Colors.white)),
                  subtitle: Text('在照片中保存拍摄位置',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.7), fontSize: 12)),
                  value: settings.enableLocation,
                  onChanged: (value) => settings.setEnableLocation(value),
                  activeColor: AppTheme.primaryColor,
                ),
              ),

              _buildSectionHeader(context, '账户'),

              // 退出登录按钮
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title:
                      const Text('退出登录', style: TextStyle(color: Colors.white)),
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
                              final authProvider = Provider.of<AuthProvider>(
                                  context,
                                  listen: false);
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

              const SizedBox(height: 24),

              // 重置按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: const Color(0xFF121530),
                        title: const Text('重置设置',
                            style: TextStyle(color: Colors.white)),
                        content: const Text('确定要将所有设置恢复为默认值吗？',
                            style: TextStyle(color: Colors.white70)),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消',
                                style: TextStyle(color: Colors.white70)),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('确定',
                                style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await settings.resetSettings();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('已重置所有设置')),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('重置所有设置'),
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
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
