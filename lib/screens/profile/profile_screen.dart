import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../utils/app_theme.dart';
import '../../providers/camera_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF02051F),
      appBar: AppBar(
        title: const Text('个人中心', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF02051F),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          // 获取拍摄次数
          final shootingCount = cameraProvider.shootingCount;

          return ListView(
            children: [
              // 用户信息卡片
              _buildUserInfoCard(context),

              const SizedBox(height: 24),

              // 拍摄统计
              _buildSectionHeader(context, '拍摄统计'),
              _buildStatisticsCard(context, shootingCount),

              const SizedBox(height: 24),

              // 其他功能
              _buildSectionHeader(context, '其他功能'),
              _buildFunctionList(context),

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

  // 用户信息卡片
  Widget _buildUserInfoCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // 用户头像
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.primaryColor.withOpacity(0.2),
              border: Border.all(color: AppTheme.primaryColor, width: 2),
            ),
            child: const Icon(
              Icons.person,
              size: 40,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 20),
          // 用户信息
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '用户',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '普通会员',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    // TODO: 实现编辑资料功能
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('编辑资料功能即将上线')),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text('编辑资料'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 拍摄统计卡片
  Widget _buildStatisticsCard(BuildContext context, int shootingCount) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('教我拍次数', shootingCount.toString()),
          _buildStatItem('拍摄照片',
              '${Provider.of<CameraProvider>(context).recentPhotos.length}张'),
          _buildStatItem('剩余次数', '无限制'),
        ],
      ),
    );
  }

  // 统计项
  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // 功能列表
  Widget _buildFunctionList(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildFunctionItem(
            context,
            Icons.settings,
            '设置',
            '应用设置与偏好',
            () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.white.withOpacity(0.2)),
          _buildFunctionItem(
            context,
            Icons.card_giftcard,
            '邀请好友',
            '邀请好友获得免费拍摄次数',
            () {
              // TODO: 实现邀请好友功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('邀请好友功能即将上线')),
              );
            },
          ),
          Divider(height: 1, indent: 56, color: Colors.white.withOpacity(0.2)),
          _buildFunctionItem(
            context,
            Icons.feedback_outlined,
            '反馈',
            '提交问题或建议',
            () {
              // TODO: 实现反馈功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('反馈功能即将上线')),
              );
            },
          ),
        ],
      ),
    );
  }

  // 功能项
  Widget _buildFunctionItem(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Icon(icon, color: Colors.white),
      title: Text(title, style: const TextStyle(color: Colors.white)),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.white.withOpacity(0.7))),
      trailing: const Icon(Icons.chevron_right, color: Colors.white70),
      onTap: onTap,
    );
  }

  // 分区标题
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
