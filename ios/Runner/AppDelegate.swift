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
    func setPreviewView(view: UIView) {
        self.previewView = view
        
        // 如果已经有预览层，先移除
        if let existingLayer = self.videoPreviewLayer {
            existingLayer.removeFromSuperlayer()
        }
        
        // 创建新的预览层
        if let session = self.captureSession {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            
            // 确保预览层的大小与视图匹配
            previewLayer.frame = view.bounds
            
            // 创建一个新的UIView作为预览容器，并添加到视图层级中
            let previewContainer = UIView(frame: view.bounds)
            previewContainer.backgroundColor = UIColor.clear
            previewContainer.tag = 999 // 使用tag便于后续查找
            
            // 将预览层添加到预览容器
            previewContainer.layer.addSublayer(previewLayer)
            
            // 将预览容器添加到视图
            DispatchQueue.main.async {
                // 移除旧的预览容器（如果存在）
                if let oldContainer = view.viewWithTag(999) {
                    oldContainer.removeFromSuperview()
                }
                
                // 添加新的预览容器
                view.insertSubview(previewContainer, at: 0)
                
                // 初始时隐藏预览层
                previewLayer.isHidden = true
            }
            
            self.videoPreviewLayer = previewLayer
            
            // 确保会话已配置但不立即启动
            if session.inputs.isEmpty {
                self.setupInitialCameraInput()
            }
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
    func switchToUltraWide(zoom: Double, completion: @escaping (Bool, String) -> Void) {
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
                    
                    // 应用轻微的缩放因子，避免预览偏移问题
                    try ultraWideDevice.lockForConfiguration()
                    // 设置一个非常接近1的缩放因子，以避免预览偏移问题
                    let minZoom = ultraWideDevice.minAvailableVideoZoomFactor
                    ultraWideDevice.videoZoomFactor = minZoom * 1.01
                    ultraWideDevice.unlockForConfiguration()
                    
                    print("成功添加超广角相机输入")
                } else {
                    session.commitConfiguration()
                    print("无法添加超广角相机输入到会话")
                    completion(false, "Cannot add ultra-wide camera input to session")
                    return
                }
                
                // 设置缩放
                self.adjustZoom(zoom: zoom)
                
                session.commitConfiguration()
                
                // 确保预览层已设置
                if let previewView = self.previewView, self.videoPreviewLayer == nil {
                    self.setPreviewView(view: previewView)
                    print("设置了新的预览层")
                }
                
                // 更新预览层的frame以匹配视图大小
                if let previewLayer = self.videoPreviewLayer, let previewView = self.previewView {
                    DispatchQueue.main.async {
                        previewLayer.frame = previewView.bounds
                        previewLayer.isHidden = false
                        print("显示预览层，尺寸: \(previewLayer.frame)")
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
            
            // 确保缩放值在设备支持的范围内
            let zoomFactor = max(min(CGFloat(zoom), maxZoom), minZoom)
            device.videoZoomFactor = zoomFactor
            
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
    let cameraChannel = FlutterMethodChannel(name: "com.example.camera/ultrawide", binaryMessenger: controller.binaryMessenger)
    
    // 设置预览视图
    CameraManager.shared.setPreviewView(view: controller.view)

    cameraChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      if call.method == "switchToUltraWide" {
        guard let args = call.arguments as? [String: Any],
              let zoom = args["zoom"] as? Double else {
          result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid zoom value", details: nil))
          return
        }
        CameraManager.shared.switchToUltraWide(zoom: zoom) { success, message in
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
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
