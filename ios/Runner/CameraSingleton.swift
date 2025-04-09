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
    
    // 当前激活的设备
    private var currentDevice: AVCaptureDevice?
    private var currentDeviceInput: AVCaptureDeviceInput?
    
    // 当前缩放状态
    private var currentZoomFactor: CGFloat = 1.0
    
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
                return
            }
            
            // 在后台线程设置相机
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try self.setupCaptureSession()
                    self.isInitialized = true
                    
                    // 在主线程返回结果
                    DispatchQueue.main.async {
                        result(true)
                    }
                } catch {
                    // 在主线程返回错误
                    DispatchQueue.main.async {
                        result(FlutterError(code: "SETUP_ERROR", 
                                           message: "设置相机失败: \(error.localizedDescription)", 
                                           details: nil))
                    }
                }
            }
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
        eventSink = newEventSink
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
            completion(false, "相机未初始化")
            return
        }
        
        let newPosition: AVCaptureDevice.Position = toFront ? .front : .back
        
        // 如果已经是请求的摄像头位置，直接返回成功
        if currentPosition == newPosition {
            completion(true, nil)
            return
        }
        
        // 在后台线程执行摄像头切换
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // 配置新摄像头
                try self.configureCamera(position: newPosition)
                
                // 在主线程返回结果
                DispatchQueue.main.async {
                    completion(true, nil)
                }
            } catch {
                // 在主线程返回错误
                DispatchQueue.main.async {
                    completion(false, "切换摄像头失败: \(error.localizedDescription)")
                }
            }
        }
    }
    
    /// 设置缩放级别
    func setZoomLevel(_ zoomLevel: CGFloat, completion: @escaping (Bool, String?) -> Void) {
        guard let device = currentDevice else {
            completion(false, "没有活动的相机设备")
            return
        }
        
        // 确保缩放级别在设备支持的范围内
        let clampedZoomLevel = max(1.0, min(zoomLevel, device.activeFormat.videoMaxZoomFactor))
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedZoomLevel
            device.unlockForConfiguration()
            
            currentZoomFactor = clampedZoomLevel
            completion(true, nil)
            
            // 发送缩放更改事件
            sendEvent(type: "zoomChanged", data: ["zoomFactor": clampedZoomLevel])
        } catch {
            completion(false, "设置缩放级别失败: \(error.localizedDescription)")
        }
    }
    
    /// 设置对焦点
    func setFocusPoint(_ point: CGPoint, completion: @escaping (Bool, String?) -> Void) {
        guard let device = currentDevice else {
            completion(false, "没有活动的相机设备")
            return
        }
        
        // 确保设备支持对焦点设置
        guard device.isFocusPointOfInterestSupported else {
            completion(false, "设备不支持对焦点设置")
            return
        }
        
        do {
            try device.lockForConfiguration()
            
            // 设置对焦点
            device.focusPointOfInterest = point
            device.focusMode = .autoFocus
            
            // 设置曝光点
            if device.isExposurePointOfInterestSupported {
                device.exposurePointOfInterest = point
                device.exposureMode = .autoExpose
            }
            
            device.unlockForConfiguration()
            
            // 发送对焦更改事件
            sendEvent(type: "focusChanged", data: [
                "x": point.x,
                "y": point.y,
                "success": true
            ])
            
            completion(true, nil)
        } catch {
            completion(false, "设置对焦点失败: \(error.localizedDescription)")
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
        if session.canSetSessionPreset(.high) {
            session.sessionPreset = .high
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
        } else {
            throw NSError(domain: "com.haohaopai.app", code: 1003, userInfo: [NSLocalizedDescriptionKey: "无法添加相机输入到会话"])
        }
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