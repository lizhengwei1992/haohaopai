import Foundation
import Flutter
import AVFoundation
import UIKit

/// 教我拍功能处理器
/// 负责从相机捕获当前预览帧并返回给Flutter端
class TeachCaptureHandler: NSObject {
    
    // 单例实例
    static let shared = TeachCaptureHandler()
    
    // 方法通道
    private var methodChannel: FlutterMethodChannel?
    
    // 私有构造函数确保单例模式
    private override init() {
        super.init()
    }
    
    // 注册方法通道
    func registerMethodChannel(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(
            name: "com.haohaopai.app/teach_capture",
            binaryMessenger: messenger
        )
        
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            guard let self = self else { 
                result(FlutterError(code: "UNAVAILABLE", 
                                   message: "TeachCaptureHandler实例不可用", 
                                   details: nil))
                return
            }
            
            switch call.method {
            case "captureCurrentFrame":
                self.captureCurrentFrame(result: result)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        NSLog("TeachCaptureHandler: 方法通道注册成功")
    }
    
    // 捕获当前预览帧
    private func captureCurrentFrame(result: @escaping FlutterResult) {
        NSLog("TeachCaptureHandler: 开始捕获当前预览帧")
        
        // 获取相机单例
        let cameraSingleton = CameraSingleton.shared
        
        // 检查相机是否已初始化
        guard cameraSingleton.isCameraInitialized else {
            NSLog("TeachCaptureHandler: 相机未初始化")
            result(FlutterError(code: "CAMERA_NOT_INITIALIZED", 
                               message: "相机未初始化", 
                               details: nil))
            return
        }
        
        // 检查相机是否准备就绪
        cameraSingleton.isCameraReady { isReady in
            if !isReady {
                NSLog("TeachCaptureHandler: 相机未准备就绪")
                result(FlutterError(code: "CAMERA_NOT_READY", 
                                   message: "相机未准备就绪", 
                                   details: nil))
                return
            }
            
            // 从相机获取当前预览帧
            NSLog("TeachCaptureHandler: 调用captureCurrentPreviewFrame")
            cameraSingleton.captureCurrentPreviewFrame { (imageData, error) in
                if let error = error {
                    NSLog("TeachCaptureHandler: 捕获预览帧失败: \(error)")
                    result(FlutterError(code: "CAPTURE_FAILED", 
                                       message: "捕获预览帧失败: \(error)", 
                                       details: nil))
                    return
                }
                
                guard let imageData = imageData else {
                    NSLog("TeachCaptureHandler: 未获取到预览帧数据")
                    result(FlutterError(code: "NO_IMAGE_DATA", 
                                       message: "未获取到预览帧数据", 
                                       details: nil))
                    return
                }
                
                NSLog("TeachCaptureHandler: 成功捕获预览帧，数据大小: \(imageData.count) 字节")
                result(imageData)
            }
        }
    }
} 