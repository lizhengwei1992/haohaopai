import AVFoundation
import UIKit
import Flutter

class CameraSingleton: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    static let shared = CameraSingleton()
    
    // 主要相机组件
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var videoDataOutput: AVCaptureVideoDataOutput?
    private var photoOutput: AVCapturePhotoOutput?
    
    // 状态跟踪
    private var isInitialized = false
    private var isRunning = false
    var currentPosition: AVCaptureDevice.Position = .back
    
    // 初始化完成回调列表
    private var initializationCompletionHandlers: [(Bool) -> Void] = []
    
    // 当前激活的设备
    private var currentDevice: AVCaptureDevice?
    private var currentDeviceInput: AVCaptureDeviceInput?
    
    // 当前缩放状态
    private var currentZoomFactor: CGFloat = 1.0
    // 当前相机类型
    private var currentDeviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera
    // 缩放切换阈值
    private var zoomThresholds: (wideToUltraWide: CGFloat, wideToTele: CGFloat) = (0.8, 2.7)
    // 是否支持超广角相机
    private var hasUltraWideCamera: Bool = false
    // 是否支持长焦相机
    private var hasTelephotoCamera: Bool = false
    
    // 事件发送器
    private var eventSink: FlutterEventSink?
    
    // 初始化锁，防止多线程初始化冲突
    private let initializationLock = NSLock()
    
    // 私有变量
    private var wasRunningBeforeBackground = false
    
    // 私有构造函数确保单例模式
    private override init() {
        super.init()
        captureSession = AVCaptureSession()
    }
    
    // MARK: - 公共方法
    
    /// 检查相机是否已准备就绪
    func isCameraReady(_ result: FlutterResult) {
        result(isInitialized)
    }
    
    /// 等待相机初始化完成
    func waitForInitialization(completion: @escaping (Bool) -> Void) {
        if isInitialized {
            completion(true)
        } else {
            initializationCompletionHandlers.append(completion)
        }
    }
    
    /// 初始化相机
    func initializeCamera(result: @escaping FlutterResult) {
        // 如果已经初始化，直接返回成功
        if isInitialized {
            result(true)
            return
        }
        
        // 加锁防止多线程初始化
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        // 再次检查（双重检查锁定模式）
        if isInitialized {
            result(true)
            return
        }
        
        // 检查相机权限
        checkCameraPermission { [weak self] hasPermission in
            guard let self = self else {
                result(FlutterError(code: "UNAVAILABLE", 
                                   message: "相机单例已被释放", 
                                   details: nil))
                return
            }
            
            if !hasPermission {
                result(FlutterError(code: "PERMISSION_DENIED", 
                                   message: "相机权限被拒绝", 
                                   details: nil))
                self.notifyInitializationCompleted(success: false)
                return
            }
            
            // 在后台线程设置相机
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.setupCaptureSession()
                    self.isInitialized = true
                    
                    // 在主线程返回结果
                    DispatchQueue.main.async {
                        self.notifyInitializationCompleted(success: true)
                        result(true)
                    }
                } catch {
                    // 在主线程返回错误
                    DispatchQueue.main.async {
                        self.notifyInitializationCompleted(success: false)
                        result(FlutterError(code: "SETUP_ERROR", 
                                           message: "设置相机失败: \(error.localizedDescription)", 
                                           details: nil))
                    }
                }
            }
        }
    }
    
    /// 通知所有等待的处理器初始化已完成
    private func notifyInitializationCompleted(success: Bool) {
        let handlers = initializationCompletionHandlers
        initializationCompletionHandlers = []
        
        for handler in handlers {
            handler(success)
        }
    }
    
    /// 开始相机预览
    func startPreview(completion: ((Bool, String?) -> Void)? = nil) {
        guard isInitialized else {
            completion?(false, "相机未初始化")
            return
        }
        
        guard let session = captureSession, !isRunning else {
            // 已经在运行
            completion?(true, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
            self.isRunning = true
            
            DispatchQueue.main.async {
                completion?(true, nil)
            }
        }
    }
    
    /// 暂停相机预览
    func pausePreview(completion: ((Bool, String?) -> Void)? = nil) {
        stopPreview(completion: completion)
    }
    
    /// 恢复相机预览
    func resumePreview(completion: ((Bool, String?) -> Void)? = nil) {
        startPreview(completion: completion)
    }
    
    /// 停止相机预览
    func stopPreview(completion: ((Bool, String?) -> Void)? = nil) {
        guard let session = captureSession, isRunning else {
            // 已经停止
            completion?(true, nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            session.stopRunning()
            self.isRunning = false
            
            DispatchQueue.main.async {
                completion?(true, nil)
            }
        }
    }
    
    /// 设置事件接收器
    func setEventSink(_ newEventSink: FlutterEventSink?) {
        // 在主线程中设置事件接收器
        DispatchQueue.main.async {
            self.eventSink = newEventSink
            
            // 如果设置了新的事件接收器，发送一个测试事件确认通道工作正常
            if let sink = newEventSink {
                // 延迟发送，确保接收器已准备好
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    let testEvent: [String: Any] = [
                        "type": "channelTest",
                        "message": "事件通道测试",
                        "timestamp": Date().timeIntervalSince1970
                    ]
                    sink(testEvent)
                }
            }
        }
    }
    
    /// 获取预览层
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        guard isInitialized, let session = captureSession else {
            return nil
        }
        
        if let existingLayer = previewLayer {
            return existingLayer
        }
        
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        previewLayer = layer
        
        return layer
    }
    
    /// 切换前后摄像头
    func switchCamera(toFront: Bool, completion: @escaping (Bool, String?) -> Void) {
        guard isInitialized, let session = captureSession else {
            print("切换相机失败: 相机未初始化")
            completion(false, "相机未初始化")
            return
        }
        
        let newPosition: AVCaptureDevice.Position = toFront ? .front : .back
        print("切换相机: 请求切换到 \(toFront ? "前置" : "后置") 相机")
        
        // 如果已经是请求的摄像头位置，直接返回成功
        if currentPosition == newPosition {
            print("相机已经是 \(toFront ? "前置" : "后置") 相机，无需切换")
            
            // 仍然发送事件，保持一致性
            sendEvent(type: "cameraSwitched", data: ["position": toFront ? "front" : "back"])
            
            completion(true, nil)
            return
        }
        
        // 在后台线程执行摄像头切换
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                print("开始配置新摄像头")
                // 配置新摄像头
                try self.configureCamera(position: newPosition)
                
                print("相机切换成功: \(toFront ? "前置" : "后置")")
                // 发送相机切换事件
                self.sendEvent(type: "cameraSwitched", data: ["position": toFront ? "front" : "back"])
                
                // 在主线程返回结果
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                print("切换相机失败: \(error.localizedDescription)")
                // 在主线程返回错误
                DispatchQueue.main.async {
                    completion(false, "切换摄像头失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 设置缩放级别
    func setZoomLevel(_ zoomLevel: CGFloat, completion: ((Bool, String?) -> Void)? = nil) {
        guard let device = currentDevice else {
            completion?(false, "当前设备不可用")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // 确保缩放值在合法范围内
            let zoom = min(max(zoomLevel, 1.0), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = zoom
            currentZoomFactor = zoom
            
            device.unlockForConfiguration()
            
            // 发送缩放变化事件
            sendEvent(type: "zoomChanged", data: ["zoomFactor": zoom])
            
            completion?(true, nil)
        } catch {
            completion?(false, "设置缩放级别失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置系统级缩放效果 (支持超广角相机)
    func setSystemLikeZoom(_ zoomLevel: CGFloat, completion: @escaping (Bool, String?) -> Void) {
        guard isInitialized, let session = captureSession else {
            completion(false, "相机未初始化")
            return
        }
        
        // 确定目标相机类型
        let targetDeviceType: AVCaptureDevice.DeviceType
        if zoomLevel < 1.0 && hasUltraWideCamera {
            if #available(iOS 13.0, *) {
                targetDeviceType = .builtInUltraWideCamera
            } else {
                // iOS 13以下不支持超广角，回退到广角
                targetDeviceType = .builtInWideAngleCamera
            }
        } else if zoomLevel >= 1.0 && zoomLevel < zoomThresholds.wideToTele {
            targetDeviceType = .builtInWideAngleCamera
        } else if zoomLevel >= zoomThresholds.wideToTele && hasTelephotoCamera {
            targetDeviceType = .builtInTelephotoCamera
        } else {
            targetDeviceType = .builtInWideAngleCamera
        }
        
        // 如果相机类型相同，只调整数字变焦
        if targetDeviceType == currentDeviceType {
            adjustDigitalZoomOnly(zoomLevel, completion: completion)
            return
        }
        
        // 记录当前会话状态
        let wasRunning = isRunning
        
        // 使用主线程处理会话配置，避免线程安全问题
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(false, "相机单例已被释放")
                return
            }
            
            // 如果相机正在运行，先停止会话
            if wasRunning {
                session.stopRunning()
                self.isRunning = false
            }
            
            // 使用beginConfiguration/commitConfiguration包裹所有配置更改
            session.beginConfiguration()
            
            do {
                // 查找指定类型的设备
                let discoverySession = AVCaptureDevice.DiscoverySession(
                    deviceTypes: [targetDeviceType],
                    mediaType: .video,
                    position: self.currentPosition
                )
                
                guard let newDevice = discoverySession.devices.first else {
                    session.commitConfiguration()
                    print("[CameraSingleton] 找不到指定类型的相机设备: \(targetDeviceType)") // 日志
                    
                    // 恢复会话状态
                    if wasRunning {
                        session.startRunning()
                        self.isRunning = true
                    }
                    
                    completion(false, "找不到指定类型的相机设备")
                    return
                }
                print("[CameraSingleton] 找到新设备: \(newDevice.localizedName)") // 日志
                
                // 保存当前输入输出
                let currentInput = self.currentDeviceInput
                let currentVideoOutput = self.videoDataOutput
                let currentPhotoOutput = self.photoOutput
                
                // 移除当前输入
                if let input = currentInput {
                    session.removeInput(input)
                    self.currentDeviceInput = nil
                    print("[CameraSingleton] 已移除旧输入") // 日志
                }
                
                // 创建新的输入
                do {
                    let newInput = try AVCaptureDeviceInput(device: newDevice)
                    print("[CameraSingleton] 已创建新输入") // 日志
                    
                    // 添加新输入
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        self.currentDeviceInput = newInput
                        self.currentDevice = newDevice
                        self.currentDeviceType = targetDeviceType
                        print("[CameraSingleton] 已添加新输入到会话") // 日志
                        
                        // 设置缩放级别
                        try newDevice.lockForConfiguration()
                        
                        // 计算有效的缩放值
                        let effectiveZoom = self.calculateEffectiveZoom(forDeviceType: targetDeviceType, requestedZoom: zoomLevel)
                        newDevice.videoZoomFactor = effectiveZoom
                        self.currentZoomFactor = effectiveZoom
                        
                        // 配置自动对焦和曝光
                        if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                            newDevice.focusMode = .continuousAutoFocus
                        }
                        
                        if newDevice.isExposureModeSupported(.continuousAutoExposure) {
                            newDevice.exposureMode = .continuousAutoExposure
                        }
                        
                        newDevice.unlockForConfiguration()
                        
                        print("[CameraSingleton] 新设备配置完成，有效缩放: \(effectiveZoom)") // 日志
                    } else {
                        // 如果无法添加新输入，恢复旧输入
                        if let input = currentInput {
                            if session.canAddInput(input) {
                                session.addInput(input)
                                self.currentDeviceInput = input
                            }
                        }
                        
                        print("[CameraSingleton] 错误：无法添加新输入到会话") // 日志
                        throw NSError(domain: "com.haohaopai.app", code: 1003, userInfo: [NSLocalizedDescriptionKey: "无法添加相机输入"])
                    }
                } catch {
                    // 恢复旧输入
                    if let input = currentInput {
                        if session.canAddInput(input) {
                            session.addInput(input)
                            self.currentDeviceInput = input
                        }
                    }
                    
                    print("[CameraSingleton] 错误：创建或添加新相机输入失败: \(error)") // 日志
                    session.commitConfiguration()
                    
                    // 恢复会话状态
                    if wasRunning {
                        session.startRunning()
                        self.isRunning = true
                    }
                    
                    completion(false, "创建新相机输入失败: \(error.localizedDescription)")
                    return
                }
                
                // 提交配置
                session.commitConfiguration()
                print("[CameraSingleton] 会话配置已提交") // 日志
                
                // 更新预览层
                print("[CameraSingleton] 准备调用 recreatePreviewLayer") // 日志
                self.recreatePreviewLayer()
                
                // 如果原来在运行，重新启动
                if wasRunning {
                    print("[CameraSingleton] 准备在后台线程重启会话") // 日志
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                        print("[CameraSingleton] 后台线程：会话已调用 startRunning") // 日志
                        
                        DispatchQueue.main.async {
                            self.isRunning = true
                            print("[CameraSingleton] 主线程：isRunning 设置为 true") // 日志
                            // 检查会话实际运行状态
                            let sessionActuallyRunning = session.isRunning // 在主线程检查
                            print("[CameraSingleton] 主线程：检查会话实际状态: isRunning = \(sessionActuallyRunning)") // 日志
                            
                            // 发送缩放变化事件
                            self.sendEvent(type: "zoomChanged", data: [
                                "zoomFactor": zoomLevel,
                                "deviceType": self.deviceTypeToString(targetDeviceType)
                            ])
                            
                            // 发送相机类型变化事件
                            self.sendEvent(type: "cameraTypeChanged", data: [
                                "deviceType": self.deviceTypeToString(targetDeviceType)
                            ])
                            
                            print("[CameraSingleton] 调用 completion(true, nil) (会话重启后)") // 日志
                            completion(true, nil)
                        }
                    }
                } else {
                    print("[CameraSingleton] 调用 completion(true, nil) (会话未运行)") // 日志
                    completion(true, nil)
                }
            } catch {
                // 提交配置以结束配置会话
                session.commitConfiguration()
                
                print("[CameraSingleton] 错误：切换相机类型时发生异常: \(error)") // 日志
                
                // 恢复会话状态
                if wasRunning {
                    session.startRunning()
                    self.isRunning = true
                }
                
                // 尝试在当前相机上调整数字变焦
                self.adjustDigitalZoomOnly(zoomLevel, completion: completion)
            }
        }
    }
    
    /// 重新创建预览层并通知客户端更新视图
    private func recreatePreviewLayer() {
        guard let session = captureSession else { 
            print("[CameraSingleton] recreatePreviewLayer 失败：会话为空") // 日志
            return 
        }
        print("[CameraSingleton] recreatePreviewLayer 开始") // 日志
        
        // 在主线程处理UI相关操作
        DispatchQueue.main.async {
            print("[CameraSingleton] recreatePreviewLayer - 主线程") // 日志
            // 移除旧的预览层引用
            if let oldLayer = self.previewLayer {
                oldLayer.removeFromSuperlayer()
                print("[CameraSingleton] recreatePreviewLayer - 旧预览层已移除") // 日志
            }
            
            // 创建新的预览层
            let newLayer = AVCaptureVideoPreviewLayer(session: session)
            newLayer.videoGravity = .resizeAspectFill
            print("[CameraSingleton] recreatePreviewLayer - 新预览层已创建，Session: \(newLayer.session?.description ?? "nil")") // 日志
            
            // 更新引用
            self.previewLayer = newLayer
            
            // 发送预览层更新事件
            print("[CameraSingleton] recreatePreviewLayer - 准备发送 previewLayerUpdated 事件") // 日志
            self.sendEvent(type: "previewLayerUpdated", data: [:])
            
            // 延迟发送诊断信息
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.sendDiagnosticInfo()
            }
        }
    }
    
    /// 仅调整数字变焦
    private func adjustDigitalZoomOnly(_ zoomLevel: CGFloat, completion: ((Bool, String?) -> Void)? = nil) {
        guard let device = currentDevice else {
            completion?(false, "当前设备不可用")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // 计算有效的缩放值
            let effectiveZoom = calculateEffectiveZoom(forDeviceType: currentDeviceType, requestedZoom: zoomLevel)
            
            // 确保缩放值在合法范围内
            let zoom = min(max(effectiveZoom, device.minAvailableVideoZoomFactor), device.activeFormat.videoMaxZoomFactor)
            device.videoZoomFactor = zoom
            currentZoomFactor = zoom
            
            device.unlockForConfiguration()
            
            // 发送缩放变化事件
            sendEvent(type: "zoomChanged", data: [
                "zoomFactor": zoomLevel,
                "deviceType": deviceTypeToString(currentDeviceType)
            ])
            
            completion?(true, nil)
        } catch {
            completion?(false, "设置缩放级别失败: \(error.localizedDescription)")
        }
    }
    
    /// 计算特定设备类型的有效缩放值
    private func calculateEffectiveZoom(forDeviceType deviceType: AVCaptureDevice.DeviceType, requestedZoom: CGFloat) -> CGFloat {
        if #available(iOS 13.0, *) {
            if deviceType == .builtInUltraWideCamera {
                // 超广角相机: 0.5x-1x 范围
                if requestedZoom < 1.0 {
                    // 直接使用物理镜头，所以乘以2来匹配UI显示的0.5x效果
                    return requestedZoom * 2.0
                } else {
                    return requestedZoom
                }
            }
        }
        
        switch deviceType {
        case .builtInWideAngleCamera:
            // 广角相机：正常使用1.0开始
            return requestedZoom
        case .builtInTelephotoCamera:
            // 长焦相机：通常是2x或3x，需要根据实际镜头调整数值
            // 这里假设长焦是3x镜头，所以除以3来得到实际缩放因子
            return requestedZoom / 3.0
        default:
            return requestedZoom
        }
    }
    
    /// 设备类型转字符串
    private func deviceTypeToString(_ deviceType: AVCaptureDevice.DeviceType) -> String {
        if #available(iOS 13.0, *) {
            if deviceType == .builtInUltraWideCamera {
                return "ultraWide"
            }
        }
        
        switch deviceType {
        case .builtInWideAngleCamera:
            return "wide"
        case .builtInTelephotoCamera:
            return "telephoto"
        default:
            return "unknown"
        }
    }
    
    /// 设置闪光灯模式
    func setFlashMode(_ mode: String, completion: ((Bool, String?) -> Void)? = nil) {
        guard let device = currentDevice else {
            completion?(false, "当前设备不可用")
            return
        }
        
        print("设置闪光灯模式: \(mode)")
        
        // 转换字符串模式为AVCaptureDevice.FlashMode
        let flashMode: AVCaptureDevice.FlashMode
        switch mode {
        case "auto":
            flashMode = .auto
        case "on":
            flashMode = .on
        case "off":
            flashMode = .off
        default:
            flashMode = .auto // 默认为自动
        }
        
        // 检查设备是否支持此闪光灯模式
        if device.hasFlash && device.isFlashAvailable && device.isFlashModeSupported(flashMode) {
            do {
                try device.lockForConfiguration()
                device.flashMode = flashMode
                device.unlockForConfiguration()
                
                // 发送闪光灯模式变化事件
                print("发送闪光灯模式变化事件: \(mode)")
                sendEvent(type: "flashModeChanged", data: ["mode": mode])
                
                completion?(true, nil)
            } catch {
                print("设置闪光灯模式失败: \(error.localizedDescription)")
                completion?(false, "设置闪光灯模式失败: \(error.localizedDescription)")
            }
        } else {
            print("设备不支持当前闪光灯模式")
            completion?(false, "设备不支持当前闪光灯模式")
        }
    }
    
    /// 设置曝光级别
    func setExposureLevel(_ value: Double, completion: @escaping (Bool, String?) -> Void) {
        guard isInitialized, isRunning, let device = currentDevice else {
            completion(false, "相机未初始化或未运行")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // iOS中曝光补偿范围通常是-8到8，我们需要将-2到2的范围映射到iOS的范围
            if device.isExposureModeSupported(.custom) {
                // 将-2到2范围映射到设备支持的曝光补偿范围
                let minExposure = Float(device.minExposureTargetBias)
                let maxExposure = Float(device.maxExposureTargetBias)
                let normalizedValue = Float((value + 2.0) / 4.0) // 转换为0-1范围
                let scaledValue = minExposure + normalizedValue * (maxExposure - minExposure)
                
                // 设置曝光偏移
                device.setExposureTargetBias(scaledValue, completionHandler: nil)
                
                // 发送曝光更改事件
                sendEvent(type: "exposureChanged", data: [
                    "exposureValue": value,
                    "success": true
                ])
            } else {
                // 如果不支持自定义曝光，尝试使用自动曝光
                if device.isExposureModeSupported(.autoExpose) {
                    device.exposureMode = .autoExpose
                    
                    // 发送曝光更改事件，但告知客户端不支持精确曝光设置
                    sendEvent(type: "exposureChanged", data: [
                        "exposureValue": 0.0, // 默认为0（中间值）
                        "success": true,
                        "message": "设备不支持自定义曝光，已设置为自动曝光"
                    ])
                } else {
                    device.unlockForConfiguration()
                    completion(false, "设备不支持曝光控制")
                    return
                }
            }
            
            device.unlockForConfiguration()
            completion(true, nil)
        } catch {
            completion(false, "设置曝光级别失败: \(error.localizedDescription)")
        }
    }
    
    /// 拍照
    func capturePhoto(completion: @escaping (Data?, String?) -> Void) {
        guard isInitialized, isRunning, let photoOutput = photoOutput else {
            completion(nil, "相机未初始化或未运行")
            return
        }
        
        // 确保有可用的视频连接
        guard let videoConnection = photoOutput.connection(with: .video) else {
            completion(nil, "无法获取视频连接")
            return
        }
        
        // 创建拍照设置
        let settings = AVCapturePhotoSettings()
        
        // 检查是否支持自动闪光灯
        let autoFlashSupported: Bool
        if #available(iOS 10.0, *) {
            autoFlashSupported = photoOutput.supportedFlashModes.contains(.auto)
        } else {
            autoFlashSupported = true // 在旧版iOS上假设支持
        }
        if autoFlashSupported {
            settings.flashMode = .auto
        }
        
        // 设置高质量照片捕获
        settings.isHighResolutionPhotoEnabled = true
        
        // 创建照片捕获代理
        let photoCaptureProcessor = PhotoCaptureProcessor { (data, error) in
            if let error = error {
                completion(nil, "拍照失败: \(error.localizedDescription)")
                return
            }
            
            guard let data = data else {
                completion(nil, "拍照数据为空")
                return
            }
            
            completion(data, nil)
        }
        
        // 执行拍照
        photoOutput.capturePhoto(with: settings, delegate: photoCaptureProcessor)
    }
    
    /// 检查当前是否是前置相机
    func isFrontCamera() -> Bool {
        return currentPosition == .front
    }
    
    /// 发送事件到Flutter
    func sendEvent(type: String, data: [String: Any] = [:]) {
        // 处理特殊的事件类型
        if type == "previewLayerUpdated" {
            // 通过通知中心发送预览层更新事件
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: NSNotification.Name("com.haohaopai.app.PreviewLayerUpdated"),
                    object: nil
                )
            }
        }
        
        guard let sink = eventSink else {
            return
        }
        
        var eventData = data
        eventData["type"] = type
        
        DispatchQueue.main.async {
            sink(eventData)
        }
    }
    
    /// 处理应用进入活跃状态
    func applicationDidBecomeActive() {
        NSLog("CameraSingleton: 应用进入活跃状态")
        
        // 如果相机之前在运行，则恢复相机
        if wasRunningBeforeBackground {
            self.resumePreview()
            wasRunningBeforeBackground = false
        }
        
        // 确保恢复事件通道通信
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            // 通过发送一个通信恢复事件来测试通道是否正常
            self.sendEvent(type: "appStateChanged", data: ["state": "active"])
        }
    }
    
    /// 处理应用进入非活跃状态
    func applicationWillResignActive() {
        NSLog("CameraSingleton: 应用进入非活跃状态")
        
        // 记录相机是否正在运行
        wasRunningBeforeBackground = isRunning
        
        // 暂停相机预览
        if isRunning {
            self.pausePreview()
        }
        
        // 发送通信暂停事件
        sendEvent(type: "appStateChanged", data: ["state": "inactive"])
    }
    
    /// 诊断当前相机状态
    func diagnoseCameraState() -> [String: Any] {
        var state: [String: Any] = [:]
        
        // 基本状态
        state["isInitialized"] = isInitialized
        state["isRunning"] = isRunning
        state["currentPosition"] = currentPosition == .back ? "back" : "front"
        
        // 设备类型
        var deviceTypeString = "unknown"
        if #available(iOS 13.0, *), currentDeviceType == .builtInUltraWideCamera {
            deviceTypeString = "ultraWide"
        } else if currentDeviceType == .builtInWideAngleCamera {
            deviceTypeString = "wide"
        } else if currentDeviceType == .builtInTelephotoCamera {
            deviceTypeString = "telephoto"
        }
        state["currentDeviceType"] = deviceTypeString
        
        // 缩放信息
        state["currentZoomFactor"] = currentZoomFactor
        state["hasUltraWideCamera"] = hasUltraWideCamera
        state["hasTelephotoCamera"] = hasTelephotoCamera
        
        // 会话信息
        if let session = captureSession {
            state["sessionPreset"] = session.sessionPreset.rawValue
            state["isSessionRunning"] = session.isRunning
            state["inputCount"] = session.inputs.count
            state["outputCount"] = session.outputs.count
        } else {
            state["session"] = "null"
        }
        
        // 预览层信息
        if let layer = previewLayer {
            state["previewLayerBounds"] = "\(layer.bounds.width)x\(layer.bounds.height)"
            state["previewLayerVideoGravity"] = layer.videoGravity.rawValue
            state["previewLayerHasConnection"] = layer.connection != nil
        } else {
            state["previewLayer"] = "null"
        }
        
        print("相机状态诊断: \(state)")
        return state
    }
    
    /// 发送相机状态诊断信息
    func sendDiagnosticInfo() {
        let diagnosticInfo = diagnoseCameraState()
        sendEvent(type: "diagnosticInfo", data: diagnosticInfo)
    }
    
    // MARK: - 私有方法
    
    /// 检查相机权限
    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            // 已有权限
            completion(true)
            
        case .notDetermined:
            // 请求权限
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
            
        case .denied, .restricted:
            // 权限被拒绝或受限
            completion(false)
            
        @unknown default:
            // 未知状态，假设无权限
            completion(false)
        }
    }
    
    /// 设置捕获会话
    private func setupCaptureSession() throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 开始配置
        session.beginConfiguration()
        
        // 设置会话预设
        // 使用 .photo 预设，这会提供更高质量的预览
        // 原来是 .high，这可能不是最适合显示的分辨率
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        // 配置相机输入
        try configureCamera(position: .back)
        
        // 配置视频输出
        try configureVideoOutput()
        
        // 配置照片输出
        try configurePhotoOutput()
        
        // 提交配置
        session.commitConfiguration()
    }
    
    /// 配置相机（输入）
    private func configureCamera(position: AVCaptureDevice.Position) throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除现有的输入
        if let currentInput = currentDeviceInput {
            session.removeInput(currentInput)
            currentDeviceInput = nil
        }
        
        // 检查设备支持能力
        checkCameraCapabilities()
        
        // 获取指定位置的相机
        guard let newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
            throw NSError(domain: "com.haohaopai.app", code: 1002, userInfo: [NSLocalizedDescriptionKey: "找不到指定位置的相机"])
        }
        
        // 创建相机输入
        let newInput = try AVCaptureDeviceInput(device: newCamera)
        
        // 添加到会话
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentDeviceInput = newInput
            currentDevice = newCamera
            currentPosition = position
            currentZoomFactor = 1.0 // 重置缩放
            currentDeviceType = .builtInWideAngleCamera // 默认使用广角相机
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1003, userInfo: [NSLocalizedDescriptionKey: "无法添加相机输入到会话"])
        }
    }
    
    /// 检查相机能力
    private func checkCameraCapabilities() {
        // 根据iOS版本确定设备类型列表
        var deviceTypes: [AVCaptureDevice.DeviceType] = [.builtInWideAngleCamera, .builtInTelephotoCamera]
        
        // 仅在iOS 13及以上添加超广角相机
        if #available(iOS 13.0, *) {
            deviceTypes.append(.builtInUltraWideCamera)
        }
        
        // 发现相机设备
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: currentPosition
        )
        
        // 重置状态
        hasUltraWideCamera = false
        hasTelephotoCamera = false
        
        // 检查支持的相机类型
        for device in discoverySession.devices {
            if #available(iOS 13.0, *) {
                if device.deviceType == .builtInUltraWideCamera {
                    hasUltraWideCamera = true
                    print("检测到超广角相机")
                    continue
                }
            }
            
            switch device.deviceType {
            case .builtInTelephotoCamera:
                hasTelephotoCamera = true
                print("检测到长焦相机")
            default:
                break
            }
        }
        
        // 根据设备能力调整缩放阈值
        zoomThresholds = getOptimalSwitchPoints()
    }
    
    /// 获取最佳切换点
    private func getOptimalSwitchPoints() -> (wideToUltraWide: CGFloat, wideToTele: CGFloat) {
        return (
            wideToUltraWide: hasUltraWideCamera ? 0.8 : CGFloat.infinity,
            wideToTele: hasTelephotoCamera ? 2.7 : CGFloat.infinity
        )
    }
    
    /// 配置视频输出
    private func configureVideoOutput() throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除现有的视频输出
        if let currentOutput = videoDataOutput {
            session.removeOutput(currentOutput)
        }
        
        // 创建新的视频输出
        let newVideoOutput = AVCaptureVideoDataOutput()
        
        // 配置视频输出设置
        newVideoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        
        // 创建串行队列处理视频帧
        let videoQueue = DispatchQueue(label: "com.haohaopai.app.videoQueue")
        newVideoOutput.setSampleBufferDelegate(self, queue: videoQueue)
        
        // 添加到会话
        if session.canAddOutput(newVideoOutput) {
            session.addOutput(newVideoOutput)
            videoDataOutput = newVideoOutput
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1004, userInfo: [NSLocalizedDescriptionKey: "无法添加视频输出到会话"])
        }
    }
    
    /// 配置照片输出
    private func configurePhotoOutput() throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除现有的照片输出
        if let currentOutput = photoOutput {
            session.removeOutput(currentOutput)
        }
        
        // 创建新的照片输出
        let newPhotoOutput = AVCapturePhotoOutput()
        
        // 配置照片输出设置
        newPhotoOutput.isHighResolutionCaptureEnabled = true
        
        // 添加到会话
        if session.canAddOutput(newPhotoOutput) {
            session.addOutput(newPhotoOutput)
            photoOutput = newPhotoOutput
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1005, userInfo: [NSLocalizedDescriptionKey: "无法添加照片输出到会话"])
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 这里可以处理视频帧
        // 如果需要实现即时帧处理功能，可以在这里添加代码
    }
}

// MARK: - 照片捕获处理器
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?, Error?) -> Void
    
    init(completion: @escaping (Data?, Error?) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error = error {
            completion(nil, error)
            return
        }
        
        // 获取照片数据
        guard let imageData = photo.fileDataRepresentation() else {
            completion(nil, NSError(domain: "com.haohaopai.app", code: 1006, userInfo: [NSLocalizedDescriptionKey: "无法获取照片数据"]))
            return
        }
        
        completion(imageData, nil)
    }
} 