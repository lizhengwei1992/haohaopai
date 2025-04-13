import Flutter
import UIKit
import AVFoundation
// 不需要导入外部模块，这些Swift文件在同一个项目中

// 备注: 我们移除了有类型问题的扩展，改为在应用中管理事件通道的生命周期

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 获取FlutterViewController
    let controller: FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // 获取插件注册器
    guard let registrar = self.registrar(forPlugin: "NativeCameraPlugin") else {
        NSLog("错误: 无法获取插件注册器")
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    // 注册原生相机视图工厂
    let cameraFactory = NativeCameraViewFactory(messenger: registrar.messenger())
    registrar.register(
        cameraFactory,
        withId: "com.haohaopai.app/native_camera_view")
    
    // 设置相机控制方法通道
    let methodChannel = FlutterMethodChannel(name: "com.haohaopai.app/native_camera",
                                          binaryMessenger: controller.binaryMessenger)
    methodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "isNativeCameraSupported":
            result(true)
        case "getCameraCapabilities":
            self.getCameraCapabilities(result: result)
        case "initializeCamera":
            CameraSingleton.shared.initializeCamera(result: result)
        case "isCameraReady":
            CameraSingleton.shared.isCameraReady(result)
        case "pauseCamera":
            CameraSingleton.shared.pausePreview()
            result(nil)
        case "resumeCamera":
            CameraSingleton.shared.resumePreview()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    // 预热相机权限，提高相机启动速度
    self.preheatCameraPermission()
    
    // 延迟初始化相机服务，避免阻塞App启动
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        NSLog("开始后台初始化相机服务...")
        CameraSingleton.shared.initializeCamera { success in
            NSLog("相机服务初始化结果: \(success)")
        }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  // 获取相机能力
  private func getCameraCapabilities(result: @escaping FlutterResult) {
    var capabilities: [String: Any] = [:]
    
    // 检查设备模型
    let deviceModel = UIDevice.current.model
    
    // 发现相机设备
    var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera]
    
    if #available(iOS 13.0, *) {
      deviceTypes.append(.builtInUltraWideCamera)
    }
    
    deviceTypes.append(.builtInTelephotoCamera)
    
    let discoverySession = AVCaptureDevice.DiscoverySession(
      deviceTypes: deviceTypes,
      mediaType: .video,
      position: .unspecified
    )
    
    // 获取支持的相机类型
    let devices = discoverySession.devices
    
    var supportedCameraTypes: [String] = []
    var zoomCapabilities: [String: Any] = [:]
    
    var hasUltraWide = false
    var hasTelephoto = false
    
    for device in devices {
      switch device.position {
      case .back:
        if device.deviceType == .builtInWideAngleCamera {
          supportedCameraTypes.append("wide")
          
          // 广角相机缩放能力
          let minZoom = device.minAvailableVideoZoomFactor
          let maxZoom = device.maxAvailableVideoZoomFactor
          
          zoomCapabilities["wide"] = [
            "minZoom": minZoom,
            "maxZoom": maxZoom
          ]
        } else if device.deviceType == .builtInTelephotoCamera {
          supportedCameraTypes.append("telephoto")
          hasTelephoto = true
          
          // 长焦相机缩放能力
          let minZoom = device.minAvailableVideoZoomFactor
          let maxZoom = device.maxAvailableVideoZoomFactor
          
          zoomCapabilities["telephoto"] = [
            "minZoom": minZoom,
            "maxZoom": maxZoom
          ]
        } else if #available(iOS 13.0, *), device.deviceType == .builtInUltraWideCamera {
          supportedCameraTypes.append("ultraWide")
          hasUltraWide = true
          
          // 超广角相机缩放能力
          let minZoom = device.minAvailableVideoZoomFactor
          let maxZoom = device.maxAvailableVideoZoomFactor
          
          zoomCapabilities["ultraWide"] = [
            "minZoom": minZoom,
            "maxZoom": maxZoom
          ]
        }
      case .front:
        supportedCameraTypes.append("front")
        
        // 前置相机缩放能力
        let minZoom = device.minAvailableVideoZoomFactor
        let maxZoom = device.maxAvailableVideoZoomFactor
        
        zoomCapabilities["front"] = [
          "minZoom": minZoom,
          "maxZoom": maxZoom
        ]
      default:
        break
      }
    }
    
    // 缩放选项
    var zoomOptions: [CGFloat] = [1.0] // 标准1x
    
    if hasUltraWide {
      zoomOptions.insert(0.5, at: 0) // 超广角0.5x
    }
    
    if hasTelephoto {
      zoomOptions.append(2.0) // 长焦2x
    }
    
    // 支持的纵横比
    let supportedRatios = ["4:3", "1:1", "16:9"]
    
    // 构建相机能力字典
    capabilities["supportedCameraTypes"] = supportedCameraTypes
    capabilities["zoomCapabilities"] = zoomCapabilities
    capabilities["hasUltraWide"] = hasUltraWide
    capabilities["hasTelephoto"] = hasTelephoto
    capabilities["allZoomOptions"] = zoomOptions
    capabilities["supportedRatios"] = supportedRatios
    
    result(capabilities)
  }
  
  // 预热相机权限，提高第一次打开相机的速度
  private func preheatCameraPermission() {
    // 只检查权限状态，不在启动时显示授权对话框
    let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
    
    // 如果已经拥有授权，可以预热一些相机设备信息
    if authStatus == .authorized {
      // 在后台线程执行，不阻塞UI
      DispatchQueue.global(qos: .utility).async {
        NSLog("预热相机: 已有授权，开始收集设备信息")
        
        // 根据iOS版本确定设备类型列表
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInTelephotoCamera]
        
        // 仅在iOS 13及以上添加超广角相机
        if #available(iOS 13.0, *) {
          deviceTypes.append(.builtInUltraWideCamera)
        }
        
        // 发现相机设备，但不实际初始化它们
        let discoverySession = AVCaptureDevice.DiscoverySession(
          deviceTypes: deviceTypes,
          mediaType: .video,
          position: .unspecified
        )
        
        // 记录设备数量，可以加速后续的相机初始化
        let devices = discoverySession.devices
        NSLog("相机预热: 发现 \(devices.count) 个相机设备")
      }
    }
  }
  
  // 处理应用进入前台的生命周期事件
  override func applicationDidBecomeActive(_ application: UIApplication) {
    super.applicationDidBecomeActive(application)
    
    // 记录应用恢复前台状态
    NSLog("应用恢复活跃状态，准备恢复通信通道")
    
    // 通知相机单例应用已恢复前台
    CameraSingleton.shared.applicationDidBecomeActive()
  }
  
  // 处理应用进入后台的生命周期事件
  override func applicationWillResignActive(_ application: UIApplication) {
    super.applicationWillResignActive(application)
    
    // 记录应用进入后台状态
    NSLog("应用即将进入非活跃状态，准备暂停通信通道")
    
    // 通知相机单例应用即将进入后台
    CameraSingleton.shared.applicationWillResignActive()
  }
}

class NativeCameraViewFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger
    
    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }
    
    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeCameraView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            binaryMessenger: messenger)
    }
    
    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}
