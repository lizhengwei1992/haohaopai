import Flutter
import UIKit
import AVFoundation

// 添加CameraManager类
class CameraManager: NSObject {
    static let shared = CameraManager()
    
    private var captureSession: AVCaptureSession?
    private var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    private var currentDevice: AVCaptureDevice?
    private var currentInput: AVCaptureDeviceInput?
    private var isUltraWideActive = false
    private var previewView: UIView?
    
    private override init() {
        super.init()
        setupCaptureSession()
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .photo
    }
    
    // 设置预览视图
    func setPreviewView(view: UIView, aspectRatio: String = "4:3") {
        self.previewView = view
        
        // 如果已经有预览层，先移除
        if let existingLayer = self.videoPreviewLayer {
            existingLayer.removeFromSuperlayer()
        }
        
        // 创建新的预览层
        if let session = self.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            // 创建一个自定义的透明视图作为预览容器
            class PassthroughView: UIView {
                override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
                    let hitView = super.hitTest(point, with: event)
                    // 如果点击的是当前视图，返回nil以允许事件传递
                    return hitView == self ? nil : hitView
                }
                
                override func point(inside point: CGPoint, with event: UIEvent?) -> Bool {
                    return false
                }
            }
            
            // 创建一个新的PassthroughView作为预览容器
            let previewContainer = PassthroughView(frame: view.bounds)
            previewContainer.backgroundColor = UIColor.clear
            previewContainer.tag = 999 // 使用tag便于后续查找
            previewContainer.isUserInteractionEnabled = false // 禁用用户交互
            previewContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            
            // 将预览层添加到预览容器
            previewContainer.layer.addSublayer(previewLayer)
            
            // 将预览容器添加到视图
            DispatchQueue.main.async {
                // 移除旧的预览容器（如果存在）
                if let oldContainer = view.viewWithTag(999) {
                    oldContainer.removeFromSuperview()
                }
                
                // 将预览容器添加到视图
                view.addSubview(previewContainer)
                
                // 将预览容器移到最底层
                view.sendSubviewToBack(previewContainer)
                
                // 设置预览层的frame
                previewLayer.frame = previewContainer.bounds
                
                // 初始时隐藏预览层
                previewLayer.isHidden = true
                
                // 应用拍摄比例
                self.updatePreviewAspectRatio(aspectRatio: aspectRatio)
                
                print("预览容器已添加到视图层级，层级结构：")
                self.printViewHierarchy(view)
            }
            
            self.videoPreviewLayer = previewLayer
            
