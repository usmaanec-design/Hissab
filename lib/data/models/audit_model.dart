class AuditModel {
  final String id;
  final String bookId;
  final String action;
  final String details;
  final String timestamp;

  const AuditModel({
    required this.id,
    required this.bookId,
    required this.action,
    required this.details,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'action': action,
      'details': details,
      'timestamp': timestamp,
    };
  }

  factory AuditModel.fromMap(Map<String, dynamic> map) {
    return AuditModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      action: map['action'] as String,
      details: map['details'] as String,
      timestamp: map['timestamp'] as String,
    );
  }
}
