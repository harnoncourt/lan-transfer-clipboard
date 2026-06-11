# Windows 开发与打包

## 当前状态

Windows 平台工程已经生成并配置为 `LAN Transfer`。当前 macOS 开发机无法直接构建 Windows 原生应用，Windows 构建需要在 Windows 10/11 上执行。

## 已配置内容

- 可执行文件名：`LAN Transfer.exe`
- 窗口标题：`LAN Transfer`
- 默认窗口大小：`1280x720`
- 资源信息：产品名、文件描述、版权信息
- DPI：`PerMonitorV2`
- 长路径支持：已开启
- 收件箱文件定位：使用 Windows 资源管理器，而不是 macOS Finder 行为。

## Windows 构建环境

需要安装：

- Flutter 3.44.1 或兼容版本
- Visual Studio 2022
- Desktop development with C++
- Windows 10/11 SDK

检查：

```powershell
flutter doctor -v
```

## 构建

在 Windows PowerShell 中执行：

```powershell
cd path\to\lan-transfer-clipboard
flutter pub get
flutter build windows --release
```

产物目录：

```text
build\windows\x64\runner\Release
```

## 打包 ZIP

项目提供脚本：

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\package_windows.ps1
```

输出：

```text
dist\LAN-Transfer-0.1.1-windows-x64.zip
```

## 不在本地 Windows 打包

Flutter 不支持在 macOS 上直接交叉编译 Windows 桌面应用。推荐使用 GitHub Actions 的 Windows runner 打包。

本项目已提供 workflow：

```text
.github/workflows/build-windows.yml
```

使用方式：

1. 将项目推送到 GitHub 仓库。
2. 打开仓库的 `Actions` 页面。
3. 选择 `Build Windows`。
4. 点击 `Run workflow`。
5. 等构建完成后，在 workflow run 的 `Artifacts` 中下载 `LAN-Transfer-0.1.1-windows-x64.zip`。

当前 workflow 已验证通过：

[Build Windows](https://github.com/harnoncourt/lan-transfer-clipboard/actions/workflows/build-windows.yml)

当前已下载到本地的 ZIP：

```text
dist/LAN-Transfer-0.1.1-windows-x64.zip
```

也可以创建 tag 触发：

```bash
git tag v0.1.1
git push origin v0.1.1
```

## 防火墙

首次运行时 Windows Defender Firewall 可能弹窗。请选择允许专用网络访问，否则局域网发现和接收文件会失败。

如果右上角一直显示 `0 在线`：

- 确认当前网络类型是专用网络。
- 确认 Windows Defender Firewall 已允许 `LAN Transfer.exe` 访问专用网络。
- 关闭 VPN 或第三方防火墙后重试。
- 确认另一台设备和 Windows 处在同一 Wi-Fi/网段。

macOS 和 Windows 桌面端不会因为窗口失焦、隐藏或最小化而暂停离线清理。远端退出后，在线数通常会在 15-20 秒内下降。

## 收件箱行为

- “打开接收目录”会调用 `explorer.exe <folder>`。
- “在资源管理器中显示”会先确认文件仍存在，再调用 `explorer.exe /select,"<file>"`。
- `explorer.exe` 即使成功打开也会返回非零退出码（Windows 已知行为），应用对这两个操作忽略退出码，以调用前的文件存在性检查为准，避免成功打开后误报“操作失败”。
- 剪贴板文本记录只显示复制动作，不显示文件定位动作。

## 正式发布建议

- 使用代码签名证书签名 exe。
- 使用 MSIX 或 Inno Setup 制作安装包。
- 在安装器或首次启动说明中提示用户允许专用网络访问。
