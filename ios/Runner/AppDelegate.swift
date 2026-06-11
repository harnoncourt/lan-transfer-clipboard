import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private lazy var lanTransferEngine = FlutterEngine(name: "lan_transfer_engine")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    lanTransferEngine.run()
    GeneratedPluginRegistrant.register(with: lanTransferEngine)

    let platformChannel = FlutterMethodChannel(
      name: "app.local.lan_transfer_clipboard/platform",
      binaryMessenger: lanTransferEngine.binaryMessenger
    )
    platformChannel.setMethodCallHandler { call, result in
      switch call.method {
      case "getDeviceName":
        result(UIDevice.current.name)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    window = UIWindow(frame: UIScreen.main.bounds)
    window?.rootViewController = FlutterViewController(
      engine: lanTransferEngine,
      nibName: nil,
      bundle: nil
    )
    window?.makeKeyAndVisible()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
