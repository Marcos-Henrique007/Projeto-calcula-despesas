
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';
import '../../domain/models/travel_group.dart';

class GroupRepository {
  GroupRepository(
      this._database, {
        Uuid uuid = const Uuid(),
      }) : _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;

  Future<TravelGroup> createGroup({
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
    required String actorUid,
    required String creatorName,
    String? creatorEmail,
    bool syncEnabled = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome do grupo.');
    }

    if (actorUid.trim().isEmpty) {
      throw ArgumentError('Usuário inválido.');
    }

    final id = _uuid.v4();
    final inviteCode = _uuid.v4()
        .replaceAll('-', '')
        .substring(0, 12)
        .toUpperCase();

    final now = DateTime.now().millisecondsSinceEpoch;

    final group = TravelGroup(
      id: id,
      name: name.trim(),
      destination: destination.trim(),
      description: description.trim(),
      currency: currency,
      createdBy: actorUid,
      types: types,
      inviteCode: inviteCode,
    );

    final db = await _database.database;

    await db.transaction((txn) async {
      await txn.insert('groups_local', {
        'id': id,
        'name': group.name,
        'destination': group.destination,
        'description': group.description,
        'currency': group.currency,
        'types': jsonEncode(group.types),
        'invite_code': inviteCode,
        'start_date': null,
        'end_date': null,
        'created_by': actorUid,
        'revision': 1,
        'updated_at': now,
        'deleted_at': null,
      });

      final participantId = _uuid.v4();

      await txn.insert('participants', {
        'id': participantId,
        'group_id': id,
        'name': creatorName.trim(),
        'email': creatorEmail,
        'uid': actorUid,
        'status': 'active',
        'joined_at': now,
      });

      if (syncEnabled) {
        await _insertOutbox(
          txn,
          entityType: 'group',
          entityId: id,
          groupId: id,
          operation: 'create',
          baseRevision: 0,
          payload: {
            'name': group.name,
            'destination': group.destination,
            'description': group.description,
            'currency': group.currency,
            'types': group.types,
            'inviteCode': inviteCode,
            'createdBy': actorUid,
            'ownerUid': actorUid,
          },
        );

        await _insertOutbox(
          txn,
          entityType: 'participant',
          entityId: participantId,
          groupId: id,
          operation: 'create',
          baseRevision: 0,
          payload: {
            'name': creatorName.trim(),
            'email': creatorEmail,
            'uid': actorUid,
            'status': 'active',
            'joinedAt': now,
          },
        );
      }
    });

    return group;
  }

  Future<List<TravelGroup>> groupsFor(String actorUid) async {
    final db = await _database.database;

    final rows = await db.query(
      'groups_local',
      where: 'deleted_at IS NULL',
      orderBy: 'updated_at DESC',
    );

    final groups = <TravelGroup>[];

    for (final row in rows) {
      final groupId = row['id']! as String;

      final isOwner = row['created_by'] == actorUid;

      final participantRows = await db.query(
        'participants',
        columns: ['id'],
        where: 'group_id = ? AND uid = ? AND status = ?',
        whereArgs: [groupId, actorUid, 'active'],
        limit: 1,
      );

      if (isOwner || participantRows.isNotEmpty) {
        groups.add(TravelGroup.fromRow(row));
      }
    }

    return List.unmodifiable(groups);
  }

  Future<void> updateGroup({
    required TravelGroup group,
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
    required String actorUid,
    bool syncEnabled = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome do grupo.');
    }

    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    final newRevision = group.revision + 1;

    await db.transaction((txn) async {
      final updated = await txn.update(
        'groups_local',
        {
          'name': name.trim(),
          'destination': destination.trim(),
          'description': description.trim(),
          'currency': currency,
          'types': jsonEncode(types),
          'revision': newRevision,
          'updated_at': now,
        },
        where: 'id = ? AND revision = ? AND deleted_at IS NULL',
        whereArgs: [group.id, group.revision],
      );

      if (updated == 0) {
        throw StateError(
          'O grupo foi alterado por outra operação. Atualize os dados.',
        );
      }

      if (syncEnabled) {
        await _insertOutbox(
          txn,
          entityType: 'group',
          entityId: group.id,
          groupId: group.id,
          operation: 'update',
          baseRevision: group.revision,
          payload: {
            'name': name.trim(),
            'destination': destination.trim(),
            'description': description.trim(),
            'currency': currency,
            'types': types,
          },
        );
      }
    });
  }

