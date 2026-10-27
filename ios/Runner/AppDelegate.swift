import Flutter
import UIKit
import Darwin

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
      case "getBroadcastAddresses":
        result(self.broadcastAddresses())
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

  private func broadcastAddresses() -> [String] {
    var interfaces: UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&interfaces) == 0, let first = interfaces else {
      return []
    }
    defer { freeifaddrs(first) }

    var addresses = Set<String>()
    var current: UnsafeMutablePointer<ifaddrs>? = first
    while let interface = current {
      current = interface.pointee.ifa_next
      let entry = interface.pointee
      let flags = entry.ifa_flags
      guard (flags & UInt32(IFF_UP)) != 0,
            (flags & UInt32(IFF_LOOPBACK)) == 0,
            let address = entry.ifa_addr,
            let netmask = entry.ifa_netmask,
            address.pointee.sa_family == sa_family_t(AF_INET) else {
        continue
      }

      let ipv4Address = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_addr
      }
      let ipv4Netmask = netmask.withMemoryRebound(to: sockaddr_in.self, capacity: 1) {
        $0.pointee.sin_addr
      }
      var broadcast = in_addr(s_addr: ipv4Address.s_addr | ~ipv4Netmask.s_addr)
      var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
      guard inet_ntop(AF_INET, &broadcast, &buffer, socklen_t(buffer.count)) != nil else {
        continue
      }
      addresses.insert(String(cString: buffer))
    }

    return addresses.sorted()
  }
}
