import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

class DeviceIdentity {
  DeviceIdentity._({
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  final String deviceId;
  final String deviceName;
  final String platform;

  static Future<DeviceIdentity> load() async {
    final hostname = Platform.localHostname;
    final platform = Platform.operatingSystem;
    final directory = await getApplicationSupportDirectory();
    final file = File('${directory.path}/device-id');
    final existing = await file.exists() ? await file.readAsString() : null;
    final deviceId = existing?.trim().isNotEmpty == true
        ? existing!.trim()
        : sha256
            .convert(
              '$hostname:$platform:${DateTime.now().microsecondsSinceEpoch}'.codeUnits,
            )
            .toString()
            .substring(0, 16);

    if (existing == null || existing.trim().isEmpty) {
      await file.create(recursive: true);
      await file.writeAsString(deviceId);
    }

    return DeviceIdentity._(
      deviceId: deviceId,
      deviceName: hostname.isEmpty ? 'LAN device' : hostname,
      platform: platform,
    );
  }
}
