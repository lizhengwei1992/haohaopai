import Flutter
import UIKit
import AVFoundation

class NativeCameraView: NSObject, FlutterPlatformView, FlutterStreamHandler {
    private var _view: UIView
    private var methodChannel: FlutterMethodChannel
    private var eventChannel: FlutterEventChannel
    private var eventSink: FlutterEventSink?
    private var viewId: Int64
    
    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments: Any?,
        binaryMessenger messenger: FlutterBinaryMessenger?
    ) {
        self.viewId = viewId
        _view = UIView(frame: frame)
        
        // 设置视图属性
        _view.backgroundColor = UIColor.black
        _view.contentMode = .scaleAspectFill
        _view.clipsToBounds = true
        
        // 创建方法通道
        methodChannel = FlutterMethodChannel(
            name: "com.haohaopai.app/native_camera_view_\(viewId)",
            binaryMessenger: messenger!)
        
        // 使用增强的事件通道创建
        let channelName = "com.haohaopai.app/native_camera_events_\(viewId)"
        eventChannel = FlutterEventChannel(
            name: channelName,
            binaryMessenger: messenger!)
        
        super.init()
        
        // 设置方法通道处理器
        methodChannel.setMethodCallHandler { [weak self] (call, result) in
            self?.handleMethodCall(call, result: result)
        }
        
        // 使用标准方式设置事件通道处理器
        print("设置事件处理器: \(channelName)")
        eventChannel.setStreamHandler(self)
        
        // 添加预览层
        setupPreviewLayer()
    }
    
    func view() -> UIView {
        return _view
    }
    
    private func setupPreviewLayer() {
        refreshPreviewLayer()
        
        // 添加观察者监听视图大小变化，以更新预览层大小
        self._view.layer.addObserver(self, forKeyPath: "bounds", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds" {
            // 当视图大小变化时，更新预览层大小
            if let previewLayer = CameraSingleton.shared.getPreviewLayer() {
                previewLayer.frame = self._view.bounds
            }
        }
    }
    
    // MARK: - FlutterStreamHandler
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        
        // 将事件接收器传递给相机单例
        CameraSingleton.shared.setEventSink(events)
        
        // 确保连接信息在控制台可见
        print("NativeCameraView: 事件通道连接成功, viewId=\(viewId)")
        print("NativeCameraView: 事件通道名称=com.haohaopai.app/native_camera_events_\(viewId)")
        
        // 注册 previewLayerUpdated 事件处理
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePreviewLayerUpdate),
            name: NSNotification.Name("com.haohaopai.app.PreviewLayerUpdated"),
            object: nil
        )
        
        // 使用延迟确保Flutter端有足够时间处理事件流设置
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // 立即发送初始化事件确认连接成功
            let initialEvent: [String: Any] = [
                "type": "initialized",
                "message": "相机事件通道已连接"
            ]
            events(initialEvent)
        }
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        
        // 清除相机单例的事件接收器
        CameraSingleton.shared.setEventSink(nil)
        
        // 移除事件观察者
        NotificationCenter.default.removeObserver(self)
        
        return nil
    }
    
    // MARK: - Event Handlers
    
    @objc private func handlePreviewLayerUpdate() {
        print("[NativeCameraView] 收到预览层更新通知")
        
        // 移除旧的预览层
        for layer in self._view.layer.sublayers ?? [] {
            if layer is AVCaptureVideoPreviewLayer {
                layer.removeFromSuperlayer()
            }
        }
        
        // 添加新的预览层
        print("[NativeCameraView] 准备调用 refreshPreviewLayer")
        refreshPreviewLayer()
        
        // 强制视图布局刷新
        self._view.setNeedsLayout()
        self._view.layoutIfNeeded()
        
        // 延迟后检查预览层是否正常显示
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            
            if let previewLayer = CameraSingleton.shared.getPreviewLayer() {
                print("预览层刷新检查: \(previewLayer.frame), 视图bounds: \(self._view.bounds)")
                
                // 如果预览层没有正确大小，尝试再次调整
                if previewLayer.frame.size.width == 0 || previewLayer.frame.size.height == 0 {
                    previewLayer.frame = self._view.bounds
                    self._view.setNeedsLayout()
                    self._view.layoutIfNeeded()
                    print("预览层大小已调整")
                }
            }
        }
    }
    
    private func refreshPreviewLayer() {
        print("[NativeCameraView] refreshPreviewLayer 开始")
        // 获取新的预览层并添加到视图
        if let previewLayer = CameraSingleton.shared.getPreviewLayer() {
            print("[NativeCameraView] refreshPreviewLayer - 获取到新预览层, Session: \(previewLayer.session?.description ?? "nil")")
            // 设置预览层框架为视图大小
            previewLayer.frame = self._view.bounds
            previewLayer.videoGravity = .resizeAspectFill
            
            // 重要：将预览层添加到最底层
            self._view.layer.insertSublayer(previewLayer, at: 0)
            print("[NativeCameraView] refreshPreviewLayer - 已调用 insertSublayer, 当前 sublayers 数: \(self._view.layer.sublayers?.count ?? 0)")
            
            // 检查是否真的添加成功
            if let sublayers = self._view.layer.sublayers, sublayers.contains(previewLayer) {
                print("[NativeCameraView] refreshPreviewLayer - 确认预览层已添加到 sublayers 中")
            } else {
                print("[NativeCameraView] refreshPreviewLayer - 警告：预览层未能添加到 sublayers 中！")
            }
            
            // 确保预览层的连接正确设置
            if let connection = previewLayer.connection {
                if connection.isVideoOrientationSupported {
                    connection.videoOrientation = .portrait
                }
            }
            
            print("[NativeCameraView] 预览层已刷新，frame: \(previewLayer.frame), 视图大小: \(self._view.bounds)")
            
            // 对于某些设备，可能需要禁用隐式动画以避免闪烁
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            previewLayer.frame = self._view.bounds
            CATransaction.commit()
        } else {
            print("[NativeCameraView] refreshPreviewLayer - 无法获取预览层")
        }
    }
    
    // MARK: - Method Handler
    
    private func handleMethodCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            CameraSingleton.shared.initializeCamera(result: result)
            
        case "startPreview":
            CameraSingleton.shared.startPreview { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "START_FAILED", message: error ?? "无法启动预览", details: nil))
                }
            }
            
        case "stopPreview":
            CameraSingleton.shared.stopPreview { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "STOP_FAILED", message: error ?? "无法停止预览", details: nil))
                }
            }
            
        case "pausePreview":
            CameraSingleton.shared.pausePreview { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "PAUSE_FAILED", message: error ?? "无法暂停预览", details: nil))
                }
            }
            
        case "resumePreview":
            CameraSingleton.shared.resumePreview { success, error in
                if success {
                    result(true)
                } else {
                    result(FlutterError(code: "RESUME_FAILED", message: error ?? "无法恢复预览", details: nil))
                }
            }
            
        case "capturePhoto":
            CameraSingleton.shared.capturePhoto { imageData, error in
                if let imageData = imageData {
                    result(FlutterStandardTypedData(bytes: imageData))
                } else {
                    result(FlutterError(code: "CAPTURE_FAILED", message: error ?? "拍照失败", details: nil))
                }
            }
            
        case "switchCamera":
            if let args = call.arguments as? [String: Any], let toFront = args["toFront"] as? Bool {
                CameraSingleton.shared.switchCamera(toFront: toFront) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "SWITCH_FAILED", message: error ?? "切换相机失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "setZoomLevel":
            if let args = call.arguments as? [String: Any], let zoomLevel = args["zoomLevel"] as? Double {
                CameraSingleton.shared.setZoomLevel(CGFloat(zoomLevel)) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "ZOOM_FAILED", message: error ?? "设置缩放失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "setSystemLikeZoom":
            if let args = call.arguments as? [String: Any], let zoomLevel = args["zoomLevel"] as? Double {
                CameraSingleton.shared.setSystemLikeZoom(CGFloat(zoomLevel)) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "ZOOM_FAILED", message: error ?? "系统级缩放设置失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "setFlashMode":
            if let args = call.arguments as? [String: Any], let mode = args["mode"] as? String {
                CameraSingleton.shared.setFlashMode(mode) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "FLASH_FAILED", message: error ?? "设置闪光灯模式失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "setExposureLevel":
            if let args = call.arguments as? [String: Any], 
               let exposureLevel = args["exposureLevel"] as? Double {
                
                CameraSingleton.shared.setExposureLevel(exposureLevel) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "EXPOSURE_FAILED", message: error ?? "设置曝光级别失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "isFrontCamera":
            // 这个方法需要在CameraSingleton中添加，返回当前是否为前置相机
            result(CameraSingleton.shared.isFrontCamera())
            
        case "getDiagnosticInfo":
            // 返回相机状态诊断信息
            result(CameraSingleton.shared.diagnoseCameraState())
            
        case "sendDiagnosticInfo":
            // 通过事件通道发送诊断信息
            CameraSingleton.shared.sendDiagnosticInfo()
            result(true)
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    deinit {
        // 移除观察者
        self._view.layer.removeObserver(self, forKeyPath: "bounds")
        
        // 清理方法通道和事件通道
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
} 