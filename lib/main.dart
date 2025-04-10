import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';

import 'camera/native_camera_service.dart';
import 'camera/camera_screen.dart';
import 'home/home.dart';
import 'home/settings_screen.dart';
import 'login/auth_provider.dart';
import 'login/login_page.dart';
import 'utils/app_theme.dart';

Future<void> main() async {
  // 确保Flutter绑定初始化
  WidgetsFlutterBinding.ensureInitialized();

  // 设置页面方向
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 请求相机权限
  final cameraStatus = await Permission.camera.request();
  if (cameraStatus.isDenied) {
    debugPrint('相机权限被拒绝');
  }

  // 启动应用
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );

  // 在应用启动后的后台初始化相机，不阻塞UI
  if (Platform.isIOS) {
    // 使用微任务确保它不会阻塞主UI线程，但会在当前帧结束后立即执行
    Future.microtask(() async {
      try {
        debugPrint('开始在后台初始化相机...');
        final success = await NativeCameraService.instance.initializeCamera();
        debugPrint('相机初始化${success ? '成功' : '失败'}');
      } catch (e) {
        debugPrint('相机初始化出错: $e');
      }
    });
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 初始化AuthProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AuthProvider>(context, listen: false).init().then((_) {
        print(
            'AuthProvider初始化完成: 登录状态=${Provider.of<AuthProvider>(context, listen: false).isLoggedIn}');
      });
    });

    return MaterialApp(
      title: '好好拍',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      routes: {
        '/camera': (context) => const CameraScreen(),
        '/home': (context) => const ProfileScreen(),
        '/settings': (context) => const SettingsScreen(),
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

// 启动页面，检查登录状态
class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // 等待AuthProvider初始化完成
    await Future.delayed(const Duration(milliseconds: 1000));

    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 根据登录状态跳转到不同页面
    if (authProvider.isLoggedIn) {
      // 如果已登录，跳转到主页
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfileScreen()),
        );
      }
    } else {
      // 如果未登录，跳转到登录页面
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const LoginPage()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF010417),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '好好拍',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 20),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade300),
            ),
          ],
        ),
      ),
    );
  }
}
