import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

class SyncOperation {
  const SyncOperation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.groupId,
    required this.operation,
    required this.payload,
    required this.baseRevision,
  });

  final String id;
  final String entityType;
  final String entityId;
  final String? groupId;
  final String operation;
  final Map<String, Object?> payload;
  final int baseRevision;

  factory SyncOperation.fromRow(Map<String, Object?> row) => SyncOperation(
        id: row['operation_id']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        groupId: row['group_id'] as String?,
        operation: row['operation']! as String,
        payload: Map<String, Object?>.from(
          jsonDecode(row['payload']! as String) as Map,
        ),
        baseRevision: row['base_revision']! as int,
      );
}

class SyncConflict {
  const SyncConflict({
    required this.operationId,
    required this.entityType,
    required this.entityId,
    required this.localPayload,
    required this.remotePayload,
    required this.detectedAt,
  });

  final String operationId;
  final String entityType;
  final String entityId;
  final Map<String, Object?> localPayload;
  final Map<String, Object?> remotePayload;
  final int detectedAt;

  factory SyncConflict.fromRow(Map<String, Object?> row) => SyncConflict(
        operationId: row['operation_id']! as String,
        entityType: row['entity_type']! as String,
        entityId: row['entity_id']! as String,
        localPayload: Map<String, Object?>.from(
          jsonDecode(row['local_payload']! as String) as Map,
        ),
        remotePayload: Map<String, Object?>.from(
          jsonDecode(row['remote_payload']! as String) as Map,
        ),
        detectedAt: row['detected_at']! as int,
      );
}

