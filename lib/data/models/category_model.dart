class CategoryModel {
  final String id;
  final String bookId;
  final String name;
  final String type; // 'income' or 'expense'
  final String icon;
  final int color;
  final bool isDefault;
  final bool isDeleted;
  final String createdAt;

  const CategoryModel({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.icon,
    required this.color,
    this.isDefault = false,
    this.isDeleted = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'name': name,
      'type': type,
      'icon': icon,
      'color': color,
      'is_default': isDefault ? 1 : 0,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt,
    };
  }

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      name: map['name'] as String,
      type: map['type'] as String,
      icon: map['icon'] as String,
      color: (map['color'] as num).toInt(),
      isDefault: (map['is_default'] as int? ?? 0) == 1,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
    );
  }

  CategoryModel copyWith({
    String? name,
    String? type,
    String? icon,
    int? color,
    bool? isDefault,
    bool? isDeleted,
  }) {
    return CategoryModel(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      type: type ?? this.type,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      isDefault: isDefault ?? this.isDefault,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
    );
  }
}
