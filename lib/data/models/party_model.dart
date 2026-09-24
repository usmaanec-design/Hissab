class PartyModel {
  final String id;
  final String bookId;
  final String name;
  final String? phone;
  final String? email;
  final String type; // 'customer', 'supplier', 'employee', 'other'
  final String? notes;
  final bool isDeleted;
  final String createdAt;
  final String updatedAt;

  const PartyModel({
    required this.id,
    required this.bookId,
    required this.name,
    this.phone,
    this.email,
    required this.type,
    this.notes,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'name': name,
      'phone': phone,
      'email': email,
      'type': type,
      'notes': notes,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory PartyModel.fromMap(Map<String, dynamic> map) {
    return PartyModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      type: map['type'] as String,
      notes: map['notes'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  PartyModel copyWith({
    String? name,
    String? phone,
    String? email,
    String? type,
    String? notes,
    bool? isDeleted,
    String? updatedAt,
  }) {
    return PartyModel(
      id: id,
      bookId: bookId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      type: type ?? this.type,
      notes: notes ?? this.notes,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
