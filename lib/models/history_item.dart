class HistoryItem {
  final String filePath;
  final String reading;
  final DateTime timestamp;

  const HistoryItem({
    required this.filePath,
    required this.reading,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'filePath': filePath,
        'reading': reading,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        filePath: json['filePath'] as String,
        reading: json['reading'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}
