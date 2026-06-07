# 快速开始

## 环境要求

基础要求：

- macOS 开发机。
- Flutter 3.44.1 或更新稳定版本。
- Dart 3.12.1 或兼容版本。

当前项目约束：

```yaml
environment:
  sdk: ">=3.4.0 <4.0.0"
```

## 安装依赖

```bash
cd /Users/huangxin/ai/codex/lan-transfer-clipboard
flutter pub get
```

## 运行测试

```bash
flutter test
```

## 生成平台目录

如果还没有 `macos/`、`windows/`、`android/`、`ios/` 目录，执行：

```bash
flutter create --platforms=macos,windows,android,ios .
flutter pub get
```

这个命令会在当前目录补齐 Flutter 平台工程，同时保留已有 `lib/`、`pubspec.yaml` 和文档。

## 本机运行

macOS：

```bash
flutter run -d macos
```

Chrome 仅适合 UI 原型验证。当前网络核心依赖 `dart:io`，不能作为完整 Web 版本运行。

## 两台设备联调

1. 确保两台设备连接同一个 Wi-Fi 或同一个有线局域网。
2. 分别运行应用。
3. 首次运行时允许本地网络或防火墙访问。
4. 等待设备列表出现对方设备。
5. 选择对方设备。
6. 点击 `Send clipboard` 或 `Send file`。

## 常用命令

```bash
flutter doctor -v
flutter devices
flutter pub get
flutter test
flutter analyze
flutter run -d macos
```

## 当前环境说明

当前机器已经安装 Xcode 26.5，Flutter 能识别 Xcode。若需要 iOS 模拟器，还需要下载 iOS Simulator runtime：

```bash
xcodebuild -downloadPlatform iOS
```

下载完成后重新执行：

```bash
flutter doctor -v
```
