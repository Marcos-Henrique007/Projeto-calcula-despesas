class Participant {
  const Participant({
    required this.id,
    required this.groupId,
    required this.name,
    required this.status,
    required this.joinedAt,
    this.email,
    this.uid,
  });

  final String id;
  final String groupId;
  final String name;
  final String? email;
  final String? uid;
  final String status;
  final DateTime joinedAt;

  bool get isActive => status == 'active';

  factory Participant.fromRow(Map<String, Object?> row) {
    return Participant(
      id: row['id'] as String,
      groupId: row['group_id'] as String,
      name: row['name'] as String,
      email: row['email'] as String?,
      uid: row['uid'] as String?,
      status: row['status'] as String? ?? 'active',
      joinedAt: DateTime.fromMillisecondsSinceEpoch(
        row['joined_at'] as int,
      ),
    );
  }

  Map<String, Object?> toRow() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'email': email,
      'uid': uid,
      'status': status,
      'joined_at': joinedAt.millisecondsSinceEpoch,
    };
  }

  Participant copyWith({
    String? name,
    String? email,
    String? uid,
    String? status,
  }) {
    return Participant(
      id: id,
      groupId: groupId,
      name: name ?? this.name,
      email: email ?? this.email,
      uid: uid ?? this.uid,
      status: status ?? this.status,
      joinedAt: joinedAt,
    );
  }
}