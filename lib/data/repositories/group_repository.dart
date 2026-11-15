import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/models/travel_group.dart';
import '../local/database/app_database.dart';

class GroupRepository {
  GroupRepository(this._database, {this._uuid = const Uuid()});

  final AppDatabase _database;
  final Uuid _uuid;

  Future<List<TravelGroup>> groupsFor(String uid) async {
    final db = await _database.database;
    final rows = await db.rawQuery('''
      SELECT DISTINCT g.* FROM groups_local g
      LEFT JOIN participants p ON p.group_id = g.id
      WHERE g.deleted_at IS NULL
        AND (g.created_by = ? OR g.created_by = 'guest-local' OR p.uid = ?)
      ORDER BY g.updated_at DESC
    ''', [uid, uid]);
    return rows.map(TravelGroup.fromRow).toList(growable: false);
  }

  Future<TravelGroup> createGroup({
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
    required String actorUid,
    required String creatorName,
    String? creatorEmail,
    required bool syncEnabled,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('Informe o nome do grupo.');
    final id = _uuid.v4();
    final inviteCode = _uuid.v4().replaceAll('-', '').substring(0, 12).toUpperCase();
    final participantId = _uuid.v4();
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch;
    final participantName = creatorName.trim().isEmpty ? 'Visitante' : creatorName.trim();
    final participantEmail = creatorEmail?.trim();
    final participantUid = syncEnabled ? actorUid : null;
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('groups_local', {
        'id': id,
        'name': normalizedName,
        'destination': destination.trim(),
        'description': description.trim(),
        'currency': currency,
        'types': jsonEncode(types),
        'invite_code': inviteCode,
        'created_by': actorUid,
        'revision': 1,
        'updated_at': timestamp,
      });
      await txn.insert('participants', {
        'id': participantId,
        'group_id': id,
        'name': participantName,
        'email': participantEmail?.isEmpty == true ? null : participantEmail,
        'uid': participantUid,
        'status': 'active',
        'joined_at': timestamp,
      });
      if (syncEnabled) {
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'group',
          'entity_id': id,
          'group_id': id,
          'operation': 'create',
          'payload': jsonEncode({
            'id': id,
            'name': normalizedName,
            'destination': destination.trim(),
            'description': description.trim(),
            'currency': currency,
            'types': types,
            'inviteCode': inviteCode,
            'ownerUid': actorUid,
            'createdBy': actorUid,
            'updatedBy': actorUid,
          }),
          'base_revision': 0,
          'created_at': timestamp,
          'status': 'pending',
        });
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'participant',
          'entity_id': participantId,
          'group_id': id,
          'operation': 'create',
          'payload': jsonEncode({
            'id': participantId,
            'groupId': id,
            'name': participantName,
            'email': participantEmail?.isEmpty == true ? null : participantEmail,
            'uid': actorUid,
            'status': 'active',
            'createdBy': actorUid,
            'updatedBy': actorUid,
          }),
          'base_revision': 0,
          'created_at': timestamp,
          'status': 'pending',
        });
      }
    });
    return TravelGroup(
      id: id,
      name: normalizedName,
      destination: destination.trim(),
      description: description.trim(),
      currency: currency,
      createdBy: actorUid,
      types: List.unmodifiable(types),
      inviteCode: inviteCode,
    );
  }

  Future<void> updateGroup({
    required TravelGroup group,
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
    required String actorUid,
    required bool syncEnabled,
  }) async {
    final normalizedName = name.trim();
    if (normalizedName.isEmpty) throw ArgumentError('Informe o nome do grupo.');
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'groups_local',
        columns: ['revision', 'created_by'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [group.id],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('O grupo não existe mais.');
      if (rows.single['created_by'] != actorUid) {
        throw StateError('Somente quem criou o grupo pode editá-lo.');
      }
      final revision = rows.single['revision']! as int;
      if (revision != group.revision) {
        throw StateError('O grupo foi alterado em outra operação.');
      }
      final newRevision = revision + 1;
      await txn.update(
        'groups_local',
        {
          'name': normalizedName,
          'destination': destination.trim(),
          'description': description.trim(),
          'currency': currency,
          'types': jsonEncode(types),
          'start_date': group.startDate?.toIso8601String(),
          'end_date': group.endDate?.toIso8601String(),
          'revision': newRevision,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [group.id],
      );
      if (syncEnabled) {
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'group',
          'entity_id': group.id,
          'group_id': group.id,
          'operation': 'update',
          'payload': jsonEncode({
            'id': group.id,
            'name': normalizedName,
            'destination': destination.trim(),
            'description': description.trim(),
            'currency': currency,
            'types': types,
            'inviteCode': group.inviteCode,
            'ownerUid': actorUid,
            'createdBy': actorUid,
            'updatedBy': actorUid,
            if (group.startDate != null)
              'startDate': group.startDate!.toIso8601String(),
            if (group.endDate != null)
              'endDate': group.endDate!.toIso8601String(),
          }),
          'base_revision': revision,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
  }

  Future<void> deleteGroup({
    required String groupId,
    required String actorUid,
    required bool syncEnabled,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'groups_local',
        columns: ['revision', 'created_by'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
        limit: 1,
      );
      if (rows.isEmpty) return;
      if (rows.single['created_by'] != actorUid) {
        throw StateError('Somente quem criou o grupo pode excluí-lo.');
      }
      final revision = rows.single['revision']! as int;
      await txn.update(
        'groups_local',
        {'deleted_at': now, 'updated_at': now, 'revision': revision + 1},
        where: 'id = ?',
        whereArgs: [groupId],
      );
      if (syncEnabled) {
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'group',
          'entity_id': groupId,
          'group_id': groupId,
          'operation': 'delete',
          'payload': jsonEncode({'updatedBy': actorUid}),
          'base_revision': revision,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> participants(String groupId) async {
    final db = await _database.database;
    return db.query(
      'participants',
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, 'active'],
      orderBy: 'joined_at',
    );
  }

  Future<List<Map<String, Object?>>> expenses(String groupId) async {
    final db = await _database.database;
    return db.query(
      'expenses',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'occurred_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> expenseLedger(String groupId) async {
    final db = await _database.database;
    return db.rawQuery('''
      SELECT e.id AS expense_id, e.payer_id, e.amount_cents,
             s.participant_id, s.amount_cents AS share_cents
      FROM expenses e
      LEFT JOIN expense_shares s ON s.expense_id = e.id
      WHERE e.group_id = ? AND e.deleted_at IS NULL
      ORDER BY e.id
    ''', [groupId]);
  }

  Future<void> addParticipant({
    required String groupId,
    required String name,
    required String actorUid,
    required bool syncEnabled,
    String? email,
  }) async {
    final participantName = name.trim();
    if (participantName.isEmpty) {
      throw ArgumentError('Informe o nome do participante.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('participants', {
        'id': id,
        'group_id': groupId,
        'name': participantName,
        'email': email?.trim().isEmpty == true ? null : email?.trim(),
        'uid': null,
        'status': 'active',
        'joined_at': now,
      });
      if (syncEnabled) {
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'participant',
          'entity_id': id,
          'group_id': groupId,
          'operation': 'create',
          'payload': jsonEncode({
            'id': id,
            'groupId': groupId,
            'name': participantName,
            'email': email?.trim(),
            'uid': null,
            'status': 'active',
            'createdBy': actorUid,
            'updatedBy': actorUid,
          }),
          'base_revision': 0,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
  }

  Future<List<Map<String, Object?>>> settlements(String groupId) async {
    final db = await _database.database;
    return db.query(
      'settlements',
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, 'settled'],
      orderBy: 'settled_at DESC',
    );
  }

  Future<void> recordSettlement({
    required String groupId,
    required String fromParticipantId,
    required String toParticipantId,
    required int amountCents,
    required String actorUid,
    required bool syncEnabled,
  }) async {
    if (amountCents <= 0 || fromParticipantId == toParticipantId) {
      throw ArgumentError('Informe um acerto válido.');
    }
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert('settlements', {
        'id': id,
        'group_id': groupId,
        'from_participant_id': fromParticipantId,
        'to_participant_id': toParticipantId,
        'amount_cents': amountCents,
        'status': 'settled',
        'created_at': now,
        'settled_at': now,
        'revision': 1,
      });
      if (syncEnabled) {
        await txn.insert('sync_outbox', {
          'operation_id': _uuid.v4(),
          'entity_type': 'settlement',
          'entity_id': id,
          'group_id': groupId,
          'operation': 'create',
          'payload': jsonEncode({
            'id': id,
            'groupId': groupId,
            'fromParticipantId': fromParticipantId,
            'toParticipantId': toParticipantId,
            'amountCents': amountCents,
            'status': 'settled',
            'settledAt': now,
            'createdBy': actorUid,
            'updatedBy': actorUid,
          }),
          'base_revision': 0,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
  }

  Future<int> expenseCount(String groupId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM expenses WHERE group_id = ? AND deleted_at IS NULL',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> expenseTotalCents(String groupId) async {
    final db = await _database.database;
    final result = await db.rawQuery(
      'SELECT COALESCE(SUM(amount_cents), 0) AS total FROM expenses '
      'WHERE group_id = ? AND deleted_at IS NULL',
      [groupId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
