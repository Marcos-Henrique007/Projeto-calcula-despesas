enum SettlementStatus {
  pending,
  settled,
}

class Settlement {
  final String id;
  final String from;
  final String to;
  final double amount;
  final SettlementStatus status;

  const Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.status,
  });

  Settlement copyWith({
    SettlementStatus? status,
  }) {
    return Settlement(
      id: id,
      from: from,
      to: to,
      amount: amount,
      status: status ?? this.status,
    );
  }
}