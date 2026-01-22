import AVFoundation
import UIKit
import Flutter
import CoreMotion  // 添加CoreMotion框架

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
    
    // 当前纵横比设置
    private var currentAspectRatio: String = "4:3"
    
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
    
    // 虚拟摄像头支持
    private var hasVirtualDeviceSupport: Bool = false
    private var virtualDeviceSwitchPoints: [CGFloat] = []
    
    // 多摄像头支持
    private var hasUltraWideCamera: Bool = false
    // 是否支持长焦相机
    private var hasTelephotoCamera: Bool = false
    
    // 事件发送器
    private var eventSink: FlutterEventSink?
    
    // 初始化锁，防止多线程初始化冲突
    private let initializationLock = NSLock()
    
    // 标记是否正在进行初始化过程
    private var isInitializing = false
    
    // 私有变量
    private var wasRunningBeforeBackground = false
    
    // 添加CoreMotion管理器
    private let motionManager = CMMotionManager()
    private var lastKnownDeviceOrientation: UIDeviceOrientation = .portrait
    
    // 公共方法 - 检查相机是否已初始化
    var isCameraInitialized: Bool {
        return isInitialized
    }
    
    // 表示相机是否已初始化
    // var isInitialized = false
    
    // 私有构造函数确保单例模式
    private override init() {
        super.init()
        captureSession = AVCaptureSession()
        
        // 初始化设备方向检测
        startDeviceOrientationTracking()
    }
    
    deinit {
        stopDeviceOrientationTracking()
    }
    
    // 开始追踪设备方向
    private func startDeviceOrientationTracking() {
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.2
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (motion, error) in
                guard let self = self, let motion = motion else { return }
                
                let orientation = self.deviceOrientationFromMotion(motion)
                if orientation != .unknown {
                    self.lastKnownDeviceOrientation = orientation
                }
            }
        } else {
            // 回退到UIDevice方法
            if !UIDevice.current.isGeneratingDeviceOrientationNotifications {
                UIDevice.current.beginGeneratingDeviceOrientationNotifications()
            }
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(deviceOrientationDidChange),
                name: UIDevice.orientationDidChangeNotification,
                object: nil
            )
        }
    }
    
    // 停止追踪设备方向
    private func stopDeviceOrientationTracking() {
        if motionManager.isDeviceMotionActive {
            motionManager.stopDeviceMotionUpdates()
        }
        
        // 停止UIDevice通知
        if UIDevice.current.isGeneratingDeviceOrientationNotifications {
            UIDevice.current.endGeneratingDeviceOrientationNotifications()
        }
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    // 从CoreMotion数据计算设备方向
    private func deviceOrientationFromMotion(_ motion: CMDeviceMotion) -> UIDeviceOrientation {
        // 重力向量
        let x = motion.gravity.x
        let y = motion.gravity.y
        let z = motion.gravity.z
        
        // 计算倾斜角度
        let absoluteX = abs(x)
        let absoluteY = abs(y)
        
        // 确定设备方向 - 修正竖向判断逻辑
        if z < -0.75 {
            return .faceUp
        } else if z > 0.75 {
            return .faceDown
        } else if absoluteX < 0.5 && y < -0.5 {
            // 注意：y轴重力向量为负值时表示设备正常竖直方向（Home键在下）
            return .portrait
        } else if absoluteX < 0.5 && y > 0.5 {
            // 注意：y轴重力向量为正值时表示设备倒置（Home键在上）
            return .portraitUpsideDown
        } else if x > 0.5 && absoluteY < 0.5 {
            return .landscapeRight
        } else if x < -0.5 && absoluteY < 0.5 {
            return .landscapeLeft
        }
        
        // 返回最后已知方向，或默认为portrait
        return lastKnownDeviceOrientation
    }
    
    // 处理UIDevice方向变化通知
    @objc private func deviceOrientationDidChange() {
        let orientation = UIDevice.current.orientation
        if orientation != .unknown && orientation != .faceUp && orientation != .faceDown {
            lastKnownDeviceOrientation = orientation
        }
    }
    
    // 获取当前设备方向（结合CoreMotion和UIDevice）
    func getCurrentDeviceOrientation() -> UIDeviceOrientation {
        // 如果CoreMotion正在运行，使用lastKnownDeviceOrientation
        if motionManager.isDeviceMotionActive {
            return lastKnownDeviceOrientation
        }
        
        // 否则尝试使用UIDevice
        let orientation = UIDevice.current.orientation
        if orientation != .unknown {
            return orientation
        }
        
        // 如果都不可用，返回最后已知方向或默认值
        return lastKnownDeviceOrientation
    }
    
    // MARK: - 公共方法
    
    /// 检查相机是否已准备就绪（接受回调函数）
    func isCameraReady(completion: @escaping (Bool) -> Void) {
        completion(isInitialized && isRunning)
    }
    
    /// 检查相机是否已准备就绪
    func isCameraReady(_ result: FlutterResult) {
        result(isCameraInitialized)
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
    func initializeCamera(completionHandler: @escaping (Bool) -> Void) {
        NSLog("CameraSingleton: 开始初始化相机")
        
        // 使用锁确保线程安全
        initializationLock.lock()
        defer { initializationLock.unlock() }
        
        // 如果相机已经初始化或正在初始化过程中，直接返回成功
        if isInitialized {
            NSLog("CameraSingleton: 相机已经初始化过，跳过初始化")
            completionHandler(true)
            return
        }
        
        // 检查是否已经在初始化过程中
        if isInitializing {
            NSLog("CameraSingleton: 相机已经在初始化过程中，添加完成回调")
            initializationCompletionHandlers.append(completionHandler)
            return
        }
        
        isInitializing = true
        
        // 清理任何已存在的会话
        cleanupOldSession()
        
        // 检查相机权限
        checkCameraPermission { [weak self] hasPermission in
            guard let self = self else {
                self?.isInitializing = false
                completionHandler(false)
                return
            }
            
            if !hasPermission {
                self.isInitializing = false
                completionHandler(false)
                self.notifyInitializationCompleted(success: false)
                return
            }
            
            // 在后台线程设置相机
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    // 确保我们有一个干净的captureSession
                    if let oldSession = self.captureSession {
                        // 停止当前会话
                        if oldSession.isRunning {
                            oldSession.stopRunning()
                            self.isRunning = false
                        }
                        
                        // 移除所有输入和输出
                        for input in oldSession.inputs {
                            oldSession.removeInput(input)
                        }
                        for output in oldSession.outputs {
                            oldSession.removeOutput(output)
                        }
                    } else {
                        // 如果没有会话，创建一个新的
                        self.captureSession = AVCaptureSession()
                    }
                    
                    try self.setupCaptureSession()
                    self.isInitialized = true
                    
                    // 在主线程返回结果
                    DispatchQueue.main.async {
                        self.isInitializing = false
                        self.notifyInitializationCompleted(success: true)
                        completionHandler(true)
                    }
                } catch {
                    // 在主线程返回错误
                    DispatchQueue.main.async {
                        self.isInitializing = false
                        self.notifyInitializationCompleted(success: false)
                        completionHandler(false)
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
    
    /// 设置系统级缩放效果 (支持虚拟摄像头和超广角相机)
    func setSystemLikeZoom(_ zoomLevel: CGFloat, completion: @escaping (Bool, String?) -> Void) {
        guard isInitialized, let device = currentDevice else {
            completion(false, "相机未初始化或设备不可用")
            return
        }
        
        // 如果是虚拟摄像头(iOS 13+)，使用虚拟摄像头的无缝缩放功能
        if #available(iOS 13.0, *), hasVirtualDeviceSupport && 
            (device.deviceType == .builtInDualWideCamera || 
             device.deviceType == .builtInTripleCamera || 
             device.deviceType == .builtInDualCamera) {
            
            do {
                try device.lockForConfiguration()
                
                // 确保缩放值在合法范围内
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 10.0) // 限制最大缩放为10倍，提高用户体验
                let constrainedZoom = min(max(zoomLevel, minZoom), maxZoom)
                
                // 使用更平滑的缩放变化 - 防止卡顿
                device.ramp(toVideoZoomFactor: constrainedZoom, withRate: 4.0)
                currentZoomFactor = constrainedZoom
                
                device.unlockForConfiguration()
                
                // 发送缩放变化事件
                sendEvent(type: "virtualDeviceZoomChanged", data: [
                    "zoomFactor": constrainedZoom,
                    "isSmooth": true,
                    "deviceType": "virtual" // 标记为虚拟设备
                ])
                
                completion(true, nil)
                return
            } catch {
                print("设置虚拟摄像头缩放失败: \(error.localizedDescription)")
                // 如果失败，继续尝试传统方法
            }
        }
        
        // 如果没有虚拟摄像头支持或虚拟摄像头设置失败，使用传统的摄像头切换方法
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
            
            guard let session = self.captureSession else {
                completion(false, "相机会话不可用")
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
                    print("[CameraSingleton] 找不到指定类型的相机设备: \(targetDeviceType)")
                    
                    // 恢复会话状态
                    if wasRunning {
                        session.startRunning()
                        self.isRunning = true
                    }
                    
                    completion(false, "找不到指定类型的相机设备")
                    return
                }
                print("[CameraSingleton] 找到新设备: \(newDevice.localizedName)")
                
                // 保存当前输入输出
                let currentInput = self.currentDeviceInput
                
                // 移除当前输入
                if let input = currentInput {
                    session.removeInput(input)
                    self.currentDeviceInput = nil
                    print("[CameraSingleton] 已移除旧输入")
                }
                
                // 创建新的输入
                do {
                    let newInput = try AVCaptureDeviceInput(device: newDevice)
                    print("[CameraSingleton] 已创建新输入")
                    
                    // 添加新输入
                    if session.canAddInput(newInput) {
                        session.addInput(newInput)
                        self.currentDeviceInput = newInput
                        self.currentDevice = newDevice
                        self.currentDeviceType = targetDeviceType
                        print("[CameraSingleton] 已添加新输入到会话")
                        
                        // 设置缩放级别
                        try newDevice.lockForConfiguration()
                        
                        // 计算有效的缩放值
                        let effectiveZoom = self.calculateEffectiveZoom(forDeviceType: targetDeviceType, requestedZoom: zoomLevel)
                        
                        // 使用平滑的缩放变化
                        if #available(iOS 13.0, *) {
                            newDevice.ramp(toVideoZoomFactor: effectiveZoom, withRate: 4.0)
                        } else {
                            newDevice.videoZoomFactor = effectiveZoom
                        }
                        self.currentZoomFactor = effectiveZoom
                        
                        // 配置自动对焦和曝光
                        if newDevice.isFocusModeSupported(.continuousAutoFocus) {
                            newDevice.focusMode = .continuousAutoFocus
                        }
                        
                        if newDevice.isExposureModeSupported(.continuousAutoExposure) {
                            newDevice.exposureMode = .continuousAutoExposure
                        }
                        
                        newDevice.unlockForConfiguration()
                        
                        print("[CameraSingleton] 新设备配置完成，有效缩放: \(effectiveZoom)")
                    } else {
                        // 如果无法添加新输入，恢复旧输入
                        if let input = currentInput {
                            if session.canAddInput(input) {
                                session.addInput(input)
                                self.currentDeviceInput = input
                            }
                        }
                        
                        print("[CameraSingleton] 错误：无法添加新输入到会话")
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
                    
                    print("[CameraSingleton] 错误：创建或添加新相机输入失败: \(error)")
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
                print("[CameraSingleton] 会话配置已提交")
                
                // 更新预览层
                print("[CameraSingleton] 准备调用 recreatePreviewLayer")
                self.recreatePreviewLayer()
                
                // 如果原来在运行，重新启动
                if wasRunning {
                    print("[CameraSingleton] 准备在后台线程重启会话")
                    DispatchQueue.global(qos: .userInitiated).async {
                        session.startRunning()
                        print("[CameraSingleton] 后台线程：会话已调用 startRunning")
                        
                        DispatchQueue.main.async {
                            self.isRunning = true
                            print("[CameraSingleton] 主线程：isRunning 设置为 true")
                            
                            // 发送缩放变化事件
                            self.sendEvent(type: "zoomChanged", data: [
                                "zoomFactor": zoomLevel,
                                "deviceType": self.deviceTypeToString(targetDeviceType)
                            ])
                            
                            // 发送相机类型变化事件
                            self.sendEvent(type: "cameraTypeChanged", data: [
                                "deviceType": self.deviceTypeToString(targetDeviceType)
                            ])
                            
                            print("[CameraSingleton] 调用 completion(true, nil) (会话重启后)")
                            completion(true, nil)
                        }
                    }
                } else {
                    print("[CameraSingleton] 调用 completion(true, nil) (会话未运行)")
                    completion(true, nil)
                }
            } catch {
                // 提交配置以结束配置会话
                session.commitConfiguration()
                
                print("[CameraSingleton] 错误：切换相机类型时发生异常: \(error)")
                
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
            let minZoom = device.minAvailableVideoZoomFactor
            let maxZoom = min(device.activeFormat.videoMaxZoomFactor, 10.0) // 限制最大缩放为10倍
            let zoom = min(max(effectiveZoom, minZoom), maxZoom)
            
            // 使用更平滑的缩放变化
            if #available(iOS 13.0, *) {
                device.ramp(toVideoZoomFactor: zoom, withRate: 4.0)
            } else {
                device.videoZoomFactor = zoom
            }
            
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
                
                // 设置闪光灯模式
                device.flashMode = flashMode
                
                // 如果是虚拟摄像头，可能需要特殊处理
                if #available(iOS 13.0, *), hasVirtualDeviceSupport && 
                   (device.deviceType == .builtInTripleCamera || 
                    device.deviceType == .builtInDualWideCamera || 
                    device.deviceType == .builtInDualCamera) {
                    // 对于虚拟设备，闪光灯功能通常在广角镜头上
                    print("在虚拟摄像头上设置闪光灯: \(mode)")
                }
                
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
            
            // 支持iOS虚拟摄像头的曝光控制
            let exposureSupported: Bool
            
            if #available(iOS 13.0, *) {
                // 对于虚拟摄像头和标准摄像头，都应该支持曝光控制
                exposureSupported = device.isExposureModeSupported(.custom) || 
                                    device.isExposureModeSupported(.continuousAutoExposure)
            } else {
                exposureSupported = device.isExposureModeSupported(.custom)
            }
            
            if exposureSupported {
                // 将-2到2范围映射到设备支持的曝光补偿范围
                let minExposure = Float(device.minExposureTargetBias)
                let maxExposure = Float(device.maxExposureTargetBias)
                let normalizedValue = Float((value + 2.0) / 4.0) // 转换为0-1范围
                let scaledValue = minExposure + normalizedValue * (maxExposure - minExposure)
                
                // 设置曝光偏移 - 使用平滑过渡提升用户体验
                if #available(iOS 13.0, *) {
                    // 对于iOS 13+，支持更平滑的曝光变化
                    device.setExposureTargetBias(scaledValue, completionHandler: nil)
                    
                    // 如果是虚拟设备，确保曝光模式设置正确
                    if hasVirtualDeviceSupport {
                        if device.exposureMode != .custom && device.exposureMode != .continuousAutoExposure {
                            // 对于虚拟设备，连续自动曝光通常效果更好
                            device.exposureMode = device.isExposureModeSupported(.continuousAutoExposure) ? 
                                                  .continuousAutoExposure : .custom
                        }
                    } else {
                        // 非虚拟设备使用自定义模式
                        if device.exposureMode != .custom {
                            device.exposureMode = .custom
                        }
                    }
                } else {
                    // iOS 13以下的标准实现
                    device.setExposureTargetBias(scaledValue, completionHandler: nil)
                    
                    if device.exposureMode != .custom {
                        device.exposureMode = .custom
                    }
                }
                
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
    
    /// 设置拍摄比例
    func setAspectRatio(_ ratio: String, completion: ((Bool, String?) -> Void)? = nil) {
        guard ["4:3", "1:1", "16:9"].contains(ratio) else {
            print("【拍照流程】错误：不支持的比例设置: \(ratio)")
            completion?(false, "不支持的比例设置: \(ratio)")
            return
        }
        
        print("【拍照流程】设置拍摄比例: \(ratio)")
        currentAspectRatio = ratio
        
        // 应用纵横比设置，这里只记录值，在拍照时应用
        // 预览层的纵横比由 Flutter 端控制
        
        // 发送事件通知前端比例已更改
        sendEvent(type: "aspectRatioChanged", data: [
            "aspectRatio": ratio,
            "success": true
        ])
        
        completion?(true, nil)
    }
    
    /// 拍照
    func capturePhoto(completion: @escaping (Data?, String?) -> Void) {
        print("【拍照流程】开始拍照")
        guard isInitialized, isRunning, let photoOutput = photoOutput else {
            print("【拍照流程】错误：相机未初始化或未运行")
            completion(nil, "相机未初始化或未运行")
            return
        }
        
        // 确保有可用的视频连接
        guard let videoConnection = photoOutput.connection(with: .video) else {
            print("【拍照流程】错误：无法获取视频连接")
            completion(nil, "无法获取视频连接")
            return
        }
        
        // 获取当前设备方向并保存，用于照片处理 - 使用CoreMotion方法
        let deviceOrientation = getCurrentDeviceOrientation()
        
        // 创建拍照设置
        let settings = AVCapturePhotoSettings()
        
        // 应用当前设置的拍摄比例
        if currentAspectRatio != "4:3" {
            print("【拍照流程】应用自定义拍摄比例: \(currentAspectRatio)")
            
            // 根据比例设置裁剪区域
            var cropRect: CGRect?
            if #available(iOS 11.0, *) {
                // 获取传感器尺寸
                let dimensions = CMVideoFormatDescriptionGetDimensions(currentDevice!.activeFormat.formatDescription)
                let sensorWidth = CGFloat(dimensions.width)
                let sensorHeight = CGFloat(dimensions.height)
                
                // 计算不同比例下的裁剪区域
                switch currentAspectRatio {
                case "16:9":
                    // 保持宽度不变，调整高度以匹配16:9比例
                    let targetHeight = sensorWidth * 9.0 / 16.0
                    let yOffset = (sensorHeight - targetHeight) / 2.0
                    cropRect = CGRect(x: 0, y: yOffset, width: sensorWidth, height: targetHeight)
                    
                case "1:1":
                    // 以短边为准创建正方形区域
                    let minDimension = min(sensorWidth, sensorHeight)
                    let xOffset = (sensorWidth - minDimension) / 2.0
                    let yOffset = (sensorHeight - minDimension) / 2.0
                    cropRect = CGRect(x: xOffset, y: yOffset, width: minDimension, height: minDimension)
                    
                default:
                    break // 使用默认的4:3
                }
            } else {
                print("【拍照流程】iOS版本过低，无法应用自定义裁剪区域")
            }
        }
        
        // 检查是否支持闪光灯
        if let device = currentDevice, device.hasFlash && device.isFlashAvailable {
            if #available(iOS 10.0, *) {
                // 检查闪光灯模式支持
                if photoOutput.supportedFlashModes.contains(.auto) {
                    settings.flashMode = .auto
                }
            } else {
                settings.flashMode = .auto
            }
        }
        
        // 设置高质量照片捕获
        settings.isHighResolutionPhotoEnabled = true
        
        // 为确保回调被正确触发，先添加到主队列延迟执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                print("【拍照流程】错误：相机单例已被释放")
                completion(nil, "相机单例已被释放")
                return
            }
            
            guard let photoOutput = self.photoOutput else {
                print("【拍照流程】错误：photoOutput在主线程中变为nil")
                completion(nil, "photoOutput在主线程中变为nil")
                return
            }
            
            // 创建照片捕获处理器，传递当前设备方向
            let photoCaptureProcessor = PhotoCaptureProcessor(aspectRatio: self.currentAspectRatio, deviceOrientation: deviceOrientation) { (data, error) in
                if let error = error {
                    print("【拍照流程】错误：拍照失败 - \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        completion(nil, "拍照失败: \(error.localizedDescription)")
                    }
                    return
                }
                
                guard let data = data else {
                    print("【拍照流程】错误：拍照数据为空")
                    DispatchQueue.main.async {
                        completion(nil, "拍照数据为空")
                    }
                    return
                }
                
                print("【拍照流程】成功获取照片数据，大小: \(data.count) 字节")
                
                DispatchQueue.main.async {
                    completion(data, nil)
                }
            }
            
            // 执行拍照
            photoOutput.capturePhoto(with: settings, delegate: photoCaptureProcessor)
            print("【拍照流程】拍照操作已提交，等待回调...")
        }
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
        state["isInitialized"] = isCameraInitialized
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
        
        // 设置会话预设 - 在iOS 13+上为了获得更好的图像质量，使用photo
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        
        // 配置相机输入
        // 注意：iOS 13+设备上会优先使用虚拟摄像头设备(如三摄或双摄)
        try configureCamera(position: .back)
        
        // 配置视频输出
        try configureVideoOutput()
        
        // 配置照片输出
        try configurePhotoOutput()
        
        // 提交配置
        session.commitConfiguration()
        
        // 打印诊断信息
        if #available(iOS 13.0, *), let device = currentDevice {
            print("当前设备类型: \(device.deviceType)")
            print("虚拟设备支持: \(hasVirtualDeviceSupport)")
            
            if hasVirtualDeviceSupport {
                print("切换点: \(virtualDeviceSwitchPoints)")
                print("最小缩放: \(device.minAvailableVideoZoomFactor)")
                print("最大缩放: \(device.maxAvailableVideoZoomFactor)")
            }
        }
    }
    
    /// 配置相机（输入）
    private func configureCamera(position: AVCaptureDevice.Position) throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除所有现有的输入
        for input in session.inputs {
            session.removeInput(input)
        }
        currentDeviceInput = nil
        
        // 检查设备支持能力
        checkCameraCapabilities()
        
        // 优先尝试获取虚拟摄像头设备 - 适配iOS 13+
        var newCamera: AVCaptureDevice?
        
        if #available(iOS 13.0, *), position == .back {
            // 优先尝试获取支持的虚拟摄像头设备（按优先级尝试）
            let deviceTypes: [AVCaptureDevice.DeviceType] = [
                .builtInTripleCamera,    // 超广角+广角+长焦（iPhone 12 Pro+）
                .builtInDualWideCamera,  // 超广角+广角（iPhone 11+）
                .builtInDualCamera       // 广角+长焦（iPhone 7 Plus - 11 Pro）
            ]
            
            // 使用discoverySession查找支持的虚拟摄像头
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: deviceTypes,
                mediaType: .video,
                position: position
            )
            
            // 使用第一个找到的虚拟设备
            newCamera = discoverySession.devices.first
            
            if let device = newCamera {
                print("成功获取虚拟设备：\(device.deviceType)")
                hasVirtualDeviceSupport = true
                
                // 获取虚拟设备切换点
                if let switchPoints = device.virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber] {
                    virtualDeviceSwitchPoints = switchPoints.map { CGFloat($0.doubleValue) }
                    print("虚拟设备切换点: \(virtualDeviceSwitchPoints)")
                }
            } else {
                print("未找到虚拟设备，将使用标准广角相机")
                hasVirtualDeviceSupport = false
            }
        }
        
        // 如果无法获取虚拟设备，退回到标准广角摄像头
        if newCamera == nil {
            print("使用标准广角摄像头")
            newCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position)
        }
        
        // 确保获取到了摄像头设备
        guard let camera = newCamera else {
            throw NSError(domain: "com.haohaopai.app", code: 1002, userInfo: [NSLocalizedDescriptionKey: "找不到指定位置的相机"])
        }
        
        // 创建相机输入
        let newInput = try AVCaptureDeviceInput(device: camera)
        
        // 添加到会话
        if session.canAddInput(newInput) {
            session.addInput(newInput)
            currentDeviceInput = newInput
            currentDevice = camera
            currentPosition = position
            currentZoomFactor = 1.0 // 重置缩放
            
            // 根据设备类型设置当前设备类型
            if #available(iOS 13.0, *) {
                if camera.deviceType == .builtInTripleCamera || 
                   camera.deviceType == .builtInDualWideCamera ||
                   camera.deviceType == .builtInDualCamera {
                    // 虚拟设备默认使用广角作为基础
                    currentDeviceType = .builtInWideAngleCamera
                    
                    // 为虚拟设备配置最佳设置
                    do {
                        try camera.lockForConfiguration()
                        
                        // 配置自动对焦和曝光
                        if camera.isFocusModeSupported(.continuousAutoFocus) {
                            camera.focusMode = .continuousAutoFocus
                        }
                        
                        if camera.isExposureModeSupported(.continuousAutoExposure) {
                            camera.exposureMode = .continuousAutoExposure
                        }
                        
                        // 移除视频稳定设置，这将在配置视频输出连接时设置
                        
                        camera.unlockForConfiguration()
                    } catch {
                        print("配置虚拟设备高级设置失败: \(error.localizedDescription)")
                    }
                } else {
                    currentDeviceType = camera.deviceType
                }
            } else {
                currentDeviceType = camera.deviceType
            }
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1003, userInfo: [NSLocalizedDescriptionKey: "无法添加相机输入到会话"])
        }
    }
    
    /// 检查相机能力
    private func checkCameraCapabilities() {
        // 根据iOS版本确定要检查的设备类型列表
        var standardDeviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera, 
            .builtInTelephotoCamera
        ]
        
        var virtualDeviceTypes: [AVCaptureDevice.DeviceType] = []
        
        // 仅在iOS 13及以上添加超广角相机和虚拟设备
        if #available(iOS 13.0, *) {
            standardDeviceTypes.append(.builtInUltraWideCamera)
            virtualDeviceTypes = [
                .builtInTripleCamera,    // 超广角+广角+长焦
                .builtInDualWideCamera,  // 超广角+广角
                .builtInDualCamera       // 广角+长焦
            ]
        }
        
        // 检查虚拟设备支持
        hasVirtualDeviceSupport = false
        if #available(iOS 13.0, *) {
            let virtualDiscoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: virtualDeviceTypes,
                mediaType: .video,
                position: .back
            )
            
            let virtualDevices = virtualDiscoverySession.devices
            if !virtualDevices.isEmpty {
                hasVirtualDeviceSupport = true
                
                // 记录找到的第一个虚拟设备类型（日志）
                if let firstDevice = virtualDevices.first {
                    print("检测到虚拟摄像头支持，类型: \(firstDevice.deviceType)")
                    
                    // 获取切换点
                    if let switchPoints = firstDevice.virtualDeviceSwitchOverVideoZoomFactors as? [NSNumber] {
                        virtualDeviceSwitchPoints = switchPoints.map { CGFloat($0.doubleValue) }
                        print("虚拟设备切换点: \(virtualDeviceSwitchPoints)")
                    }
                }
            }
        }
        
        // 如果不支持虚拟设备，则继续检查单独的相机设备
        if !hasVirtualDeviceSupport {
            // 发现标准相机设备
            let discoverySession = AVCaptureDevice.DiscoverySession(
                deviceTypes: standardDeviceTypes,
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
        } else {
            // 如果支持虚拟设备，则假设同时支持超广角和长焦
            if #available(iOS 13.0, *) {
                for deviceType in virtualDeviceTypes {
                    if deviceType == .builtInDualWideCamera || deviceType == .builtInTripleCamera {
                        hasUltraWideCamera = true
                    }
                    if deviceType == .builtInDualCamera || deviceType == .builtInTripleCamera {
                        hasTelephotoCamera = true
                    }
                }
            }
        }
        
        // 根据设备能力调整缩放阈值
        zoomThresholds = getOptimalSwitchPoints()
    }
    
    /// 获取最佳切换点
    private func getOptimalSwitchPoints() -> (wideToUltraWide: CGFloat, wideToTele: CGFloat) {
        // 如果有虚拟设备切换点，优先使用这些值
        if !virtualDeviceSwitchPoints.isEmpty {
            // 虚拟设备通常会有 1-2 个切换点，根据设备类型不同
            // 值通常是递增的，如 [2.0] 或 [0.5, 2.0]
            
            var wideToUltraWide: CGFloat = 0.8 // 默认值
            var wideToTele: CGFloat = 2.0 // 默认值
            
            // 根据切换点设置阈值
            if virtualDeviceSwitchPoints.count >= 2 {
                // 三摄设备通常是 [0.5, 2.0] - 超广角到广角，广角到长焦
                wideToUltraWide = virtualDeviceSwitchPoints[0]
                wideToTele = virtualDeviceSwitchPoints[1]
            } else if virtualDeviceSwitchPoints.count == 1 {
                // 双摄设备通常是 [2.0]（广角+长焦）或 [0.5]（超广角+广角）
                let point = virtualDeviceSwitchPoints[0]
                if point < 1.0 {
                    // 超广角+广角设备
                    wideToUltraWide = point
                    wideToTele = CGFloat.infinity
                } else {
                    // 广角+长焦设备
                    wideToUltraWide = CGFloat.infinity
                    wideToTele = point
                }
            }
            
            return (wideToUltraWide: wideToUltraWide, wideToTele: wideToTele)
        }
        
        // 如果没有虚拟设备切换点，使用默认值
        return (
            wideToUltraWide: hasUltraWideCamera ? 0.8 : CGFloat.infinity,
            wideToTele: hasTelephotoCamera ? 2.5 : CGFloat.infinity
        )
    }
    
    /// 配置视频输出
    private func configureVideoOutput() throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除所有视频输出
        for output in session.outputs {
            if output is AVCaptureVideoDataOutput {
                session.removeOutput(output)
            }
        }
        
        // 重置当前引用
        videoDataOutput = nil
        
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
            
            // 获取视频连接并配置视频稳定
            if let videoConnection = newVideoOutput.connection(with: .video) {
                // 设置视频方向
                if videoConnection.isVideoOrientationSupported {
                    videoConnection.videoOrientation = .portrait
                }
                
                // 设置视频稳定模式（如果支持）
                if videoConnection.isVideoStabilizationSupported {
                    videoConnection.preferredVideoStabilizationMode = .auto
                }
            }
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1004, userInfo: [NSLocalizedDescriptionKey: "无法添加视频输出到会话"])
        }
    }
    
    /// 配置照片输出
    private func configurePhotoOutput() throws {
        guard let session = captureSession else {
            throw NSError(domain: "com.haohaopai.app", code: 1001, userInfo: [NSLocalizedDescriptionKey: "捕获会话未创建"])
        }
        
        // 移除所有现有的照片输出
        for output in session.outputs {
            if output is AVCapturePhotoOutput {
                session.removeOutput(output)
            }
        }
        
        // 重置当前引用
        photoOutput = nil
        
        // 创建新的照片输出
        let newPhotoOutput = AVCapturePhotoOutput()
        
        // 配置照片输出设置
        newPhotoOutput.isHighResolutionCaptureEnabled = true
        
        // 添加到会话
        if session.canAddOutput(newPhotoOutput) {
            session.addOutput(newPhotoOutput)
            photoOutput = newPhotoOutput
            
            // 配置照片输出连接
            if let photoConnection = newPhotoOutput.connection(with: .video) {
                // 设置视频方向
                if photoConnection.isVideoOrientationSupported {
                    photoConnection.videoOrientation = .portrait
                }
                
                // 设置视频稳定（如果支持）
                if photoConnection.isVideoStabilizationSupported {
                    photoConnection.preferredVideoStabilizationMode = .auto
                }
            }
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1005, userInfo: [NSLocalizedDescriptionKey: "无法添加照片输出到会话"])
        }
    }
    
    // MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // 保存最新的视频帧，供"教我拍"功能使用
        latestSampleBuffer = sampleBuffer
    }
    
    // 清理之前的会话
    private func cleanupOldSession() {
        // 使用主队列确保线程安全
        if Thread.isMainThread {
            performCleanup()
        } else {
            DispatchQueue.main.sync {
                performCleanup()
            }
        }
    }
    
    // 执行实际的清理操作
    private func performCleanup() {
        // 如果captureSession已经存在且正在运行，先停止
        if captureSession?.isRunning == true {
            captureSession?.stopRunning()
        }
        
        // 移除所有的输入和输出
        if let session = captureSession {
            for input in session.inputs {
                session.removeInput(input)
            }
            for output in session.outputs {
                session.removeOutput(output)
            }
        }
        
        // 重置session
        captureSession = AVCaptureSession()
        
        // 重置状态
        isRunning = false
        photoOutput = nil
        videoDataOutput = nil
        currentDevice = nil
        currentDeviceInput = nil
    }
    
    // 修正图像方向，确保图像以正确方向保存
    func fixImageOrientation(_ image: UIImage) -> UIImage {
        print("【拍照流程】修正图像方向，原始方向: \(image.imageOrientation.rawValue)")
        
        // 如果图像方向已经是正确的，则直接返回
        if image.imageOrientation == .up {
            print("【拍照流程】图像方向已是正确的，不需要修正")
            return image
        }
        
        // 获取图像尺寸
        let width = image.size.width
        let height = image.size.height
        
        // 创建一个新的图像上下文，确保使用正确的比例因子
        UIGraphicsBeginImageContextWithOptions(CGSize(width: width, height: height), false, image.scale)
        
        // 在上下文中绘制图像，这会自动按照imageOrientation进行旋转
        let rect = CGRect(x: 0, y: 0, width: width, height: height)
        image.draw(in: rect)
        
        // 从上下文中获取新的图像
        guard let normalizedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("【拍照流程】警告：无法从图像上下文获取修正后的图像")
            return image
        }
        
        // 结束图像上下文
        UIGraphicsEndImageContext()
        
        print("【拍照流程】图像方向修正完成，新方向: \(normalizedImage.imageOrientation.rawValue), 尺寸: \(normalizedImage.size.width) x \(normalizedImage.size.height)")
        
        return normalizedImage
    }
    
    // 旋转图像
    func rotateImage(_ image: UIImage, clockwise: Bool) -> UIImage {
        let radians = clockwise ? CGFloat.pi / 2.0 : -CGFloat.pi / 2.0
        let rotationDirection = clockwise ? "顺时针" : "逆时针"
        print("【拍照流程】旋转图像: \(rotationDirection) 90度, 原始尺寸: \(image.size.width) x \(image.size.height)")
        
        // 计算新的尺寸（宽高互换）
        let sourceWidth = image.size.width
        let sourceHeight = image.size.height
        let newSize = CGSize(width: sourceHeight, height: sourceWidth)
        
        // 创建绘制上下文
        UIGraphicsBeginImageContextWithOptions(newSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // 平移和旋转
        context.translateBy(x: newSize.width / 2, y: newSize.height / 2)
        context.rotate(by: radians)
        
        // 绘制图像
        context.scaleBy(x: 1.0, y: -1.0)
        let rect = CGRect(x: -sourceWidth / 2, y: -sourceHeight / 2, width: sourceWidth, height: sourceHeight)
        
        if let cgImage = image.cgImage {
            context.draw(cgImage, in: rect)
        } else {
            print("【拍照流程】警告：无法获取图像的CGImage")
            return image
        }
        
        // 获取旋转后的图像
        guard let rotatedImage = UIGraphicsGetImageFromCurrentImageContext() else {
            print("【拍照流程】警告：无法获取旋转后的图像")
            return image
        }
        UIGraphicsEndImageContext()
        
        print("【拍照流程】旋转后图像尺寸: \(rotatedImage.size.width) x \(rotatedImage.size.height), 方向: \(rotatedImage.imageOrientation.rawValue)")
        
        // 验证图像宽高是否确实互换
        if rotatedImage.size.width != sourceHeight || rotatedImage.size.height != sourceWidth {
            print("【拍照流程】警告：旋转后的尺寸与预期不符")
        }
        
        return rotatedImage
    }
    
    // 将图像裁剪为16:9比例 (竖屏下的9:16)
    func cropImageTo16by9(_ image: UIImage) -> UIImage? {
        let sourceWidth = image.size.width
        let sourceHeight = image.size.height
        
        // 判断图像是否为横向
        let isLandscape = sourceWidth > sourceHeight
        
        // 无论横向还是竖向，都保持最长边不变，裁剪短边
        if isLandscape {
            // 横向图像：保持宽度不变，裁剪高度
            let targetHeight = sourceWidth * 9.0 / 16.0
            
            // 高度裁剪量计算
            let yOffset = (sourceHeight - targetHeight) / 2.0
            let finalYOffset = max(0, yOffset)
            
            let cropRect = CGRect(x: 0, y: finalYOffset, width: sourceWidth, height: targetHeight)
            return cropImage(image, toRect: cropRect)
        } else {
            // 竖向图像：保持高度不变，裁剪宽度
            let targetWidth = sourceHeight * 9.0 / 16.0
            
            // 宽度裁剪量计算
            let xOffset = (sourceWidth - targetWidth) / 2.0
            let finalXOffset = max(0, xOffset)
            
            let cropRect = CGRect(x: finalXOffset, y: 0, width: targetWidth, height: sourceHeight)
            return cropImage(image, toRect: cropRect)
        }
    }

    // 将图像裁剪为正方形 (1:1)
    func cropImageToSquare(_ image: UIImage) -> UIImage? {
        let sourceWidth = image.size.width
        let sourceHeight = image.size.height
        
        // 使用较短边作为正方形边长
        let squareSize = min(sourceWidth, sourceHeight)
        
        // 计算偏移量以居中裁剪
        let xOffset = (sourceWidth - squareSize) / 2.0
        let yOffset = (sourceHeight - squareSize) / 2.0
        
        let cropRect = CGRect(x: xOffset, y: yOffset, width: squareSize, height: squareSize)
        return cropImage(image, toRect: cropRect)
    }
    
    // 通用的图像裁剪方法
    func cropImage(_ image: UIImage, toRect cropRect: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let contextImage = UIImage(cgImage: cgImage)
        
        // 确保裁剪区域在图像范围内
        let imageRect = CGRect(x: 0, y: 0, width: contextImage.size.width, height: contextImage.size.height)
        let finalRect = cropRect.intersection(imageRect)
        
        // 计算裁剪区域（考虑UIImage的scale）
        let scaledRect = CGRect(
            x: finalRect.origin.x * image.scale,
            y: finalRect.origin.y * image.scale,
            width: finalRect.size.width * image.scale,
            height: finalRect.size.height * image.scale
        )
        
        // 裁剪图像
        if let croppedCGImage = cgImage.cropping(to: scaledRect) {
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
        }
        
        return nil
    }
    
    // 强制重绘旋转后的图像，确保像素数据真正被改变
    func forceRedrawRotatedImage(_ image: UIImage) -> UIImage {
        print("【拍照流程】强制重绘横向图像为竖向")
        
        // 强制旋转为竖向图像，宽高互换
        let sourceWidth = image.size.width
        let sourceHeight = image.size.height
        let targetSize = CGSize(width: sourceHeight, height: sourceWidth)
        
        // 创建旋转变换
        let rotationAngle = CGFloat.pi / 2  // 90度，顺时针旋转
        
        // 创建绘制上下文
        UIGraphicsBeginImageContextWithOptions(targetSize, false, image.scale)
        let context = UIGraphicsGetCurrentContext()!
        
        // 移动原点到中心
        context.translateBy(x: targetSize.width / 2, y: targetSize.height / 2)
        // 应用旋转
        context.rotate(by: rotationAngle)
        // 翻转坐标空间，因为Core Graphics和UIKit的坐标系不同
        context.scaleBy(x: 1.0, y: -1.0)
        
        // 绘制图像
        let drawRect = CGRect(x: -sourceWidth / 2, y: -sourceHeight / 2, width: sourceWidth, height: sourceHeight)
        context.draw(image.cgImage!, in: drawRect)
        
        // 获取新图像
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()!
        UIGraphicsEndImageContext()
        
        print("【拍照流程】强制重绘后图像尺寸: \(rotatedImage.size.width) x \(rotatedImage.size.height)")
        
        return rotatedImage
    }
    
    // MARK: - 教我拍功能

    // 当前最新的视频帧缓冲（用于教我拍功能）
    private var latestSampleBuffer: CMSampleBuffer?

    /// 捕获当前预览帧（从视频流中获取，不触发拍照）
    /// - Parameter completion: 完成回调，返回图像数据或错误
    func captureCurrentPreviewFrame(completion: @escaping (Data?, String?) -> Void) {
        // 确保在主线程执行
        DispatchQueue.main.async { [weak self] in
            guard let self = self else {
                completion(nil, "相机单例实例不可用")
                return
            }

            // 检查相机会话是否在运行
            guard isRunning else {
                completion(nil, "相机会话未运行")
                return
            }

            // 检查是否有可用的视频帧
            guard let sampleBuffer = self.latestSampleBuffer else {
                NSLog("TeachCaptureHandler: 没有可用的视频帧")
                completion(nil, "没有可用的视频帧")
                return
            }

            NSLog("TeachCaptureHandler: 从视频流中捕获当前帧")

            // 从 CMSampleBuffer 获取图像
            guard let image = self.imageFromSampleBuffer(sampleBuffer) else {
                NSLog("TeachCaptureHandler: 无法从视频帧创建图像")
                completion(nil, "无法从视频帧创建图像")
                return
            }

            // 压缩图像为 JPEG，压缩质量 0.7 以平衡质量和大小
            guard let jpegData = image.jpegData(compressionQuality: 0.7) else {
                NSLog("TeachCaptureHandler: 无法压缩图像")
                completion(nil, "无法压缩图像")
                return
            }

            NSLog("TeachCaptureHandler: 成功捕获预览帧，数据大小: \(jpegData.count) 字节")
            completion(jpegData, nil)
        }
    }

    /// 从 CMSampleBuffer 创建 UIImage
    private func imageFromSampleBuffer(_ sampleBuffer: CMSampleBuffer) -> UIImage? {
        // 获取 CVImageBuffer
        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return nil
        }

        // 锁定 base address
        CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
        defer {
            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
        }

        // 获取图像信息
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)

        // 创建颜色空间
        let colorSpace = CGColorSpaceCreateDeviceRGB()

        // 创建 bitmap context
        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(imageBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            return nil
        }

        // 创建 CGImage
        guard let cgImage = context.makeImage() else {
            return nil
        }

        // 创建 UIImage（需要正确的方向）
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: .right)

        return image
    }

    /// 根据设备方向旋转图像
    /// - Parameters:
    ///   - image: 原始图像
    ///   - orientation: 设备方向
    /// - Returns: 旋转后的图像
    private func orientImage(_ image: CIImage, forDeviceOrientation orientation: UIDeviceOrientation) -> CIImage {
        var rotationAngle: CGFloat = 0.0
        
        switch orientation {
        case .portrait:
            // 竖直方向，不需要旋转
            rotationAngle = 0
        case .portraitUpsideDown:
            // 倒置竖直方向，旋转180度
            rotationAngle = .pi
        case .landscapeLeft:
            // 横向左，旋转90度
            rotationAngle = .pi / 2
        case .landscapeRight:
            // 横向右，旋转270度
            rotationAngle = -.pi / 2
        default:
            // 其他情况默认不旋转
            rotationAngle = 0
        }
        
        // 如果角度为0，不需要旋转
        if rotationAngle == 0 {
            return image
        }
        
        // 计算旋转后的图像
        let transform = CGAffineTransform(rotationAngle: rotationAngle)
        
        // 根据是否需要调整大小来应用变换
        var rotatedImage = image.transformed(by: transform)
        
        // 如果是90度或270度旋转，需要调整图像位置，使其居中
        if orientation == .landscapeLeft || orientation == .landscapeRight {
            let originalSize = image.extent.size
            let rotatedSize = rotatedImage.extent.size
            
            // 计算偏移量，使旋转后的图像居中
            let xOffset = (rotatedSize.width - originalSize.height) / 2
            let yOffset = (rotatedSize.height - originalSize.width) / 2
            
            // 应用偏移变换
            rotatedImage = rotatedImage.transformed(by: CGAffineTransform(translationX: -xOffset, y: -yOffset))
        }
        
        return rotatedImage
    }
}

