import Flutter
import UIKit

public class WakelockPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "com.example.wakelock",
            binaryMessenger: registrar.messenger()
        )
        let instance = WakelockPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "enable":
            UIApplication.shared.isIdleTimerDisabled = true
            result(true)
        case "disable":
            UIApplication.shared.isIdleTimerDisabled = false
            result(true)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
