import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

class ExpenseRepository {
  ExpenseRepository(this._database, {this._uuid = const Uuid()});

  final AppDatabase _database;
  final Uuid _uuid;

  /// Writes the expense, its shares and its sync event in one local transaction.
  /// The caller supplies integer cents and an exact base revision (0 for create).
  Future<void> deleteExpense({
    required String groupId,
    required String expenseId,
    required int baseRevision,
    required String actorUid,
    bool queueSync = true,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final operationId = _uuid.v4();
    final db = await _database.database;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        columns: ['revision'],
        where: 'id = ? AND group_id = ? AND deleted_at IS NULL',
        whereArgs: [expenseId, groupId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('A despesa não existe mais.');
      final revision = rows.single['revision']! as int;
      if (revision != baseRevision) {
        throw StateError('A despesa foi alterada em outra operação.');
      }
      await txn.update(
        'expenses',
        {'deleted_at': now, 'revision': revision + 1, 'updated_at': now},
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      if (queueSync) {
        await txn.insert('sync_outbox', {
          'operation_id': operationId,
          'entity_type': 'expense',
          'entity_id': expenseId,
          'group_id': groupId,
          'operation': 'delete',
          'payload': jsonEncode({
            'id': expenseId,
            'groupId': groupId,
            'updatedBy': actorUid,
          }),
          'base_revision': baseRevision,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
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
    final db = await _database.database;
    final now = DateTime.now().millisecondsSinceEpoch;
    await db.transaction((txn) async {
      final rows = await txn.query(
        'expenses',
        where: 'id = ? AND group_id = ? AND deleted_at IS NULL',
        whereArgs: [expenseId, groupId],
        limit: 1,
      );
      if (rows.isEmpty) throw StateError('A despesa não existe mais.');
      final expense = rows.single;
      final revision = expense['revision']! as int;
      if (revision != baseRevision) {
        throw StateError('A despesa foi alterada em outra operação.');
      }
      final normalizedDescription = description.trim();
      if (normalizedDescription.isEmpty) {
        throw ArgumentError('Informe a descrição da despesa.');
      }
      await txn.update(
        'expenses',
        {
          'description': normalizedDescription,
          'category': category,
          'occurred_at': occurredAt,
          'notes': notes.trim(),
          'revision': revision + 1,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [expenseId],
      );
      if (!queueSync) return;

      final shareRows = await txn.query(
        'expense_shares',
        where: 'expense_id = ?',
        whereArgs: [expenseId],
      );
      final payload = <String, Object?>{
        'id': expenseId,
        'groupId': groupId,
        'description': normalizedDescription,
        'amountCents': expense['amount_cents'],
        'originalAmountCents': expense['original_amount_cents'],
        'currency': expense['currency'],
        'exchangeRate': expense['exchange_rate'],
        'payerId': expense['payer_id'],
        'category': category,
        'divisionMode': expense['division_mode'],
        'occurredAt': occurredAt,
        'notes': notes.trim(),
        'receiptLocalPath': expense['receipt_local_path'],
        'shares': {
          for (final share in shareRows)
            share['participant_id']! as String: share['amount_cents']! as int,
        },
        'createdBy': expense['created_by'],
        'updatedBy': actorUid,
      };
      await txn.insert('sync_outbox', {
        'operation_id': _uuid.v4(),
        'entity_type': 'expense',
        'entity_id': expenseId,
        'group_id': groupId,
        'operation': 'update',
        'payload': jsonEncode(payload),
        'base_revision': revision,
        'created_at': now,
        'status': 'pending',
      });
    });
  }

  Future<String> saveExpense({
    required String groupId,
    required Map<String, Object?> fields,
    required Map<String, int> sharesCents,
    required int baseRevision,
    required String actorUid,
    bool queueSync = true,
    String? expenseId,
  }) async {
    final total = fields['amount_cents'];
    if (total is! int || total < 0) {
      throw ArgumentError('O valor da despesa deve estar em centavos.');
    }
    if (sharesCents.values.any((value) => value < 0) ||
        sharesCents.values.fold<int>(0, (a, b) => a + b) != total) {
      throw ArgumentError('As parcelas devem somar o valor da despesa.');
    }
    if (sharesCents.isEmpty) {
      throw ArgumentError('A despesa precisa ser dividida entre participantes.');
    }

    final id = expenseId ?? _uuid.v4();
    final operationId = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = await _database.database;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'expenses',
        columns: ['revision'],
        where: 'id = ? AND group_id = ?',
        whereArgs: [id, groupId],
        limit: 1,
      );
      final currentRevision =
          existing.isEmpty ? 0 : existing.single['revision']! as int;
      if (currentRevision != baseRevision) {
        throw StateError('A despesa local foi alterada em outra operação.');
      }

      final row = <String, Object?>{
        ...fields,
        'created_by': fields['created_by'] ?? actorUid,
        'id': id,
        'group_id': groupId,
        'revision': currentRevision + 1,
        'updated_at': now,
        'deleted_at': null,
      };
      await txn.insert('expenses', row, conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.delete('expense_shares',
          where: 'expense_id = ?', whereArgs: [id]);
      for (final share in sharesCents.entries) {
        await txn.insert('expense_shares', {
          'expense_id': id,
          'participant_id': share.key,
          'amount_cents': share.value,
        });
      }

      if (queueSync) {
        final remotePayload = <String, Object?>{
          'id': id,
          'groupId': groupId,
          'description': fields['description'],
          'amountCents': total,
          'originalAmountCents': fields['original_amount_cents'],
          'currency': fields['currency'],
          'exchangeRate': fields['exchange_rate'],
          'payerId': fields['payer_id'],
          'category': fields['category'],
          'divisionMode': fields['division_mode'] ?? 'equal',
          'occurredAt': fields['occurred_at'],
          'notes': fields['notes'] ?? '',
          'receiptLocalPath': fields['receipt_local_path'],
          'shares': sharesCents.map((key, value) => MapEntry(key, value)),
          'createdBy': fields['created_by'] ?? actorUid,
          'updatedBy': actorUid,
        };
        await txn.insert('sync_outbox', {
          'operation_id': operationId,
          'entity_type': 'expense',
          'entity_id': id,
          'group_id': groupId,
          'operation': currentRevision == 0 ? 'create' : 'update',
          'payload': jsonEncode(remotePayload),
          'base_revision': baseRevision,
          'created_at': now,
          'status': 'pending',
        });
      }
    });
    return id;
  }
}
