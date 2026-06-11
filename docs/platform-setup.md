# 平台配置

本文档说明 macOS、Windows、Android、iOS 的平台工程配置。执行以下命令后会生成平台目录：

```bash
flutter create --platforms=macos,windows,android,ios .
flutter pub get
```

## 当前本机环境

截至 2026-06-11，当前机器状态：

- Flutter 3.44.1：已安装。
- Dart 3.12.1：已安装。
- Android SDK：`/Users/huangxin/Library/Android/sdk`，已配置。
- Android licenses：已接受。
- CocoaPods 1.16.2：已安装。
- Xcode 26.5：已安装，`xcode-select` 已指向 `/Applications/Xcode.app/Contents/Developer`。
- iOS Simulator runtime（iOS 26.5）：已安装，iPhone/iPad 模拟器可用。
- iOS 真机构建：已验证，可通过 `flutter build ios --release` + `flutter install` 安装到 iPad。

## macOS

### Xcode

macOS/iOS 构建需要完整 Xcode。当前机器已经安装 Xcode 26.5。如需重新选择 Xcode，执行：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

然后重新检查：

```bash
flutter doctor -v
```

如果 `flutter doctor` 提示 `Unable to get list of installed Simulator runtimes`，说明 Xcode 没有安装任何模拟器 runtime。可以在 Xcode 的 Settings 中下载 iOS Simulator，或执行：

```bash
xcodebuild -downloadPlatform iOS
```

### Sandbox Entitlements

如果发布 sandboxed macOS 应用，需要开启网络客户端和服务端权限。

在 `macos/Runner/DebugProfile.entitlements` 和发布用 entitlements 中加入：

```xml
<key>com.apple.security.network.client</key>
<true/>
<key>com.apple.security.network.server</key>
<true/>
```

### 本地网络弹窗

首次监听端口或接收连接时，系统可能弹出网络权限或防火墙确认。选择允许局域网访问。

## iOS

### Local Network 权限

`ios/Runner/Info.plist` 已配置：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>需要局域网访问权限以发现并连接同一网络中的其他设备。</string>
<key>NSBonjourServices</key>
<array>
  <string>_lan-transfer._udp</string>
</array>
```

当前 MVP 使用 UDP 广播，不依赖 Bonjour。声明 Bonjour service 是为了后续迁移 mDNS/Bonjour，也让 iOS Local Network 权限说明更清晰。

真机首次启动会弹出本地网络权限请求，必须允许，否则设备发现一直显示 `0 在线`。误拒后可在 设置 → 隐私与安全性 → 本地网络 中重新开启。

### 应用生命周期

当前 `AppDelegate.swift` 采用手动创建 `FlutterEngine` 和窗口的传统（非 UIScene）生命周期，`Info.plist` 中没有 `UIApplicationSceneManifest`。`SceneDelegate.swift` 仍在工程中但未被使用。注意：Apple 已宣布未来 iOS SDK 将强制 scene-based 生命周期，后续升级 Flutter/Xcode 大版本时此处可能需要迁回 UIScene 模板。

### 发现广播差异

iOS 上发送 limited broadcast（`255.255.255.255`）会被系统拒绝，因此 iOS 端只向本机网段的 directed broadcast 地址（如 `192.168.1.255`）发送心跳。其他平台两者都发。

### 设备名

iOS 设备名通过原生 `UIDevice.current.name` 方法通道获取。iOS/iPadOS 16+ 出于隐私限制只返回通用名称（`iPad`、`iPhone`），获取用户自定义设备名需要申请 Apple 的 `user-assigned-device-name` entitlement。通道不可用时回退为 `iOS device`。

### 真机安装

工程已配置开发团队签名（`DEVELOPMENT_TEAM`）。连接 iPad/iPhone 后执行：

```bash
flutter build ios --release
flutter install -d <device-id>
```

注意：

- 首次安装后如提示“不受信任的开发者”，在 设置 → 通用 → VPN 与设备管理 中信任证书。
- 个人开发证书签名的应用 7 天过期，需重新安装；付费开发者账号为 1 年。
- 开源发布前建议把个人 `DEVELOPMENT_TEAM` 从 pbxproj 中移除，改用本地 xcconfig 覆盖。

### 后台限制

iOS 对后台常驻网络服务限制较严格。当前 MVP 设计为前台运行优先。应用进入后台会暂停离线清理，回到前台后重新绑定 discovery socket 并连发心跳。后续如果需要后台接收，应结合：

- Background Modes。
- 本地通知。
- 有限时间后台任务。
- 用户显式打开应用接收。

## Android

确保 `android/app/src/main/AndroidManifest.xml` 包含：

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_MULTICAST_STATE" />
```

当前 Android 原生入口会在应用运行期间申请 `WifiManager.MulticastLock`，用于提升局域网 UDP 广播接收可靠性。若设备仍显示 `0 在线`，优先检查同一 Wi-Fi、VPN、热点隔离和路由器 AP isolation。

Android 顶部设备名通过原生 `Build.MANUFACTURER` / `Build.MODEL` 生成，避免显示 `localhost`。本机地址优先使用 Wi-Fi DHCP IPv4，并过滤 `0.0.0.0`、`127.0.0.1` 和链路本地地址。

Android 接收文件通过原生 MediaStore 写入系统下载目录：

```text
Download/LAN Transfer
```

Android 10+ 不需要额外存储权限即可写入自己的下载条目。用户可以在系统“下载”或文件管理器中找到收到的文件。

如果后续实现后台接收、通知或前台服务，再按需加入：

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

Android 13+ 的通知权限需要运行时授权。

## Windows

Windows 首次监听端口时可能触发 Windows Defender Firewall 弹窗。请选择允许专用网络访问，否则右上角在线设备数可能一直为 0，文件接收也可能失败。

发布时建议：

- 签名安装包。
- 给应用明确的发布者名称。
- 在帮助文档中说明只需要局域网访问。

Windows 详细构建与打包说明见 [windows.md](windows.md)。

## Web

Flutter Web 可以作为界面验证目标，但当前核心网络代码使用 `dart:io`，不支持 Web 端运行。Web 不是当前目标平台。

## 验证命令

```bash
flutter doctor -v
flutter devices
flutter test
```

Android 构建：

```bash
flutter build apk
```

macOS 构建：

```bash
flutter build macos
```

iOS 构建：

```bash
flutter build ios
```
