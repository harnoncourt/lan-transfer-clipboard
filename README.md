# LAN Transfer Clipboard

LAN Transfer Clipboard 是一个面向 macOS、Windows、Android、iOS 的局域网文件与剪贴板传输应用。项目采用 Flutter 构建统一客户端，当前 MVP 使用 UDP 广播发现局域网设备，并通过本机 HTTP 服务传输剪贴板文本和文件。

## 当前状态

当前仓库已经包含 Flutter 应用代码、核心传输服务和完整项目文档。开发环境状态如下：

- Flutter 3.44.1 已安装。
- Dart 3.12.1 已安装。
- Android toolchain 已配置，Android licenses 已接受。
- CocoaPods 1.16.2 已安装。
- Xcode 26.5 已安装并被系统选中。
- iOS Simulator runtime 尚未安装，`xcodebuild -downloadPlatform iOS` 当前因 Apple MobileAsset 网络错误下载失败。

## 已实现能力

- 启动本机局域网传输服务。
- 每 3 秒通过 UDP limited broadcast 和本机网段 directed broadcast 发送设备心跳。
- 自动发现同一局域网内其他在线设备。
- 向选中设备发送剪贴板文本。
- 选择本地文件并发送给选中设备。
- 接收剪贴板文本和文件。
- 将收到的文件保存到应用文档目录。
- 在界面中展示在线设备、发送状态和接收记录。
- macOS 收件箱支持 Finder 显示文件；Windows 收件箱支持资源管理器显示文件。
- Android 收件箱支持直接打开收到的文件，桌面专用的文件夹/定位动作会自动隐藏。

## 技术栈

- Flutter：跨平台 UI 和应用壳。
- Dart `dart:io`：UDP、HTTP server、HTTP client、文件读写。
- `file_picker`：跨平台选择文件。
- `path_provider`：获取平台应用目录。
- `crypto`：生成稳定设备标识。

## 快速开始

```bash
cd /Users/huangxin/ai/codex/lan-transfer-clipboard
flutter pub get
flutter test
```

Windows 包可以通过 GitHub Actions 云端打包，不需要本地 Windows。见 [Windows 开发与打包](docs/windows.md)。

当前 Windows 云端打包 workflow 已验证通过，最新产物可在 GitHub Actions run 中下载：

[Build Windows #27133176865](https://github.com/harnoncourt/lan-transfer-clipboard/actions/runs/27133176865)

如果需要生成完整平台目录：

```bash
flutter create --platforms=macos,windows,android,ios .
flutter pub get
```

运行桌面端：

```bash
flutter run -d macos
```

当前机器已经安装完整 Xcode。若需要 iOS 模拟器，请在 Xcode 的 Platforms/Components 设置中下载 iOS Simulator runtime，或稍后重试 `xcodebuild -downloadPlatform iOS`。

## 文档索引

- [项目概览](docs/project-overview.md)
- [快速开始](docs/getting-started.md)
- [架构设计](docs/architecture.md)
- [协议规范](docs/protocol.md)
- [平台配置](docs/platform-setup.md)
- [Windows 开发与打包](docs/windows.md)
- [开发指南](docs/development.md)
- [测试指南](docs/testing.md)
- [安全模型](docs/security.md)
- [发布清单](docs/release-checklist.md)
- [路线图](docs/roadmap.md)
- [故障排查](docs/troubleshooting.md)

## 重要限制

当前版本是 MVP，不应直接作为生产级工具使用。主要限制包括：

- 传输内容尚未加密。
- 尚未实现设备配对和信任管理。
- 尚未实现接收前确认。
- 尚未限制文件大小。
- 移动端后台传输能力尚未实现。
- UDP 广播在部分网络、iOS 环境或隔离 Wi-Fi 下可能不可用；Windows 还需要允许专用网络防火墙访问。

生产化前请优先完成 [安全模型](docs/security.md) 中的 P0/P1 项。
