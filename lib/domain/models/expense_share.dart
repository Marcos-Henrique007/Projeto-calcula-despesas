class ExpenseShare {
  const ExpenseShare({
    this.expenseId,
    required this.participantId,
    required this.cents,
  });

  final String? expenseId;
  final String participantId;
  final int cents;

  factory ExpenseShare.fromRow(Map<String, Object?> row) {
    return ExpenseShare(
      expenseId: row['expense_id'] as String?,
      participantId: row['participant_id'] as String,
      cents: row['amount_cents'] as int,
    );
  }

  Map<String, Object?> toRow({String? expenseId}) {
    final resolvedExpenseId = expenseId ?? this.expenseId;

    if (resolvedExpenseId == null || resolvedExpenseId.isEmpty) {
      throw ArgumentError('Informe o ID da despesa.');
    }

    return {
      'expense_id': resolvedExpenseId,
      'participant_id': participantId,
      'amount_cents': cents,
    };
  }

  ExpenseShare copyWith({
    String? expenseId,
    String? participantId,
    int? cents,
  }) {
    return ExpenseShare(
      expenseId: expenseId ?? this.expenseId,
      participantId: participantId ?? this.participantId,
      cents: cents ?? this.cents,
    );
  }
}