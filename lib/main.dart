import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';

import 'screens/camera_screen.dart';
import 'providers/camera_provider.dart';

List<CameraDescription> cameras = [];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 获取相机列表
  cameras = await availableCameras();

  // 请求相机权限
  await Permission.camera.request();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CameraProvider())],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI 拍照助手',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: CameraScreen(cameras: cameras),
    );
  }
}
