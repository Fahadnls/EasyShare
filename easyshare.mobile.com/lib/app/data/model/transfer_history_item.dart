enum TransferDirection { sent, received }

enum TransferHistoryStatus { completed, failed, cancelled }

class TransferHistoryItem {
  const TransferHistoryItem({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.date,
    required this.direction,
    required this.status,
    required this.location,
    this.sourcePath,
  });

  final String id;
  final String name;
  final String type;
  final int size;
  final DateTime date;
  final TransferDirection direction;
  final TransferHistoryStatus status;
  final String location;
  final String? sourcePath;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'size': size,
    'date': date.toIso8601String(),
    'direction': direction.name,
    'status': status.name,
    'location': location,
    'sourcePath': sourcePath,
  };

  factory TransferHistoryItem.fromJson(Map<String, dynamic> json) {
    return TransferHistoryItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: json['type'] as String? ?? 'file',
      size: (json['size'] as num?)?.toInt() ?? 0,
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      direction: TransferDirection.values.firstWhere(
        (value) => value.name == json['direction'],
        orElse: () => TransferDirection.received,
      ),
      status: TransferHistoryStatus.values.firstWhere(
        (value) => value.name == json['status'],
        orElse: () => TransferHistoryStatus.failed,
      ),
      location: json['location'] as String? ?? '',
      sourcePath: json['sourcePath'] as String?,
    );
  }
}