// MARK: - 照片捕获处理器
class PhotoCaptureProcessor: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Data?, Error?) -> Void
    private let aspectRatio: String
    private let deviceOrientation: UIDeviceOrientation
    
    // 添加一个静态数组存储当前活跃的处理器实例，防止被过早释放
    private static var activeProcessors = [PhotoCaptureProcessor]()
    
    init(aspectRatio: String, deviceOrientation: UIDeviceOrientation, completion: @escaping (Data?, Error?) -> Void) {
        self.completion = completion
        self.aspectRatio = aspectRatio
        self.deviceOrientation = deviceOrientation
        super.init()
        
        // 将自己加入到活跃处理器列表
        PhotoCaptureProcessor.activeProcessors.append(self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        print("【拍照流程】照片处理中...")
        
        if let error = error {
            print("【拍照流程】处理照片时出错: \(error.localizedDescription)")
            completion(nil, error)
        } else {
            // 获取照片数据
            if let imageData = photo.fileDataRepresentation() {
                // 处理图像方向
                let processedData = processImageData(imageData, deviceOrientation: deviceOrientation)
                
                // 检查是否需要裁剪 (非4:3比例)
                if aspectRatio != "4:3" {
                    print("【拍照流程】裁剪照片为 \(aspectRatio) 比例")
                    
                    // 创建UIImage以进行裁剪
                    if let image = UIImage(data: processedData) {
                        // 根据不同比例计算裁剪区域
                        let croppedImage: UIImage?
                        switch aspectRatio {
                        case "16:9":
                            croppedImage = CameraSingleton.shared.cropImageTo16by9(image)
                        case "1:1":
                            croppedImage = CameraSingleton.shared.cropImageToSquare(image)
                        default:
                            croppedImage = image
                        }
                        
                        // 转换裁剪后的图像为JPEG数据，保留EXIF
                        if let croppedImage = croppedImage, 
                           let croppedData = addOrientationToImageData(croppedImage.jpegData(compressionQuality: 0.9), deviceOrientation: deviceOrientation) {
                            completion(croppedData, nil)
                        } else {
                            print("【拍照流程】裁剪照片后转换失败，使用原始图像")
                            completion(processedData, nil)
                        }
                    } else {
                        print("【拍照流程】无法从数据创建图像，使用原始数据")
                        completion(processedData, nil)
                    }
                } else {
                    // 不需要裁剪，直接返回处理后的图像数据
                    completion(processedData, nil)
                }
            } else {
                print("【拍照流程】无法获取照片数据")
                let error = NSError(domain: "com.haohaopai.app", code: 1006, userInfo: [NSLocalizedDescriptionKey: "无法获取照片数据"])
                completion(nil, error)
            }
        }
        
        // 处理完成后从活跃处理器列表中移除自己
        if let index = PhotoCaptureProcessor.activeProcessors.firstIndex(where: { $0 === self }) {
            PhotoCaptureProcessor.activeProcessors.remove(at: index)
        }
    }
    
    // 处理图像数据，根据设备方向设置正确的EXIF方向标签
    private func processImageData(_ imageData: Data, deviceOrientation: UIDeviceOrientation) -> Data {
        // 创建图像源
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return imageData
        }
        
        // 获取原始图像属性
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        // 创建一个可变的图像属性字典
        var newProperties = imageProperties
        
        // 确定正确的EXIF方向值
        var orientationValue: CGImagePropertyOrientation
        
        // 检查是否为前置相机
        let isFrontCamera = CameraSingleton.shared.isFrontCamera()
        
        if isFrontCamera {
            // 前置相机拍摄的照片需要水平翻转
        switch deviceOrientation {
        case .landscapeLeft:
                // 对于前置相机，需要与后置相机相反
                orientationValue = .downMirrored  // 值为4，旋转180度并水平翻转
        case .landscapeRight:
                // 对于前置相机，需要与后置相机相反
                orientationValue = .upMirrored  // 值为2，水平翻转
        case .portrait:
                orientationValue = .leftMirrored  // 值为5，顺时针旋转90度并水平翻转
        case .portraitUpsideDown:
                orientationValue = .rightMirrored  // 值为7，逆时针旋转90度并水平翻转
        case .faceUp, .faceDown:
                orientationValue = .leftMirrored  // 值为5
        default:
                orientationValue = .leftMirrored  // 值为5
            }
        } else {
            // 后置相机
            switch deviceOrientation {
            case .landscapeLeft:
                orientationValue = .up  // 值为1
            case .landscapeRight:
                orientationValue = .down  // 值为3
            case .portrait:
                orientationValue = .right  // 值为6
            case .portraitUpsideDown:
                orientationValue = .left  // 值为8
            case .faceUp, .faceDown:
                orientationValue = .right  // 值为6
            default:
                orientationValue = .right  // 值为6
            }
        }
        
        // 设置方向属性
        newProperties[kCGImagePropertyOrientation as String] = orientationValue.rawValue
        
        // 创建一个可变数据对象来存储新的图像数据
        let mutableData = NSMutableData()
        
        // 创建图像目标
        guard let destination = CGImageDestinationCreateWithData(mutableData, CGImageSourceGetType(source)!, 1, nil) else {
            return imageData
        }
        
        // 添加图像到目标，并应用新属性
        CGImageDestinationAddImageFromSource(destination, source, 0, newProperties as CFDictionary)
        
        // 完成图像目标的写入
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        } else {
            return imageData
        }
    }
    
    // 为图像数据添加方向信息
    private func addOrientationToImageData(_ imageData: Data?, deviceOrientation: UIDeviceOrientation) -> Data? {
        guard let imageData = imageData else {
            return nil
        }
        
        // 创建图像源
        guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            return imageData
        }
        
        // 确定正确的EXIF方向值
        var orientationValue: CGImagePropertyOrientation
        
        // 检查是否为前置相机
        let isFrontCamera = CameraSingleton.shared.isFrontCamera()
        
        if isFrontCamera {
            // 前置相机拍摄的照片需要水平翻转
        switch deviceOrientation {
        case .landscapeLeft:
                // 对于前置相机，需要与后置相机相反
                orientationValue = .downMirrored  // 值为4，旋转180度并水平翻转
        case .landscapeRight:
                // 对于前置相机，需要与后置相机相反
                orientationValue = .upMirrored  // 值为2，水平翻转
        case .portrait:
                orientationValue = .leftMirrored  // 值为5，顺时针旋转90度并水平翻转
        case .portraitUpsideDown:
                orientationValue = .rightMirrored  // 值为7，逆时针旋转90度并水平翻转
        case .faceUp, .faceDown:
                orientationValue = .leftMirrored  // 值为5
        default:
                orientationValue = .leftMirrored  // 值为5
            }
        } else {
            // 后置相机
            switch deviceOrientation {
            case .landscapeLeft:
                orientationValue = .up  // 值为1
            case .landscapeRight:
                orientationValue = .down  // 值为3
            case .portrait:
                orientationValue = .right  // 值为6
            case .portraitUpsideDown:
                orientationValue = .left  // 值为8
            case .faceUp, .faceDown:
                orientationValue = .right  // 值为6
            default:
                orientationValue = .right  // 值为6
            }
        }
        
        // 创建一个可变数据对象来存储新的图像数据
        let mutableData = NSMutableData()
        
        // 创建图像目标
        guard let destination = CGImageDestinationCreateWithData(mutableData, CGImageSourceGetType(source)!, 1, nil) else {
            return imageData
        }
        
        // 获取原始图像属性
        let imageProperties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] ?? [:]
        
        // 创建一个可变的图像属性字典
        var newProperties = imageProperties
        
        // 设置方向属性
        newProperties[kCGImagePropertyOrientation as String] = orientationValue.rawValue
        
        // 添加图像到目标，并应用新属性
        CGImageDestinationAddImageFromSource(destination, source, 0, newProperties as CFDictionary)
        
        // 完成图像目标的写入
        if CGImageDestinationFinalize(destination) {
            return mutableData as Data
        } else {
            return imageData
        }
    }
    
    // 添加一个方法用于在应用程序状态变化时清理
    class func cleanupActiveProcessors() {
        let count = activeProcessors.count
        activeProcessors.removeAll()
    }
} 