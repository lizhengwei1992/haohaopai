import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置'), elevation: 0),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, child) {
          return ListView(
            children: [
              _buildSectionHeader(context, '相机设置'),

              // 网格线开关
              SwitchListTile(
                title: const Text('显示网格线'),
                subtitle: const Text('拍照时显示九宫格辅助线'),
                value: settings.showGridLines,
                onChanged: (value) => settings.setShowGridLines(value),
                activeColor: AppTheme.primaryColor,
              ),

              const Divider(),

              // 闪光灯设置
              ListTile(
                title: const Text('闪光灯默认设置'),
                subtitle: const Text('每次启动应用时的闪光灯状态'),
                trailing: DropdownButton<String>(
                  value: '关闭',
                  onChanged: (String? newValue) {
                    // TODO: 实现闪光灯默认设置
                  },
                  items:
                      <String>['自动', '开启', '关闭'].map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                ),
              ),

              _buildSectionHeader(context, '存储设置'),

              // 保存到相册开关
              SwitchListTile(
                title: const Text('自动保存到相册'),
                subtitle: const Text('拍照后自动保存到系统相册'),
                value: settings.saveToGallery,
                onChanged: (value) => settings.setSaveToGallery(value),
                activeColor: AppTheme.primaryColor,
              ),

              // 图片质量滑块
              ListTile(
                title: const Text('图片质量'),
                subtitle: Text('${settings.imageQuality}%'),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Slider(
                  value: settings.imageQuality.toDouble(),
                  min: 50,
                  max: 100,
                  divisions: 10,
                  label: '${settings.imageQuality}%',
                  onChanged: (value) => settings.setImageQuality(value.round()),
                  activeColor: AppTheme.primaryColor,
                ),
              ),

              _buildSectionHeader(context, '位置信息'),

              // 位置信息开关
              SwitchListTile(
                title: const Text('记录位置信息'),
                subtitle: const Text('在照片中保存拍摄位置'),
                value: settings.enableLocation,
                onChanged: (value) => settings.setEnableLocation(value),
                activeColor: AppTheme.primaryColor,
              ),

              const SizedBox(height: 24),

              // 重置按钮
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ElevatedButton(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder:
                          (context) => AlertDialog(
                            title: const Text('重置设置'),
                            content: const Text('确定要将所有设置恢复为默认值吗？'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false),
                                child: const Text('取消'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true),
                                child: const Text('确定'),
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
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('重置所有设置'),
                ),
              ),

              const SizedBox(height: 32),

              // 版本信息
              const Center(
                child: Text('好好拍 v1.0.0', style: TextStyle(color: Colors.grey)),
              ),
              const SizedBox(height: 8),
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
        style: TextStyle(
          color: AppTheme.primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }
}
