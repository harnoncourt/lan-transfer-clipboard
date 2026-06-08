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

  Map<String, Object?> toJson() {
    return {
      'type': type.name,
      'title': title,
      'detail': detail,
      'receivedAt': receivedAt.toIso8601String(),
    };
  }

  factory ReceivedItem.fromJson(Map<String, Object?> json) {
    final typeName = json['type'] as String? ?? ReceivedItemType.file.name;
    return ReceivedItem(
      type: ReceivedItemType.values.firstWhere(
        (type) => type.name == typeName,
        orElse: () => ReceivedItemType.file,
      ),
      title: json['title'] as String? ?? 'Received item',
      detail: json['detail'] as String? ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
