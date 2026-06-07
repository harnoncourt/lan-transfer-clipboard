# 故障排查

## 设备发现不到

可能原因：

- 两台设备不在同一局域网。
- Wi-Fi 开启了 AP isolation。
- 防火墙阻止 UDP 或入站连接。
- iOS 未授予 Local Network 权限。
- 路由器不转发 UDP broadcast。

排查方式：

1. 确认两台设备连接同一个 Wi-Fi。
2. 关闭 VPN 后重试。
3. 检查系统防火墙。
4. 重启应用。
5. 在路由器中关闭客户端隔离。

## 能发现设备但发送失败

可能原因：

- 远端 HTTP 端口被防火墙阻止。
- 对方应用已退出，但 peer 还没过期。
- 移动端进入后台导致服务不可用。
- 网络发生切换。

排查方式：

1. 等待 15 秒让离线设备自动移除。
2. 确认对方应用在前台运行。
3. 允许防火墙专用网络访问。
4. 重新连接 Wi-Fi。

## macOS 无法构建

如果 `flutter doctor -v` 提示 Xcode incomplete，需要安装完整 Xcode，然后执行：

```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

如果 CocoaPods 缺失：

```bash
brew install cocoapods
```

如果 `flutter doctor -v` 提示 `Unable to get list of installed Simulator runtimes`，但 `xcodebuild -version` 正常，通常是没有安装 iOS Simulator runtime。可以在 Xcode 的 Settings 中下载，或执行：

```bash
xcodebuild -downloadPlatform iOS
```

如果下载失败并出现 Apple MobileAsset 网络错误，稍后重试或换一个网络。

## Android licenses 问题

执行：

```bash
flutter doctor --android-licenses
```

如果找不到 `sdkmanager`，确认 Android command-line tools 已安装，并且 Flutter 指向正确 SDK：

```bash
flutter config --android-sdk /Users/huangxin/Library/Android/sdk
```

## Flutter 命令被 macOS 拦截

如果 Homebrew 安装 Flutter 后命令无输出或异常退出，可能是 quarantine 属性导致。

可以清除：

```bash
xattr -dr com.apple.quarantine /opt/homebrew/share/flutter
```

## 文件接收后找不到

当前接收文件保存到应用文档目录。不同平台路径不同。后续应在 UI 中增加“打开接收目录”按钮。

临时排查方式：

- 查看接收记录中的路径。
- 在桌面端复制路径到 Finder 或文件管理器。

## 公共 Wi-Fi 不工作

很多公共 Wi-Fi 会隔离客户端，设备之间无法互相发现或连接。这是网络策略问题，不是应用逻辑问题。

解决方式：

- 使用个人热点。
- 使用家庭/办公室可信网络。
- 后续增加手动 IP 连接或中继模式。
