# 发布清单

## 发布前通用检查

- `flutter doctor -v` 无关键错误。
- `flutter analyze` 通过。
- `flutter test` 通过。
- 文档与实际行为一致。
- 版本号已更新。
- 权限说明准确。
- 已测试两台真实设备互传。
- 已测试拒绝防火墙权限后的错误提示。
- 已测试应用重启后收件箱历史仍保留。
- 已测试收件箱“显示更多”能展开历史记录。
- 已测试顶部在线数和设备清单数量一致。

## macOS

- 完整 Xcode 已安装。
- CocoaPods 可用。
- entitlements 包含 network client/server。
- 已测试首次启动的本地网络/防火墙弹窗。
- 发布包已签名。
- 如需分发给普通用户，完成 notarization。

构建命令：

```bash
flutter build macos
```

## Windows

- 在 Windows 真机或虚拟机上构建。
- 测试 Windows Defender Firewall 弹窗。
- 测试专用网络下互传。
- 测试右上角在线设备数能正确显示远端设备。
- 测试收件箱“在资源管理器中显示”能选中收到的文件。
- 发布安装包签名。

构建命令：

```bash
flutter build windows
```

## Android

- AndroidManifest 权限完整。
- 真机测试同一 Wi-Fi 发现。
- 测试 `WifiManager.MulticastLock` 生效后右上角在线设备数能正确显示远端设备。
- 测试 Android 设备清单正常时，顶部在线数不会停留在 `0 在线`。
- 测试收件箱不会显示桌面端文件夹/定位按钮。
- Android 13+ 通知权限按需处理。
- release keystore 已配置。
- 已测试 APK/AAB 安装。

构建命令：

```bash
flutter build apk
flutter build appbundle
```

## iOS

- 完整 Xcode 已安装。
- Apple Developer 账号已配置。
- `Info.plist` 包含 Local Network 权限说明。
- 真机测试 Local Network 权限弹窗。
- 前台运行时互传成功。
- App Store 隐私说明与实际行为一致。

构建命令：

```bash
flutter build ios
```

## MVP 不建议公开发布的原因

当前版本缺少设备配对和传输加密。公开发布前至少应完成：

- 配对和信任管理。
- 接收确认。
- 文件大小限制。
- 错误提示改进。
- 安全说明和隐私说明。
