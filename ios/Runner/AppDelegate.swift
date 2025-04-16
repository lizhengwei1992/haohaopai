import Flutter
import UIKit
import AVFoundation
import UserNotifications
// 不需要导入外部模块，这些Swift文件在同一个项目中

// 备注: 我们移除了有类型问题的扩展，改为在应用中管理事件通道的生命周期

@main
@objc class AppDelegate: FlutterAppDelegate {
  // 私有标识，防止多次初始化相机
  private var isCameraInitializing = false
  
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
            CameraSingleton.shared.initializeCamera { success in
                result(success)
            }
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
    
    // 避免立即初始化相机，改为仅在用户首次打开相机页面时初始化
    // 这有助于提高App启动速度和避免不必要的资源占用
    // 相机初始化会延迟到用户通过Flutter代码调用时再执行
    
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
      
      // 添加虚拟设备类型检查
      deviceTypes.append(contentsOf: [
        .builtInTripleCamera,
        .builtInDualWideCamera,
        .builtInDualCamera
      ])
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
    var hasVirtualDeviceSupport = false
    var virtualDeviceSwitchPoints: [CGFloat] = []
    
    // 检查是否支持虚拟设备
    if #available(iOS 13.0, *) {
      // 先检查是否有虚拟设备支持
      for device in devices {
        if device.position == .back {
          if device.deviceType == .builtInTripleCamera || 
             device.deviceType == .builtInDualWideCamera || 
             device.deviceType == .builtInDualCamera {
            hasVirtualDeviceSupport = true
            
            // 获取虚拟设备切换点
            if let switchPoints = device.virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber] {
              virtualDeviceSwitchPoints = switchPoints.map { CGFloat($0.doubleValue) }
            }
            
            // 如果找到虚拟设备，不需要继续查找
            break
          }
        }
      }
    }
    
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
      // 一些高端设备可能有3x长焦
      if virtualDeviceSwitchPoints.count > 1 && virtualDeviceSwitchPoints.last! > 2.5 {
        zoomOptions.append(3.0)
      }
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
    
    // 添加虚拟设备支持信息
    capabilities["hasVirtualDeviceSupport"] = hasVirtualDeviceSupport
    capabilities["virtualDeviceSwitchPoints"] = virtualDeviceSwitchPoints
    
    // 添加设备信息
    capabilities["deviceModel"] = deviceModel
    capabilities["iOSVersion"] = UIDevice.current.systemVersion
    
    // 最大缩放倍率
    let maxZoom: CGFloat = hasVirtualDeviceSupport ? 10.0 : 5.0
    capabilities["maxZoomLevel"] = maxZoom
    
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
