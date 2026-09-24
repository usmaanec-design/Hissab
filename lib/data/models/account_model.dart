class AccountModel {
  final String id;
  final String bookId;
  final String name;
  final String type; // cash, bank, mada, wallet, other
  final int openingBalanceMinor;
  final String createdAt;
  final String updatedAt;

  const AccountModel({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    this.openingBalanceMinor = 0,
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
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  AccountModel copyWith({
    String? name,
    String? type,
    int? openingBalanceMinor,
    String? updatedAt,
  }) {
    return AccountModel(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
