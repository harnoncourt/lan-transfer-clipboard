# 平台配置

本文档说明 macOS、Windows、Android、iOS 的平台工程配置。执行以下命令后会生成平台目录：

```bash
flutter create --platforms=macos,windows,android,ios .
flutter pub get
```

## 当前本机环境

截至 2026-06-07，当前机器状态：

- Flutter 3.44.1：已安装。
- Dart 3.12.1：已安装。
- Android SDK：`/Users/huangxin/Library/Android/sdk`，已配置。
- Android licenses：已接受。
- CocoaPods 1.16.2：已安装。
- Xcode 26.5：已安装，`xcode-select` 已指向 `/Applications/Xcode.app/Contents/Developer`。
- iOS Simulator runtime：尚未安装，当前命令行下载遇到 Apple MobileAsset 网络错误。

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

在 `ios/Runner/Info.plist` 中加入：

```xml
<key>NSLocalNetworkUsageDescription</key>
<string>Discover and transfer files to nearby devices on your local network.</string>
<key>NSBonjourServices</key>
<array>
  <string>_lan-transfer._tcp</string>
</array>
```

当前 MVP 使用 UDP 广播，不依赖 Bonjour。声明 Bonjour service 是为了后续迁移 mDNS/Bonjour，也让 iOS Local Network 权限说明更清晰。

### 后台限制

iOS 对后台常驻网络服务限制较严格。当前 MVP 设计为前台运行优先。后续如果需要后台接收，应结合：

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
```

如果后续实现后台接收、通知或前台服务，再按需加入：

```xml
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
```

Android 13+ 的通知权限需要运行时授权。

## Windows

Windows 首次监听端口时可能触发 Windows Defender Firewall 弹窗。请选择允许专用网络访问。

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
