import 'dart:convert';

class TravelGroup {
  const TravelGroup({
    required this.id,
    required this.name,
    required this.destination,
    required this.description,
    required this.currency,
    required this.createdBy,
    this.types = const [],
    this.inviteCode = '',
    this.startDate,
    this.endDate,
    this.revision = 1,
  });

  final String id;
  final String name;
  final String destination;
  final String description;
  final String currency;
  final String createdBy;
  final List<String> types;
  final String inviteCode;
  final DateTime? startDate;
  final DateTime? endDate;
  final int revision;

  bool get isLocalOnly => createdBy == 'guest-local';

  factory TravelGroup.fromRow(Map<String, Object?> row) => TravelGroup(
        id: row['id']! as String,
        name: row['name']! as String,
        destination: row['destination']! as String,
        description: row['description']! as String,
        currency: row['currency']! as String,
        createdBy: row['created_by']! as String,
        types: (jsonDecode(row['types'] as String? ?? '[]') as List<dynamic>)
            .cast<String>(),
        inviteCode: row['invite_code'] as String? ?? '',
        startDate: row['start_date'] == null
            ? null
            : DateTime.parse(row['start_date']! as String),
        endDate: row['end_date'] == null
            ? null
            : DateTime.parse(row['end_date']! as String),
        revision: row['revision'] as int? ?? 1,
      );
}
