class AccountModel {
  final String id;
  final String bookId;
  final String name;
  final String type; // cash, bank, mada, wallet, other
  final int openingBalanceMinor;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  const AccountModel({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    this.openingBalanceMinor = 0,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'name': name,
      'type': type,
      'opening_balance_minor': openingBalanceMinor,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory AccountModel.fromMap(Map<String, dynamic> map) {
    return AccountModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      openingBalanceMinor: (map['opening_balance_minor'] as num? ?? 0).toInt(),
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  AccountModel copyWith({
    String? name,
    String? type,
    int? openingBalanceMinor,
    bool? isDeleted,
    String? updatedAt,
  }) {
    return AccountModel(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