  Future<void> deleteGroup({
    required String groupId,
    required String actorUid,
    bool syncEnabled = false,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'groups_local',
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Grupo não encontrado.');
      }

      final group = rows.single;
      final revision = group['revision']! as int;

      await txn.update(
        'groups_local',
        {
          'deleted_at': now,
          'updated_at': now,
          'revision': revision + 1,
        },
        where: 'id = ?',
        whereArgs: [groupId],
      );

      if (syncEnabled) {
        await _insertOutbox(
          txn,
          entityType: 'group',
          entityId: groupId,
          groupId: groupId,
          operation: 'delete',
          baseRevision: revision,
          payload: {},
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> participants(
      String groupId,
      ) async {
    final db = await _database.database;

    return db.query(
      'participants',
      where: 'group_id = ? AND status = ?',
      whereArgs: [groupId, 'active'],
      orderBy: 'joined_at ASC',
    );
  }

  Future<void> addParticipant({
    required String groupId,
    required String name,
    String? email,
    required String actorUid,
    bool syncEnabled = false,
  }) async {
    if (name.trim().isEmpty) {
      throw ArgumentError('Informe o nome do participante.');
    }

    final db = await _database.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final group = await txn.query(
        'groups_local',
        columns: ['id'],
        where: 'id = ? AND deleted_at IS NULL',
        whereArgs: [groupId],
        limit: 1,
      );

      if (group.isEmpty) {
        throw StateError('Grupo não encontrado.');
      }

      await txn.insert('participants', {
        'id': id,
        'group_id': groupId,
        'name': name.trim(),
        'email': email,
        'uid': null,
        'status': 'active',
        'joined_at': now,
      });

      if (syncEnabled) {
        await _insertOutbox(
          txn,
          entityType: 'participant',
          entityId: id,
          groupId: groupId,
          operation: 'create',
          baseRevision: 0,
          payload: {
            'name': name.trim(),
            'email': email,
            'uid': null,
            'status': 'active',
            'joinedAt': now,
          },
        );
      }
    });
  }

  Future<List<Map<String, Object?>>> expenses(
      String groupId,
      ) async {
    final db = await _database.database;

    return db.query(
      'expenses',
      where: 'group_id = ? AND deleted_at IS NULL',
      whereArgs: [groupId],
      orderBy: 'occurred_at DESC',
    );
  }

  Future<List<Map<String, Object?>>> expenseLedger(
      String groupId,
      ) async {
    final db = await _database.database;

    return db.rawQuery('''
      SELECT
        e.id AS expense_id,
        e.payer_id,
        e.amount_cents,
        s.participant_id,
        s.amount_cents AS share_cents
      FROM expenses e
      LEFT JOIN expense_shares s
        ON s.expense_id = e.id
      WHERE e.group_id = ?
        AND e.deleted_at IS NULL
      ORDER BY e.occurred_at DESC
    ''', [groupId]);
  }

  Future<List<Map<String, Object?>>> settlements(
      String groupId,
      ) async {
    final db = await _database.database;

    return db.query(
      'settlements',
      where: 'group_id = ?',
      whereArgs: [groupId],
      orderBy: 'created_at DESC',
    );
  }

  Future<int> expenseCount(String groupId) async {
    final db = await _database.database;

    final result = await db.rawQuery(
      '''
      SELECT COUNT(*) AS total
      FROM expenses
      WHERE group_id = ?
        AND deleted_at IS NULL
      ''',
      [groupId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> expenseTotalCents(String groupId) async {
    final db = await _database.database;

    final result = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(amount_cents), 0) AS total
      FROM expenses
      WHERE group_id = ?
        AND deleted_at IS NULL
      ''',
      [groupId],
    );

    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> recordSettlement({
    required String groupId,
    required String fromParticipantId,
    required String toParticipantId,
    required int amountCents,
    required String actorUid,
    bool syncEnabled = false,
  }) async {
    if (amountCents <= 0) {
      throw ArgumentError('O valor do acerto deve ser positivo.');
    }

    if (fromParticipantId == toParticipantId) {
      throw ArgumentError('Os participantes do acerto devem ser diferentes.');
    }

    final db = await _database.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

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
        await _insertOutbox(
          txn,
          entityType: 'settlement',
          entityId: id,
          groupId: groupId,
          operation: 'create',
          baseRevision: 0,
          payload: {
            'fromParticipantId': fromParticipantId,
            'toParticipantId': toParticipantId,
            'amountCents': amountCents,
            'status': 'settled',
            'createdAt': now,
            'settledAt': now,
            'revision': 1,
          },
        );
      }
    });
  }

  Future<void> _insertOutbox(
      Transaction txn, {
        required String entityType,
        required String entityId,
        required String groupId,
        required String operation,
        required int baseRevision,
        required Map<String, Object?> payload,
      }) async {
    await txn.insert('sync_outbox', {
      'operation_id': _uuid.v4(),
      'entity_type': entityType,
      'entity_id': entityId,
      'group_id': groupId,
      'operation': operation,
      'payload': jsonEncode(payload),
      'base_revision': baseRevision,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'status': 'pending',
      'last_error': null,
    });
  }
}