            // 确保会话已配置但不立即启动
            if session.inputs.isEmpty {
                self.setupInitialCameraInput()
            }
        }
    }
    
    // 打印视图层级结构，用于调试
    private func printViewHierarchy(_ view: UIView, level: Int = 0) {
        let indent = String(repeating: "  ", count: level)
        let viewType = String(describing: type(of: view))
        print("\(indent)View: \(viewType), tag: \(view.tag), frame: \(view.frame), zPosition: \(view.layer.zPosition), userInteraction: \(view.isUserInteractionEnabled)")
        
        for subview in view.subviews {
            printViewHierarchy(subview, level: level + 1)
        }
    }
    
    // 更新预览层的宽高比
    func updatePreviewAspectRatio(aspectRatio: String) {
        guard let previewView = self.previewView,
              let previewContainer = previewView.viewWithTag(999),
              let previewLayer = self.videoPreviewLayer else {
            return
        }
        
        let screenWidth = previewView.bounds.width
        let screenHeight = previewView.bounds.height
        
        // 计算目标宽高比
        var targetAspectRatio: CGFloat
        switch aspectRatio {
        case "16:9":
            targetAspectRatio = 9.0 / 16.0 // 在竖屏模式下，宽高比需要倒置
        case "1:1":
            targetAspectRatio = 1.0
        case "4:3":
            fallthrough
        default:
            targetAspectRatio = 3.0 / 4.0 // 在竖屏模式下，宽高比需要倒置
        }
        
        // 计算预览区域的高度，确保水平方向充满屏幕宽度
        let previewHeight = screenWidth / targetAspectRatio
        
        // 计算预览容器的位置，使其垂直居中
        let yOffset = (screenHeight - previewHeight) / 2.0
        
        DispatchQueue.main.async {
            // 更新预览容器的frame
            previewContainer.frame = CGRect(x: 0, y: yOffset, width: screenWidth, height: previewHeight)
            
            // 更新预览层的frame以匹配预览容器
            previewLayer.frame = previewContainer.bounds
            
            // 确保预览容器位于最底层
            if let superview = previewContainer.superview {
                superview.sendSubviewToBack(previewContainer)
            }
            
            print("更新预览层宽高比: \(aspectRatio), 尺寸: \(previewContainer.frame)")
        }
    }
    
    // 设置初始相机输入
    private func setupInitialCameraInput() {
        guard let session = self.captureSession else { return }
        
        // 查找广角相机作为初始相机
        guard let wideAngleDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            print("无法找到广角相机")
            return
        }
        
        do {
            let input = try AVCaptureDeviceInput(device: wideAngleDevice)
            if session.canAddInput(input) {
                session.beginConfiguration()
                session.addInput(input)
                session.commitConfiguration()
                self.currentDevice = wideAngleDevice
                self.currentInput = input
            }
        } catch {
            print("设置初始相机输入错误: \(error.localizedDescription)")
        }
    }
    
    // 检查设备是否支持超广角相机
    func isUltraWideCameraAvailable() -> Bool {
        if #available(iOS 13.0, *) {
            return AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) != nil
        } else {
            return false
        }
    }
    
    // 切换到超广角相机
    func switchToUltraWide(zoom: Double, aspectRatio: String = "4:3", completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(false, "CameraManager instance is nil")
                return
            }
            
            // 检查iOS版本
            guard #available(iOS 13.0, *) else {
                completion(false, "Ultra-wide camera requires iOS 13.0 or newer")
                return
            }
            
            guard let session = self.captureSession else {
                completion(false, "Capture session is nil")
                return
            }
            
            // 检查是否已经是超广角相机
            if self.isUltraWideActive {
                // 如果已经是超广角相机，只调整缩放
                self.adjustZoom(zoom: zoom)
                // 更新宽高比
                self.updatePreviewAspectRatio(aspectRatio: aspectRatio)
                completion(true, "Already using ultra-wide camera, zoom adjusted")
                return
            }
            
            // 查找超广角相机
            guard let ultraWideDevice = AVCaptureDevice.default(.builtInUltraWideCamera, for: .video, position: .back) else {
                completion(false, "Ultra-wide camera not available on this device")
                return
            }
            
            print("开始切换到超广角相机...")
            
            do {
                // 停止当前会话
                if session.isRunning {
                    session.stopRunning()
                }
                
                session.beginConfiguration()
                
                // 移除当前输入
                if let currentInput = self.currentInput {
                    session.removeInput(currentInput)
                }
                
                // 添加超广角相机输入
                let input = try AVCaptureDeviceInput(device: ultraWideDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.currentDevice = ultraWideDevice
                    self.currentInput = input
                    self.isUltraWideActive = true
                    
                    // 获取设备支持的缩放范围
                    let minZoom = ultraWideDevice.minAvailableVideoZoomFactor
                    let maxZoom = ultraWideDevice.maxAvailableVideoZoomFactor
                    print("超广角相机缩放范围: \(minZoom) - \(maxZoom)")
                    
                    // 设置会话预设为照片质量，这对于正确显示超广角视野很重要
                    session.sessionPreset = .photo
                    
                    // 计算缩放因子：将0.5-1.0的范围映射到设备的minZoom-1.0范围
                    // 这样当Flutter传入0.5时，我们使用设备的最小缩放；当传入1.0时，我们使用1.0的缩放
                    var zoomFactor: CGFloat
                    if zoom < 1.0 {
                        // 将0.5-1.0映射到minZoom-1.0
                        let normalizedZoom = (CGFloat(zoom) - 0.5) / 0.5 // 将0.5-1.0归一化为0-1
                        zoomFactor = minZoom + normalizedZoom * (1.0 - minZoom) // 映射到minZoom-1.0
                    } else {
                        zoomFactor = CGFloat(zoom)
                    }
                    
                    // 应用缩放因子
                    try ultraWideDevice.lockForConfiguration()
                    ultraWideDevice.videoZoomFactor = zoomFactor
                    ultraWideDevice.unlockForConfiguration()
                    
                    print("成功添加超广角相机输入，应用缩放因子: \(zoomFactor)")
                } else {
                    session.commitConfiguration()
                    print("无法添加超广角相机输入到会话")
                    completion(false, "Cannot add ultra-wide camera input to session")
                    return
                }
                
                session.commitConfiguration()
                
                // 确保预览层已设置
                if let previewView = self.previewView, self.videoPreviewLayer == nil {
                    self.setPreviewView(view: previewView, aspectRatio: aspectRatio)
                    print("设置了新的预览层")
                } else {
                    // 更新现有预览层的宽高比
                    self.updatePreviewAspectRatio(aspectRatio: aspectRatio)
                }
                
                // 更新预览层的frame以匹配视图大小
                if let previewLayer = self.videoPreviewLayer, let previewView = self.previewView {
                    DispatchQueue.main.async {
                        // 显示预览层
                        previewLayer.isHidden = false
                        
                        // 确保预览容器在正确的位置
                        if let previewContainer = previewView.viewWithTag(999) {
                            // 将预览容器移到最底层
                            if let superview = previewContainer.superview {
                                superview.sendSubviewToBack(previewContainer)
                            }
                            
                            print("预览容器已设置为最底层")
                        }
                        
                        print("显示预览层，尺寸: \(previewLayer.frame)")
                        
                        // 打印视图层级结构，用于调试
                        self.printViewHierarchy(previewView)
                    }
                }
                
                // 启动会话
                DispatchQueue.global(qos: .userInitiated).async {
                    session.startRunning()
                    print("相机会话已启动")
                    
                    // 在主线程上通知完成
                    DispatchQueue.main.async {
                        completion(true, "Switched to ultra-wide camera")
                    }
                }
            } catch {
                session.commitConfiguration()
                print("切换到超广角相机错误: \(error.localizedDescription)")
                completion(false, "Error switching to ultra-wide: \(error.localizedDescription)")
            }
        }
    }
    
    // 切换到广角相机
    func switchToWideAngle(zoom: Double, completion: @escaping (Bool, String) -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(false, "CameraManager instance is nil")
                return
            }
            
            guard let session = self.captureSession else {
                completion(false, "Capture session is nil")
                return
            }
            
            // 如果已经是广角相机，只调整缩放
            if !self.isUltraWideActive {
                self.adjustZoom(zoom: zoom)
                completion(true, "Already using wide-angle camera, zoom adjusted")
                return
            }
            
            // 查找广角相机
            guard let wideAngleDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
                completion(false, "Wide-angle camera not available")
                return
            }
            
            do {
                // 停止当前会话
                if session.isRunning {
                    session.stopRunning()
                }
                
                session.beginConfiguration()
                
                // 移除当前输入
                if let currentInput = self.currentInput {
                    session.removeInput(currentInput)
                }
                
                // 添加广角相机输入
                let input = try AVCaptureDeviceInput(device: wideAngleDevice)
                if session.canAddInput(input) {
                    session.addInput(input)
                    self.currentDevice = wideAngleDevice
                    self.currentInput = input
                    self.isUltraWideActive = false
                } else {
                    session.commitConfiguration()
                    completion(false, "Cannot add wide-angle camera input to session")
                    return
                }
                
                // 设置缩放
                self.adjustZoom(zoom: zoom)
                
                session.commitConfiguration()
                
                // 隐藏预览层，因为我们将使用Flutter的相机预览
                if let previewLayer = self.videoPreviewLayer {
                    DispatchQueue.main.async {
                        previewLayer.isHidden = true
                    }
                }
                
                // 通知完成
                completion(true, "Switched to wide-angle camera")
            } catch {
                session.commitConfiguration()
                completion(false, "Error switching to wide-angle: \(error.localizedDescription)")
            }
        }
    }
    
    // 调整缩放
    private func adjustZoom(zoom: Double) {
        do {
            guard let device = self.currentDevice else { return }
            
            try device.lockForConfiguration()
            
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = device.maxAvailableVideoZoomFactor
            
            // 如果是超广角相机，需要特殊处理缩放范围
            if self.isUltraWideActive && zoom < 1.0 {
                // 将0.5-1.0映射到minZoom-1.0
                let normalizedZoom = (CGFloat(zoom) - 0.5) / 0.5 // 将0.5-1.0归一化为0-1
                let zoomFactor = minZoom + normalizedZoom * (1.0 - minZoom) // 映射到minZoom-1.0
                device.videoZoomFactor = zoomFactor
                print("调整超广角相机缩放: \(zoom) -> \(zoomFactor)")
            } else {
                // 确保缩放值在设备支持的范围内
                let zoomFactor = max(min(CGFloat(zoom), maxZoom), minZoom)
                device.videoZoomFactor = zoomFactor
                print("调整相机缩放: \(zoom) -> \(zoomFactor)")
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error adjusting zoom: \(error.localizedDescription)")
        }
    }
}

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController
    
    // 创建一个容器视图来持有相机预览
    let cameraContainer = UIView(frame: controller.view.bounds)
    cameraContainer.backgroundColor = .clear
    cameraContainer.tag = 888 // 用于标识相机容器
    cameraContainer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    
    // 将相机容器添加到视图层级中
    controller.view.insertSubview(cameraContainer, at: 0)
    
    let cameraChannel = FlutterMethodChannel(name: "com.example.camera/ultrawide", binaryMessenger: controller.binaryMessenger)
    
    // 设置预览视图为相机容器
    CameraManager.shared.setPreviewView(view: cameraContainer)

    cameraChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "switchToUltraWide" {
        guard let args = call.arguments as? [String: Any],
              let zoom = args["zoom"] as? Double else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid zoom value", details: nil))
          return
        }
        
        // 获取宽高比参数，默认为"4:3"
        let aspectRatio = (args["aspectRatio"] as? String) ?? "4:3"
        
        CameraManager.shared.switchToUltraWide(zoom: zoom, aspectRatio: aspectRatio) { success, message in
          result(["success": success, "message": message])
        }
      } else if call.method == "switchToWideAngle" {
        guard let args = call.arguments as? [String: Any],
              let zoom = args["zoom"] as? Double else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid zoom value", details: nil))
          return
        }
        CameraManager.shared.switchToWideAngle(zoom: zoom) { success, message in
          result(["success": success, "message": message])
        }
      } else if call.method == "checkUltraWideCameraAvailability" {
        let isAvailable = CameraManager.shared.isUltraWideCameraAvailable()
        result(isAvailable)
      } else if call.method == "updateAspectRatio" {
        guard let args = call.arguments as? [String: Any],
              let aspectRatio = args["aspectRatio"] as? String else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid aspect ratio", details: nil))
          return
        }
        CameraManager.shared.updatePreviewAspectRatio(aspectRatio: aspectRatio)
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
