import 'package:flutter/material.dart';

// 消息列表页面
class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010417),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '消息中心',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Text(
          '暂无消息',
          style: TextStyle(
            color: Colors.white60,
            fontSize: 16,
          ),
        ),
      ),
    );
  }
}
