class BookModel {
  final String id;
  final String name;
  final String currency;
  final int openingBalanceMinor;
  final String openingBalanceDate;
  final int color; // ARGB int, e.g. 0xFF2563EB
  final String? logo; // Local file path or base64 data URL
  final bool isArchived;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  const BookModel({
    required this.id,
    required this.name,
    required this.currency,
    required this.openingBalanceMinor,
    required this.openingBalanceDate,
    this.color = 0xFF2563EB, // Default Sapphire Blue
    this.logo,
    this.isArchived = false,
    this.isDeleted = false,
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
      'color': color,
      'logo': logo,
      'is_archived': isArchived ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
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
      color: map['color'] as int? ?? 0xFF2563EB,
      logo: map['logo'] as String?,
      isArchived: (map['is_archived'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
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
    int? color,
    String? logo,
    bool? isArchived,
    bool? isDeleted,
    String? updatedAt,
  }) {
    return BookModel(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      openingBalanceMinor: openingBalanceMinor ?? this.openingBalanceMinor,
      openingBalanceDate: openingBalanceDate ?? this.openingBalanceDate,
      color: color ?? this.color,
      logo: logo ?? this.logo,
      isArchived: isArchived ?? this.isArchived,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
