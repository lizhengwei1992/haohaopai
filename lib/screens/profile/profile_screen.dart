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
      appBar: AppBar(
        title: const Text('个人中心'),
        elevation: 0,
      ),
      body: Consumer<CameraProvider>(
        builder: (context, cameraProvider, child) {
          // 获取拍摄次数
          final shootingCount = cameraProvider.shootingCount;

          return ListView(
            children: [
              // 用户信息卡片
              _buildUserInfoCard(context),

              const SizedBox(height: 16),

              // 拍摄统计
              _buildSectionHeader(context, '拍摄统计'),
              _buildStatisticsCard(context, shootingCount),

              const SizedBox(height: 16),

              // 付费信息
              _buildSectionHeader(context, '付费信息'),
              _buildPaymentInfoCard(context, shootingCount),

              const SizedBox(height: 16),

              // 其他功能
              _buildSectionHeader(context, '其他功能'),
              _buildFunctionList(context),

              const SizedBox(height: 32),

              // 版本信息
              const Center(
                child: Text('好好拍 v1.0.0', style: TextStyle(color: Colors.grey)),
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
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // 用户头像
            CircleAvatar(
              radius: 40,
              backgroundColor: AppTheme.primaryColor.withOpacity(0.1),
              child: Icon(
                Icons.person,
                size: 40,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(width: 16),
            // 用户信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '用户',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '普通会员',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: () {
                      // TODO: 实现编辑资料功能
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('编辑资料功能即将上线')),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryColor,
                      side: BorderSide(color: AppTheme.primaryColor),
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
      ),
    );
  }

  // 拍摄统计卡片
  Widget _buildStatisticsCard(BuildContext context, int shootingCount) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('教我拍次数', shootingCount.toString()),
                _buildStatItem('拍摄照片',
                    '${Provider.of<CameraProvider>(context).recentPhotos.length}张'),
                _buildStatItem('剩余次数', '无限制'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // 统计项
  Widget _buildStatItem(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  // 付费信息卡片
  Widget _buildPaymentInfoCard(BuildContext context, int shootingCount) {
    // 根据拍摄次数计算费用
    final int basicFee = 0;
    final int additionalFee = (shootingCount / 10).floor() * 5; // 每10次额外收费5元
    final int totalFee = basicFee + additionalFee;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '付费方案',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildPaymentRow('基础费用', '$basicFee 元'),
            const SizedBox(height: 8),
            _buildPaymentRow('额外费用', '$additionalFee 元 (${shootingCount}次)'),
            const Divider(height: 24),
            _buildPaymentRow('总计', '$totalFee 元', isBold: true),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // TODO: 实现付费功能
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('付费功能即将上线')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('立即付费'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 付费行
  Widget _buildPaymentRow(String title, String value, {bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? Colors.black : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isBold ? 16 : 14,
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            color: isBold ? AppTheme.primaryColor : Colors.black,
          ),
        ),
      ],
    );
  }

  // 功能列表
  Widget _buildFunctionList(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildFunctionItem(
            context,
            Icons.history,
            '拍摄历史',
            '查看历史拍摄记录',
            () {
              // TODO: 实现拍摄历史功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('拍摄历史功能即将上线')),
              );
            },
          ),
          const Divider(height: 1, indent: 56),
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
          const Divider(height: 1, indent: 56),
          _buildFunctionItem(
            context,
            Icons.settings,
            '设置',
            '应用设置与偏好',
            () {
              Navigator.pushNamed(context, '/settings');
            },
          ),
          const Divider(height: 1, indent: 56),
          _buildFunctionItem(
            context,
            Icons.help_outline,
            '帮助与反馈',
            '获取帮助或提交反馈',
            () {
              // TODO: 实现帮助与反馈功能
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('帮助与反馈功能即将上线')),
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
      leading: Icon(icon, color: AppTheme.primaryColor),
      title: Text(title),
      subtitle: Text(subtitle,
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  // 分区标题
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
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
