enum ReceivedItemType { clipboard, file }

class ReceivedItem {
  const ReceivedItem({
    required this.type,
    required this.title,
    required this.detail,
    required this.receivedAt,
  });

  final ReceivedItemType type;
  final String title;
  final String detail;
  final DateTime receivedAt;
}
