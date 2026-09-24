enum TransactionType {
  income,
  expense,
  transferIn,
  transferOut,
  receivable,
  payable,
  paymentReceived,
  paymentMade,
  adjustment;

  String toDbString() {
    switch (this) {
      case TransactionType.income:
        return 'INCOME';
      case TransactionType.expense:
        return 'EXPENSE';
      case TransactionType.transferIn:
        return 'TRANSFER_IN';
      case TransactionType.transferOut:
        return 'TRANSFER_OUT';
      case TransactionType.receivable:
        return 'RECEIVABLE';
      case TransactionType.payable:
        return 'PAYABLE';
      case TransactionType.paymentReceived:
        return 'PAYMENT_RECEIVED';
      case TransactionType.paymentMade:
        return 'PAYMENT_MADE';
      case TransactionType.adjustment:
        return 'ADJUSTMENT';
    }
  }

  static TransactionType fromDbString(String str) {
    switch (str.toUpperCase()) {
      case 'INCOME':
        return TransactionType.income;
      case 'EXPENSE':
        return TransactionType.expense;
      case 'TRANSFER_IN':
        return TransactionType.transferIn;
      case 'TRANSFER_OUT':
        return TransactionType.transferOut;
      case 'RECEIVABLE':
        return TransactionType.receivable;
      case 'PAYABLE':
        return TransactionType.payable;
      case 'PAYMENT_RECEIVED':
        return TransactionType.paymentReceived;
      case 'PAYMENT_MADE':
        return TransactionType.paymentMade;
      case 'ADJUSTMENT':
        return TransactionType.adjustment;
      default:
        return TransactionType.expense;
    }
  }

  bool get isMoneyIn =>
      this == TransactionType.income ||
      this == TransactionType.paymentReceived ||
      this == TransactionType.transferIn;

  bool get isMoneyOut =>
      this == TransactionType.expense ||
      this == TransactionType.paymentMade ||
      this == TransactionType.transferOut;
}

class TransactionModel {
  final String id;
  final String bookId;
  final String? accountId;
  final String? partyId;
  final String? categoryId;
  final TransactionType type;
  final int amountMinorUnit; // Must be strictly > 0
  final String date; // YYYY-MM-DD local
  final String time; // HH:mm local
  final String? description;
  final String? paymentMethod;
  final String? referenceNumber;
  final String? attachmentPath;
  final String? transferId;
  final bool isDeleted;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  const TransactionModel({
    required this.id,
    required this.bookId,
    this.accountId,
    this.partyId,
    this.categoryId,
    required this.type,
    required this.amountMinorUnit,
    required this.date,
    required this.time,
    this.description,
    this.paymentMethod,
    this.referenceNumber,
    this.attachmentPath,
    this.transferId,
    this.isDeleted = false,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'account_id': accountId,
      'party_id': partyId,
      'category_id': categoryId,
      'type': type.toDbString(),
      'amount_minor': amountMinorUnit,
      'date': date,
      'time': time,
      'description': description,
      'payment_method': paymentMethod,
      'reference_number': referenceNumber,
      'attachment_path': attachmentPath,
      'transfer_id': transferId,
      'is_deleted': isDeleted ? 1 : 0,
      'deleted_at': deletedAt,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      bookId: map['book_id'] as String,
      accountId: map['account_id'] as String?,
      partyId: map['party_id'] as String?,
      categoryId: map['category_id'] as String?,
      type: TransactionType.fromDbString(map['type'] as String),
      amountMinorUnit: (map['amount_minor'] as num).toInt(),
      date: map['date'] as String,
      time: map['time'] as String,
      description: map['description'] as String?,
      paymentMethod: map['payment_method'] as String?,
      referenceNumber: map['reference_number'] as String?,
      attachmentPath: map['attachment_path'] as String?,
      transferId: map['transfer_id'] as String?,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      deletedAt: map['deleted_at'] as String?,
      createdAt: map['created_at'] as String,
      updatedAt: map['updated_at'] as String,
    );
  }

  TransactionModel copyWith({
    String? accountId,
    String? partyId,
    String? categoryId,
    TransactionType? type,
    int? amountMinorUnit,
    String? date,
    String? time,
    String? description,
    String? paymentMethod,
    String? referenceNumber,
    String? attachmentPath,
    String? transferId,
    bool? isDeleted,
    String? deletedAt,
    String? updatedAt,
  }) {
    return TransactionModel(
      id: id,
      bookId: bookId,
      accountId: accountId ?? this.accountId,
      partyId: partyId ?? this.partyId,
      categoryId: categoryId ?? this.categoryId,
      type: type ?? this.type,
      amountMinorUnit: amountMinorUnit ?? this.amountMinorUnit,
      date: date ?? this.date,
      time: time ?? this.time,
      description: description ?? this.description,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      referenceNumber: referenceNumber ?? this.referenceNumber,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      transferId: transferId ?? this.transferId,
      isDeleted: isDeleted ?? this.isDeleted,
      deletedAt: deletedAt ?? this.deletedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
