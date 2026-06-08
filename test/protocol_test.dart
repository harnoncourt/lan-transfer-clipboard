import 'package:flutter_test/flutter_test.dart';
import 'package:lan_transfer_clipboard/src/models/received_item.dart';

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
}