class SyncOutboxRepository {
  SyncOutboxRepository(this._database, {this._uuid = const Uuid()});

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> enqueue({
    required String entityType,
    required String entityId,
    required String? groupId,
    required String operation,
    required Map<String, Object?> payload,
    required int baseRevision,
  }) async {
    final id = _uuid.v4();
    final db = await _database.database;
    await db.insert(
      'sync_outbox',
      {
        'operation_id': id,
        'entity_type': entityType,
        'entity_id': entityId,
        'group_id': groupId,
        'operation': operation,
        'payload': jsonEncode(payload),
        'base_revision': baseRevision,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'status': 'pending',
      },
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    return id;
  }

  Future<List<SyncOperation>> pending({int limit = 50}) async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_outbox',
      where: "status = 'pending'",
      orderBy: 'created_at ASC, rowid ASC',
      limit: limit,
    );
    return rows.map(SyncOperation.fromRow).toList(growable: false);
  }

  Future<void> markSynced(
    SyncOperation operation, {
    String? remoteReceiptPath,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.update(
        'sync_outbox',
        {'status': 'synced', 'last_error': null},
        where: 'operation_id = ?',
        whereArgs: [operation.id],
      );
      if (remoteReceiptPath != null && operation.entityType == 'expense') {
        await txn.update(
          'expenses',
          {'receipt_remote_path': remoteReceiptPath},
          where: 'id = ?',
          whereArgs: [operation.entityId],
        );
      }
    });
  }

  Future<void> markFailed(String operationId, Object error) async {
    final db = await _database.database;
    await db.update(
      'sync_outbox',
      {'status': 'pending', 'last_error': error.toString()},
      where: 'operation_id = ?',
      whereArgs: [operationId],
    );
  }

  Future<List<SyncConflict>> conflicts() async {
    final db = await _database.database;
    final rows = await db.query(
      'sync_conflicts',
      where: 'resolution IS NULL',
      orderBy: 'detected_at DESC',
    );
    return rows.map(SyncConflict.fromRow).toList(growable: false);
  }

  Future<void> resolveWithLocalVersion(String operationId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'sync_conflicts',
        where: 'operation_id = ? AND resolution IS NULL',
        whereArgs: [operationId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('O conflito já foi resolvido.');
      final conflict = rows.single;
      final remotePayload = Map<String, Object?>.from(
        jsonDecode(conflict['remote_payload']! as String) as Map,
      );
      final remoteRevision = (remotePayload['revision'] as num?)?.toInt() ?? 0;
      final operationRows = await txn.query(
        'sync_outbox',
        columns: ['operation'],
        where: 'operation_id = ?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (operationRows.isEmpty) throw StateError('A operação local não existe mais.');
      final priorOperation = operationRows.single['operation']! as String;
      await txn.update(
        'sync_outbox',
        {
          'base_revision': remoteRevision,
          'operation': priorOperation == 'create' && remoteRevision > 0
              ? 'update'
              : remoteRevision == 0 && priorOperation == 'update'
                  ? 'create'
                  : priorOperation,
          'status': 'pending',
          'last_error': null,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      await txn.update(
        'sync_conflicts',
        {
          'resolution': 'local',
          'resolved_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
    });
  }

  Future<void> resolveWithRemoteVersion(String operationId) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      final conflictRows = await txn.query(
        'sync_conflicts',
        where: 'operation_id = ? AND resolution IS NULL',
        whereArgs: [operationId],
        limit: 1,
      );
      if (conflictRows.isEmpty) throw StateError('O conflito já foi resolvido.');
      final conflict = conflictRows.single;
      final operationRows = await txn.query(
        'sync_outbox',
        where: 'operation_id = ?',
        whereArgs: [operationId],
        limit: 1,
      );
      if (operationRows.isEmpty) throw StateError('A operação local não existe mais.');
      final operation = operationRows.single;
      final remote = Map<String, Object?>.from(
        jsonDecode(conflict['remote_payload']! as String) as Map,
      );
      final groupId = operation['group_id'] as String?;
      if (groupId == null) throw StateError('O conflito não está associado a um grupo.');
      await _applyRemoteVersion(
        txn,
        entityType: conflict['entity_type']! as String,
        entityId: conflict['entity_id']! as String,
        groupId: groupId,
        remote: remote,
      );
      await txn.update(
        'sync_outbox',
        {'status': 'resolved_remote', 'last_error': null},
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
      await txn.update(
        'sync_conflicts',
        {
          'resolution': 'remote',
          'resolved_at': DateTime.now().millisecondsSinceEpoch,
        },
        where: 'operation_id = ?',
        whereArgs: [operationId],
      );
    });
  }

  Future<void> _applyRemoteVersion(
    Transaction txn, {
    required String entityType,
    required String entityId,
    required String groupId,
    required Map<String, Object?> remote,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final revision = (remote['revision'] as num?)?.toInt() ?? 0;
    if (remote.isEmpty) {
      if (entityType == 'group') {
        await txn.update(
          'groups_local',
          {'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [entityId],
        );
      } else if (entityType == 'expense') {
        await txn.update(
          'expenses',
          {'deleted_at': now, 'updated_at': now},
          where: 'id = ?',
          whereArgs: [entityId],
        );
      } else if (entityType == 'participant') {
        await txn.update(
          'participants',
          {'status': 'inactive'},
          where: 'id = ?',
          whereArgs: [entityId],
        );
      }
      return;
    }

    switch (entityType) {
      case 'group':
        await txn.update(
          'groups_local',
          {
            'name': remote['name'] ?? '',
            'destination': remote['destination'] ?? '',
            'description': remote['description'] ?? '',
            'currency': remote['currency'] ?? 'BRL',
            'types': jsonEncode(remote['types'] ?? const <String>[]),
            'invite_code': remote['inviteCode'] ?? '',
            'start_date': remote['startDate'],
            'end_date': remote['endDate'],
            'created_by': remote['createdBy'] ?? remote['ownerUid'] ?? '',
            'revision': revision,
            'updated_at': _millis(remote['updatedAt'], now),
            'deleted_at': remote['deletedAt'] == null
                ? null
                : _millis(remote['deletedAt'], now),
          },
          where: 'id = ?',
          whereArgs: [entityId],
        );
        return;
      case 'expense':
        await txn.insert(
          'expenses',
          {
            'id': entityId,
            'group_id': groupId,
            'description': remote['description'] ?? '',
            'amount_cents': remote['amountCents'] ?? 0,
            'original_amount_cents':
                remote['originalAmountCents'] ?? remote['amountCents'] ?? 0,
            'currency': remote['currency'] ?? 'BRL',
            'exchange_rate': remote['exchangeRate']?.toString() ?? '1',
            'payer_id': remote['payerId'] ?? '',
            'category': remote['category'] ?? 'Outros',
            'division_mode': remote['divisionMode'] ?? 'equal',
            'occurred_at': _millis(remote['occurredAt'], now),
            'notes': remote['notes'] ?? '',
            'created_by': remote['createdBy'] ?? '',
            'receipt_remote_path': remote['receiptRemotePath'],
            'revision': revision,
            'updated_at': _millis(remote['updatedAt'], now),
            'deleted_at': remote['deletedAt'] == null
                ? null
                : _millis(remote['deletedAt'], now),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await txn.delete(
          'expense_shares',
          where: 'expense_id = ?',
          whereArgs: [entityId],
        );
        final shares = remote['shares'];
        if (shares is Map) {
          for (final entry in shares.entries) {
            final amount = entry.value;
            if (amount is num) {
              await txn.insert('expense_shares', {
                'expense_id': entityId,
                'participant_id': entry.key.toString(),
                'amount_cents': amount.toInt(),
              });
            }
          }
        }
        return;
      case 'participant':
        await txn.insert(
          'participants',
          {
            'id': entityId,
            'group_id': groupId,
            'name': remote['name'] ?? 'Participante',
            'email': remote['email'],
            'uid': remote['uid'],
            'status': remote['status'] ?? 'active',
            'joined_at': _millis(remote['joinedAt'], now),
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      case 'settlement':
        await txn.insert(
          'settlements',
          {
            'id': entityId,
            'group_id': groupId,
            'from_participant_id': remote['fromParticipantId'] ?? '',
            'to_participant_id': remote['toParticipantId'] ?? '',
            'amount_cents': remote['amountCents'] ?? 0,
            'status': remote['status'] ?? 'settled',
            'created_at': _millis(remote['createdAt'], now),
            'settled_at': _millis(remote['settledAt'], now),
            'revision': revision,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        return;
      default:
        throw StateError('Tipo de conflito não suportado: $entityType');
    }
  }

  Object? _jsonSafe(Object? value) {
    if (value is firestore.Timestamp) return value.millisecondsSinceEpoch;
    if (value is DateTime) return value.millisecondsSinceEpoch;
    if (value is Map) {
      return {
        for (final entry in value.entries)
          entry.key.toString(): _jsonSafe(entry.value),
      };
    }
    if (value is Iterable) {
      return value.map(_jsonSafe).toList(growable: false);
    }
    return value;
  }

  int _millis(Object? value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return fallback;
  }

  Future<void> markConflict({
    required SyncOperation operation,
    required Map<String, Object?> remotePayload,
  }) async {
    final db = await _database.database;
    await db.transaction((txn) async {
      await txn.insert(
        'sync_conflicts',
        {
          'operation_id': operation.id,
          'entity_type': operation.entityType,
          'entity_id': operation.entityId,
          'local_payload': jsonEncode(operation.payload),
          'remote_payload': jsonEncode(_jsonSafe(remotePayload)),
          'detected_at': DateTime.now().millisecondsSinceEpoch,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.update(
        'sync_outbox',
        {'status': 'conflict'},
        where: 'operation_id = ?',
        whereArgs: [operation.id],
      );
    });
  }
}
