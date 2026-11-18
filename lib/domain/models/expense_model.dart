class ExpenseModel {
  final String id;
  final String groupId;
  final String description;
  final int amountCents;
  final int originalAmountCents;
  final String currency;
  final String exchangeRate;
  final String payerId;
  final String category;
  final String divisionMode;
  final int occurredAt;
  final String notes;
  final String createdBy;
  final String? receiptLocalPath;
  final String? receiptRemotePath;
  final int revision;
  final int updatedAt;
  final List<ExpenseShareModel> shares;

  const ExpenseModel({
    required this.id,
    required this.groupId,
    required this.description,
    required this.amountCents,
    required this.originalAmountCents,
    required this.currency,
    required this.exchangeRate,
    required this.payerId,
    required this.category,
    required this.divisionMode,
    required this.occurredAt,
    required this.notes,
    required this.createdBy,
    this.receiptLocalPath,
    this.receiptRemotePath,
    required this.revision,
    required this.updatedAt,
    this.shares = const [],
  });

  factory ExpenseModel.fromMap(
      Map<String, Object?> map, {
        List<ExpenseShareModel> shares = const [],
      }) {
    return ExpenseModel(
      id: map['id'] as String,
      groupId: map['group_id'] as String,
      description: map['description'] as String,
      amountCents: map['amount_cents'] as int,
      originalAmountCents: map['original_amount_cents'] as int,
      currency: map['currency'] as String,
      exchangeRate: map['exchange_rate'] as String,
      payerId: map['payer_id'] as String,
      category: map['category'] as String,
      divisionMode: map['division_mode'] as String,
      occurredAt: map['occurred_at'] as int,
      notes: map['notes'] as String,
      createdBy: map['created_by'] as String,
      receiptLocalPath: map['receipt_local_path'] as String?,
      receiptRemotePath: map['receipt_remote_path'] as String?,
      revision: map['revision'] as int,
      updatedAt: map['updated_at'] as int,
      shares: shares,
    );
  }
}

class ExpenseShareModel {
  final String expenseId;
  final String participantId;
  final int amountCents;

  const ExpenseShareModel({
    required this.expenseId,
    required this.participantId,
    required this.amountCents,
  });

  factory ExpenseShareModel.fromMap(Map<String, Object?> map) {
    return ExpenseShareModel(
      expenseId: map['expense_id'] as String,
      participantId: map['participant_id'] as String,
      amountCents: map['amount_cents'] as int,
    );
  }
}