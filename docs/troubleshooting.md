# 故障排查

## 设备发现不到

可能原因：

- 两台设备不在同一局域网。
- Wi-Fi 开启了 AP isolation。
- 防火墙阻止 UDP 或入站连接。
- iOS 未授予 Local Network 权限。
- 路由器不转发 UDP broadcast。
- Windows 网络类型是公用网络，或没有允许应用通过专用网络防火墙。

排查方式：

1. 确认两台设备连接同一个 Wi-Fi。
2. 关闭 VPN 后重试。
3. 检查系统防火墙。
4. 重启应用。
5. 在路由器中关闭客户端隔离。

当前实现会同时向 `255.255.255.255` 和本机 `/24` 网段 directed broadcast 发送心跳。Android 端也会申请 `WifiManager.MulticastLock`。如果 Windows 或 Android 右上角仍显示 `0 在线`，通常说明当前网络或系统防火墙仍在拦截 UDP `45671` 或设备互访。

如果设备清单里已经能看到远端设备，但右上角仍显示 `0 在线`，请安装最新 APK。当前版本顶部状态栏会直接监听同一份 `service.peers` 数据，在线数应与设备清单数量一致。

macOS 和 Windows 不会因为窗口失焦、隐藏或最小化而暂停离线清理。远端退出后，在线数通常会在 15-20 秒内下降；如果没有下降，优先检查远端是否仍在后台运行或网络上是否仍有心跳包。

Windows 重点检查：

- 将当前 Wi-Fi/以太网设置为专用网络。
- 在 Windows Defender Firewall 中允许 `LAN Transfer.exe` 的专用网络访问。
- 关闭 VPN、代理安全软件或第三方防火墙后重试。

Android 重点检查：

- 保持应用在前台运行。
- 关闭 VPN。
- 避免访客 Wi-Fi、公司隔离网络和公共 Wi-Fi。
- 如果家庭 Wi-Fi 仍失败，用手机热点或另一台路由器交叉验证。

如果 Android 顶部显示 `localhost` 或错误 IP，请安装最新 APK。当前版本会通过 Android 原生接口读取设备型号和 Wi-Fi IPv4，并过滤不可连接的本地地址。

## Android 息屏后在线列表为空

Android 息屏或锁屏一段时间后，系统可能暂停 Dart 定时器、UDP socket 事件或 Wi-Fi 广播接收。当前版本在应用回到前台时会自动：

- 暂停后台期间的离线清理，避免刚解锁时立即清空列表。
- 重新加载本机 IPv4 地址。
- 重新绑定 UDP discovery socket。
- 连续发送多次 `hello` 心跳，加快重新发现。

如果解锁后等待 3-5 秒仍看不到设备，按“设备发现不到”章节检查 Wi-Fi 隔离、防火墙、VPN 和 UDP `45671`。

## 能发现设备但发送失败

可能原因：

- 远端 HTTP 端口被防火墙阻止。
- 对方应用已退出，但 peer 还没过期。
- 移动端进入后台导致服务不可用。
- 网络发生切换。
- 远端连接建立后没有继续响应，发送端会按剪贴板 15 秒、文件 60 秒超时报错。

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

当前接收文件保存到平台接收目录。不同平台路径不同。

平台行为：

- macOS：收件箱提供“在 Finder 中显示”。
- Windows：收件箱提供“在资源管理器中显示”，底层使用 `explorer.exe /select,"<path>"`；如果历史记录指向的文件已被移动或删除，会提示文件不存在。
- Android：文件写入系统下载目录 `Download/LAN Transfer`。可以从系统“下载”或文件管理器中直接找到。
- 收件箱历史会在应用重新打开后恢复显示；默认显示最近 20 条，底部“显示更多”可以继续展开。

排查方式：

- 查看接收记录中的路径。
- 桌面端使用收件箱里的文件夹或定位按钮。
- Android 端打开文件管理器，进入“下载”目录下的 `LAN Transfer` 文件夹；也可以从收件箱直接打开文件。若系统没有可处理该文件类型的应用，会提示打开失败。
- 如果收到同名文件，应用会保留旧文件，并把新文件保存为 `name (1).ext`、`name (2).ext` 等。
- 如果历史记录显示但文件打不开，通常是文件被用户从接收目录移动或删除了；重新接收一次即可。

## 公共 Wi-Fi 不工作

很多公共 Wi-Fi 会隔离客户端，设备之间无法互相发现或连接。这是网络策略问题，不是应用逻辑问题。

解决方式：

- 使用个人热点。
- 使用家庭/办公室可信网络。
- 后续增加手动 IP 连接或中继模式。
