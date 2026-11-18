
import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

class ExpenseRepository {
  ExpenseRepository(
      this._database, {
        Uuid uuid = const Uuid(),
      }) : _uuid = uuid;

  final AppDatabase _database;
  final Uuid _uuid;

  Future<String> saveExpense({
    required String groupId,
    required String actorUid,
    required int baseRevision,
    required Map<String, Object?> fields,
    required Map<String, int> sharesCents,
    bool queueSync = true,
  }) async {
    final description = fields['description'] as String? ?? '';
    final amountCents = fields['amount_cents'] as int? ?? 0;

    if (description.trim().isEmpty) {
      throw ArgumentError('Informe a descrição da despesa.');
    }

    if (amountCents <= 0) {
      throw ArgumentError('O valor da despesa deve ser positivo.');
    }

    if (sharesCents.isEmpty) {
      throw ArgumentError('Informe ao menos uma parcela.');
    }

    if (sharesCents.values.any((value) => value < 0)) {
      throw ArgumentError('As parcelas não podem ser negativas.');
    }

    final totalShares = sharesCents.values.fold<int>(
      0,
          (total, value) => total + value,
    );

    if (totalShares != amountCents) {
      throw ArgumentError(
        'A soma das parcelas deve ser igual ao valor da despesa.',
      );
    }

    final db = await _database.database;
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    final expenseFields = <String, Object?>{
      ...fields,
      'original_amount_cents':
      fields['original_amount_cents'] ?? amountCents,
      'created_by': fields['created_by'] ?? actorUid,
      'division_mode': fields['division_mode'] ?? 'equal',
      'revision': 1,
      'updated_at': now,
      'deleted_at': null,
    };

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

      await txn.insert('expenses', {
        'id': id,
        'group_id': groupId,
        ...expenseFields,
      });

      for (final entry in sharesCents.entries) {
        await txn.insert('expense_shares', {
          'expense_id': id,
          'participant_id': entry.key,
          'amount_cents': entry.value,
        });
      }

      if (queueSync) {
        await _insertOutbox(
          txn,
          entityType: 'expense',
          entityId: id,
          groupId: groupId,
          operation: 'create',
          baseRevision: baseRevision,
          payload: {
            'description': description.trim(),
            'amountCents': amountCents,
            'originalAmountCents':
            expenseFields['original_amount_cents'],
            'currency': fields['currency'],
            'exchangeRate': fields['exchange_rate'],
            'payerId': fields['payer_id'],
            'category': fields['category'],
            'divisionMode': expenseFields['division_mode'],
            'occurredAt': fields['occurred_at'],
            'notes': fields['notes'] ?? '',
            'createdBy': expenseFields['created_by'],
            'receiptLocalPath': fields['receipt_local_path'],
            'shares': sharesCents,
          },
        );
      }
    });

    return id;
  }

  Future<void> updateExpenseDetails({
    required String groupId,
    required String expenseId,
    required int baseRevision,
    required String actorUid,
    required String description,
    required String category,
    required int occurredAt,
    required String notes,
    bool queueSync = true,
  }) async {
    if (description.trim().isEmpty) {
      throw ArgumentError('Informe a descrição da despesa.');
    }

    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        where: 'id = ? AND group_id = ? AND deleted_at IS NULL',
        whereArgs: [expenseId, groupId],
        limit: 1,
      );

      if (rows.isEmpty) {
        throw StateError('Despesa não encontrada.');
      }

      final updated = await txn.update(
        'expenses',
        {
          'description': description.trim(),
          'category': category,
          'occurred_at': occurredAt,
          'notes': notes.trim(),
          'revision': baseRevision + 1,
          'updated_at': now,
        },
        where: 'id = ? AND revision = ? AND deleted_at IS NULL',
        whereArgs: [expenseId, baseRevision],
      );

      if (updated == 0) {
        throw StateError(
          'A despesa foi alterada por outra operação. Atualize os dados.',
        );
      }

      if (queueSync) {
        final shares = await txn.query(
          'expense_shares',
          columns: ['participant_id', 'amount_cents'],
          where: 'expense_id = ?',
          whereArgs: [expenseId],
        );

        await _insertOutbox(
          txn,
          entityType: 'expense',
          entityId: expenseId,
          groupId: groupId,
          operation: 'update',
          baseRevision: baseRevision,
          payload: {
            'description': description.trim(),
            'category': category,
            'occurredAt': occurredAt,
            'notes': notes.trim(),
            'shares': {
              for (final share in shares)
                share['participant_id']! as String:
                share['amount_cents']! as int,
            },
          },
        );
      }
    });
  }

  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
    required int baseRevision,
    required String actorUid,
    bool queueSync = true,
  }) async {
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;

    await db.transaction((txn) async {
      final updated = await txn.update(
        'expenses',
        {
          'deleted_at': now,
          'updated_at': now,
          'revision': baseRevision + 1,
        },
        where: '''
          id = ?
          AND group_id = ?
          AND revision = ?
          AND deleted_at IS NULL
        ''',
        whereArgs: [expenseId, groupId, baseRevision],
      );

      if (updated == 0) {
        throw StateError(
          'A despesa não existe ou foi alterada por outra operação.',
        );
      }

      if (queueSync) {
        await _insertOutbox(
          txn,
          entityType: 'expense',
          entityId: expenseId,
          groupId: groupId,
          operation: 'delete',
          baseRevision: baseRevision,
          payload: {},
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
