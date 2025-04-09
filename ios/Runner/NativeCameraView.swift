import Flutter
import UIKit

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
        // 获取预览层并添加到视图
        if let previewLayer = CameraSingleton.shared.getPreviewLayer() {
            previewLayer.frame = _view.bounds
            _view.layer.addSublayer(previewLayer)
            
            // 添加观察者监听视图大小变化，以更新预览层大小
            _view.layer.addObserver(self, forKeyPath: "bounds", options: .new, context: nil)
        }
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "bounds" {
            // 当视图大小变化时，更新预览层大小
            if let previewLayer = CameraSingleton.shared.getPreviewLayer() {
                previewLayer.frame = _view.bounds
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
        
        // 立即发送初始化事件确认连接成功
        let initialEvent: [String: Any] = [
            "type": "initialized",
            "message": "相机事件通道已连接"
        ]
        events(initialEvent)
        
        return nil
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        
        // 清除相机单例的事件接收器
        CameraSingleton.shared.setEventSink(nil)
        
        return nil
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
            
        case "setFocusPoint":
            if let args = call.arguments as? [String: Any], 
               let x = args["x"] as? Double, 
               let y = args["y"] as? Double {
                
                let point = CGPoint(x: CGFloat(x), y: CGFloat(y))
                CameraSingleton.shared.setFocusPoint(point) { success, error in
                    if success {
                        result(true)
                    } else {
                        result(FlutterError(code: "FOCUS_FAILED", message: error ?? "设置对焦点失败", details: nil))
                    }
                }
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "无效的参数", details: nil))
            }
            
        case "isFrontCamera":
            // 这个方法需要在CameraSingleton中添加，返回当前是否为前置相机
            result(CameraSingleton.shared.isFrontCamera())
            
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    deinit {
        // 移除观察者
        _view.layer.removeObserver(self, forKeyPath: "bounds")
        
        // 清理方法通道和事件通道
        methodChannel.setMethodCallHandler(nil)
        eventChannel.setStreamHandler(nil)
    }
} 