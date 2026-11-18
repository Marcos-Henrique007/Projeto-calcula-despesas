enum SettlementStatus {
  pending,
  settled,
}

class Settlement {
  const Settlement({
    required this.id,
    required this.groupId,
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.amountCents,
    required this.status,
    required this.createdAt,
    required this.revision,
    this.settledAt,
  });

  final String id;
  final String groupId;

  final String fromParticipantId;
  final String toParticipantId;

  final int amountCents;

  final SettlementStatus status;

  final DateTime createdAt;
  final DateTime? settledAt;

  final int revision;

  bool get isSettled => status == SettlementStatus.settled;

  double get amount => amountCents / 100;

  factory Settlement.fromRow(Map<String, Object?> row) {
    final statusName = row['status'] as String? ?? 'pending';

    return Settlement(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      fromParticipantId: row['from_participant_id'] as String,
      toParticipantId: row['to_participant_id'] as String,
      amountCents: row['amount_cents'] as int,
      status: SettlementStatus.values.firstWhere(
            (status) => status.name == statusName,
        orElse: () => SettlementStatus.pending,
      ),
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        row['created_at'] as int,
      ),
      settledAt: row['settled_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(
        row['settled_at'] as int,
      ),
      revision: row['revision'] as int? ?? 1,
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'group_id': groupId,
      'from_participant_id': fromParticipantId,
      'to_participant_id': toParticipantId,
      'amount_cents': amountCents,
      'status': status.name,
      'created_at': createdAt.millisecondsSinceEpoch,
      'settled_at': settledAt?.millisecondsSinceEpoch,
      'revision': revision,
    };
  }

  Settlement copyWith({
    SettlementStatus? status,
    DateTime? settledAt,
    int? revision,
  }) {
    return Settlement(
      id: id,
      groupId: groupId,
      fromParticipantId: fromParticipantId,
      toParticipantId: toParticipantId,
      amountCents: amountCents,
      status: status ?? this.status,
      createdAt: createdAt,
      settledAt: settledAt ?? this.settledAt,
      revision: revision ?? this.revision,
    );
  }
}