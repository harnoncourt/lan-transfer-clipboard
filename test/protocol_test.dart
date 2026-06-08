import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lan_transfer_clipboard/src/models/lan_peer.dart';
import 'package:lan_transfer_clipboard/src/models/received_item.dart';
import 'package:lan_transfer_clipboard/src/services/lan_transfer_service.dart';
import 'package:lan_transfer_clipboard/src/ui/home_screen.dart';

void main() {
  test('received item can be restored from persisted json', () {
    final receivedAt = DateTime.parse('2026-06-08T19:45:00.000');
    final item = ReceivedItem(
      type: ReceivedItemType.file,
      title: 'report.pdf',
      detail: '/storage/emulated/0/Download/LAN Transfer/report.pdf',
      receivedAt: receivedAt,
    );

    final restored = ReceivedItem.fromJson(item.toJson());

    expect(restored.type, ReceivedItemType.file);
    expect(restored.title, 'report.pdf');
    expect(
      restored.detail,
      '/storage/emulated/0/Download/LAN Transfer/report.pdf',
    );
    expect(restored.receivedAt, receivedAt);
  });

  test('lan peer parses numeric ports defensively', () {
    final intPeer = LanPeer.fromHello(
      {
        'deviceId': 'a',
        'deviceName': 'A',
        'platform': 'windows',
        'port': 45678,
      },
      '192.168.1.2',
    );
    final doublePeer = LanPeer.fromHello(
      {
        'deviceId': 'b',
        'deviceName': 'B',
        'platform': 'macos',
        'port': 45678.0,
      },
      '192.168.1.3',
    );
    final invalidPeer = LanPeer.fromHello(
      {
        'deviceId': 'c',
        'deviceName': 'C',
        'platform': 'android',
        'port': double.nan,
      },
      '192.168.1.4',
    );

    expect(intPeer.port, 45678);
    expect(doublePeer.port, 45678);
    expect(invalidPeer.port, 0);
  });

  test('received item time includes date outside current day', () {
    final now = DateTime(2026, 6, 8, 12);

    expect(
      formatReceivedTime(DateTime(2026, 6, 8, 9, 5), now: now),
      '09:05',
    );
    expect(
      formatReceivedTime(DateTime(2026, 6, 7, 23, 59), now: now),
      '06-07 23:59',
    );
  });

  test('clipboard send times out when peer does not respond', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      // Leave the response open to simulate a peer that accepted the
      // connection but stopped responding.
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final service = LanTransferService(
      connectionTimeout: const Duration(milliseconds: 200),
      clipboardTimeout: const Duration(milliseconds: 100),
    );
    final peer = LanPeer(
      deviceId: 'peer',
      deviceName: 'Peer',
      platform: 'test',
      host: InternetAddress.loopbackIPv4.address,
      port: server.port,
      lastSeen: DateTime.now(),
    );

    await expectLater(
      service.sendClipboard(peer, 'hello'),
      throwsA(isA<TimeoutException>()),
    );
  });
}
