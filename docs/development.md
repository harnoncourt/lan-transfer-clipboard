# 开发指南

## 目录结构

```text
lan-transfer-clipboard/
  lib/
    main.dart
    src/
      models/
        lan_peer.dart
        received_item.dart
      services/
        device_identity.dart
        lan_transfer_service.dart
      ui/
        home_screen.dart
  docs/
  test/
  pubspec.yaml
```

## 代码分层

### UI 层

位置：`lib/src/ui/`

职责：

- 展示设备列表。
- 展示发送操作。
- 展示接收记录。
- 调用服务层方法，不直接处理网络协议。

### Service 层

位置：`lib/src/services/`

职责：

- 设备身份。
- UDP 发现。
- HTTP server。
- HTTP client。
- 文件保存。
- 状态通知。

### Model 层

位置：`lib/src/models/`

职责：

- 定义 UI 和服务层共享的数据结构。
- 避免把原始 JSON 直接扩散到 UI。

## 开发原则

- 优先保持协议简单可测。
- UI 不直接依赖 socket 或 HTTP 细节。
- 网络服务必须能明确启动和停止。
- 接收文件时必须清理文件名。
- 新增网络入口时必须同步更新 `docs/protocol.md`。
- 新增平台权限时必须同步更新 `docs/platform-setup.md`。

## 新增功能流程

1. 在文档中定义行为和协议。
2. 在 model 层补充数据结构。
3. 在 service 层实现核心逻辑。
4. 在 UI 层加入入口和状态反馈。
5. 补测试。
6. 更新故障排查和发布清单。

## 常见开发任务

### 增加新的接收类型

例如新增图片预览：

1. 扩展 `ReceivedItemType`。
2. 更新 `/file` 接收后的 metadata。
3. 在 `_ReceivedPanel` 中按类型展示不同图标或预览。
4. 更新 `docs/protocol.md`。

### 增加传输进度

建议引入：

- `TransferTask` model。
- 上传进度 stream。
- 接收端按 chunk 写入。
- UI 中展示进度和取消按钮。

### 增加设备配对

建议新增：

- `PairedDevice` model。
- 本地信任存储。
- 配对码或 QR code。
- 每次请求附带设备签名。

## 格式化和检查

```bash
dart format lib test
flutter analyze
flutter test
```

## 依赖管理

添加依赖：

```bash
flutter pub add package_name
```

升级依赖前先查看：

```bash
flutter pub outdated
```

## 调试建议

局域网调试时，优先确认：

- 两台设备是否在同一网段。
- 防火墙是否允许入站连接。
- UDP 广播是否被路由器隔离。
- HTTP 端口是否能从另一台设备访问。

可以先用 `GET /info` 验证远端 HTTP 服务是否可达。
