class LanPeer {
  const LanPeer({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
    required this.host,
    required this.port,
    required this.lastSeen,
  });

  final String deviceId;
  final String deviceName;
  final String platform;
  final String host;
  final int port;
  final DateTime lastSeen;

  Uri get baseUri => Uri(scheme: 'http', host: host, port: port);

  LanPeer copyWith({
    String? host,
    int? port,
    DateTime? lastSeen,
  }) {
    return LanPeer(
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
      host: host ?? this.host,
      port: port ?? this.port,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  factory LanPeer.fromHello(Map<String, Object?> json, String host) {
    final rawPort = json['port'];
    final port = rawPort is num && rawPort.isFinite ? rawPort.toInt() : 0;
    return LanPeer(
      deviceId: json['deviceId'] as String,
      deviceName: json['deviceName'] as String? ?? 'Unknown device',
      platform: json['platform'] as String? ?? 'unknown',
      host: host,
      port: port,
      lastSeen: DateTime.now(),
    );
  }
}
