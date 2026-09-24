class BookModel {
  final String id;
  final String name;
  final String currency;
  final int openingBalanceMinor;
  final String openingBalanceDate;
  final bool isArchived;
  final String createdAt;
  final String updatedAt;

  const BookModel({
    required this.id,
    required this.name,
    required this.currency,
    required this.openingBalanceMinor,
    required this.openingBalanceDate,
    this.isArchived = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'opening_balance_minor': openingBalanceMinor,
      'opening_balance_date': openingBalanceDate,
      'is_archived': isArchived ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory BookModel.fromMap(Map<String, dynamic> map) {
    return BookModel(
      id: map['id'] as String,
      name: map['name'] as String,
      currency: map['currency'] as String,
      openingBalanceMinor: (map['opening_balance_minor'] as num).toInt(),
      openingBalanceDate: map['opening_balance_date'] as String,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  BookModel copyWith({
    String? id,
    String? name,
    String? currency,
    int? openingBalanceMinor,
    String? openingBalanceDate,
    bool? isArchived,
    String? updatedAt,
  }) {
    return BookModel(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
