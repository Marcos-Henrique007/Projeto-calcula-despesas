import 'expense_share.dart';

enum ExpenseDivisionMode {
  equal,
  selected,
  exact,
  percentages,
  weights,
}

class Expense {
  const Expense({
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
    required this.revision,
    required this.updatedAt,
    this.receiptLocalPath,
    this.receiptRemotePath,
    this.deletedAt,
    this.shares = const [],
  });

  final String id;
  final String groupId;
  final String description;

  // Valores monetários armazenados em centavos.
  final int amountCents;
  final int originalAmountCents;

  final String currency;
  final String exchangeRate;
  final String payerId;
  final String category;

  final ExpenseDivisionMode divisionMode;

  final DateTime occurredAt;
  final String notes;
  final String createdBy;

  final String? receiptLocalPath;
  final String? receiptRemotePath;

  final int revision;
  final DateTime updatedAt;
  final DateTime? deletedAt;

  final List<ExpenseShare> shares;

  bool get isDeleted => deletedAt != null;

  double get amount => amountCents / 100;

  factory Expense.fromRow(
      Map<String, Object?> row, {
        List<ExpenseShare> shares = const [],
      }) {
    final amountCents = row['amount_cents'] as int;

    final divisionModeName =
        row['division_mode'] as String? ?? 'equal';

    return Expense(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      description: row['description'] as String,
      amountCents: amountCents,
      originalAmountCents:
      row['original_amount_cents'] as int? ?? amountCents,
      currency: row['currency'] as String,
      exchangeRate: row['exchange_rate'] as String,
      payerId: row['payer_id'] as String,
      category: row['category'] as String,
      divisionMode: ExpenseDivisionMode.values.firstWhere(
            (mode) => mode.name == divisionModeName,
        orElse: () => ExpenseDivisionMode.equal,
      ),
      occurredAt: DateTime.fromMillisecondsSinceEpoch(
        row['occurred_at'] as int,
      ),
      notes: row['notes'] as String? ?? '',
      createdBy: row['created_by'] as String? ?? '',
      receiptLocalPath: row['receipt_local_path'] as String?,
      receiptRemotePath: row['receipt_remote_path'] as String?,
      revision: row['revision'] as int? ?? 1,
      updatedAt: DateTime.fromMillisecondsSinceEpoch(
        row['updated_at'] as int,
      ),
      deletedAt: row['deleted_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
        row['deleted_at'] as int,
      ),
      shares: List.unmodifiable(shares),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'group_id': groupId,
      'description': description,
      'amount_cents': amountCents,
      'original_amount_cents': originalAmountCents,
      'currency': currency,
      'exchange_rate': exchangeRate,
      'payer_id': payerId,
      'category': category,
      'division_mode': divisionMode.name,
      'occurred_at': occurredAt.millisecondsSinceEpoch,
      'notes': notes,
      'created_by': createdBy,
      'receipt_local_path': receiptLocalPath,
      'receipt_remote_path': receiptRemotePath,
      'revision': revision,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'deleted_at': deletedAt?.millisecondsSinceEpoch,
    };
  }

  Expense copyWith({
    String? description,
    int? amountCents,
    int? originalAmountCents,
    String? currency,
    String? exchangeRate,
    String? payerId,
    String? category,
    ExpenseDivisionMode? divisionMode,
    DateTime? occurredAt,
    String? notes,
    String? receiptLocalPath,
    String? receiptRemotePath,
    int? revision,
    DateTime? updatedAt,
    DateTime? deletedAt,
    List<ExpenseShare>? shares,
  }) {
    return Expense(
      id: id,
      groupId: groupId,
      description: description ?? this.description,
      amountCents: amountCents ?? this.amountCents,
      originalAmountCents:
      originalAmountCents ?? this.originalAmountCents,
      currency: currency ?? this.currency,
      exchangeRate: exchangeRate ?? this.exchangeRate,
      payerId: payerId ?? this.payerId,
      category: category ?? this.category,
      divisionMode: divisionMode ?? this.divisionMode,
      occurredAt: occurredAt ?? this.occurredAt,
      notes: notes ?? this.notes,
      createdBy: createdBy,
      receiptLocalPath: receiptLocalPath ?? this.receiptLocalPath,
      receiptRemotePath: receiptRemotePath ?? this.receiptRemotePath,
      revision: revision ?? this.revision,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      shares: shares ?? this.shares,
    );
  }
}