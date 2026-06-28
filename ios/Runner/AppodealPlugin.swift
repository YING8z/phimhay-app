import Flutter
import UIKit

class AppodealPlugin: NSObject {
    static func register(controller: FlutterViewController) {
        let channel = FlutterMethodChannel(
            name: "com.xiaofilm/appodeal",
            binaryMessenger: controller.binaryMessenger
        )
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "initialize":
                result(true)
            case "loadInterstitial", "loadRewarded", "loadBanner":
                result(nil)
            case "showInterstitial", "showRewarded", "showBanner":
                result(false)
            case "hideBanner":
                result(true)
            case "getDebugInfo":
                result([String: Any]())
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }
}
