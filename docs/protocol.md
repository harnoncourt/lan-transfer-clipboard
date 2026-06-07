# 协议规范

本文档描述当前 MVP 的局域网发现协议和传输协议。版本号为 `1`。

## 端口

| 用途 | 协议 | 端口 |
| --- | --- | --- |
| 设备发现 | UDP broadcast | `45671` |
| 内容传输 | HTTP | 启动时随机可用端口 |

HTTP 端口会通过 UDP `hello` 消息告知其他设备。

## 设备发现

每台设备启动后绑定 UDP `45671`，并每 3 秒向 `255.255.255.255:45671` 广播一次 `hello`。

### Hello Payload

```json
{
  "type": "hello",
  "deviceId": "stable-device-id",
  "deviceName": "MacBook-Pro",
  "platform": "macos",
  "port": 51432,
  "version": 1
}
```

字段说明：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `type` | string | 是 | 当前固定为 `hello` |
| `deviceId` | string | 是 | 本机稳定设备 ID |
| `deviceName` | string | 否 | 显示给用户的设备名称 |
| `platform` | string | 否 | `macos`、`windows`、`android`、`ios` 等 |
| `port` | number | 是 | 本机 HTTP server 端口 |
| `version` | number | 是 | 协议版本 |

### 在线状态

设备收到远端 `hello` 后更新本地 peer 列表。超过 15 秒没有收到某个设备的心跳，则认为该设备离线。

### 自身过滤

如果收到的 `deviceId` 等于本机 `deviceId`，忽略该消息。

## HTTP 传输协议

每台设备启动一个 HTTP server，绑定 `0.0.0.0` 和随机可用端口。

### `GET /info`

返回本机设备信息，格式与 `hello` payload 基本一致。

响应示例：

```json
{
  "type": "hello",
  "deviceId": "stable-device-id",
  "deviceName": "MacBook-Pro",
  "platform": "macos",
  "port": 51432,
  "version": 1
}
```

### `POST /clipboard`

发送剪贴板文本。

请求头：

```http
Content-Type: application/json
```

请求体：

```json
{
  "text": "hello from clipboard"
}
```

成功响应：

```http
204 No Content
```

### `POST /file`

发送文件二进制内容。

请求头：

```http
Content-Type: application/octet-stream
X-File-Name: encoded-file-name.txt
Content-Length: 12345
```

请求体为原始文件字节。

成功响应：

```http
204 No Content
```

接收端会：

1. 读取 `X-File-Name`。
2. URL decode 文件名。
3. 替换文件名中的非法路径字符。
4. 保存到应用文档目录。
5. 写入接收记录。

## 错误处理

当前错误处理较简单：

- 未知路径返回 `404`。
- 未捕获异常返回 `500`。
- 发送端收到 `>= 300` 的 HTTP 状态码时抛出错误。

后续建议引入统一错误结构：

```json
{
  "error": {
    "code": "file_too_large",
    "message": "File exceeds the receiver limit."
  }
}
```

## 兼容性策略

当前协议版本为 `1`。后续新增字段时保持向后兼容：

- 接收方忽略未知字段。
- 必填字段不随意改名。
- 破坏性变化提升 `version`。

## 生产化协议建议

生产版本应加入：

- 配对握手。
- 设备公钥。
- 消息签名。
- 端到端加密。
- 文件 hash 校验。
- 分片上传。
- 断点续传。
- 传输进度事件。
