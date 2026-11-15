import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_calcula_despesas/data/local/database/app_database.dart';
import 'package:projeto_calcula_despesas/data/repositories/expense_repository.dart';
import 'package:projeto_calcula_despesas/data/repositories/group_repository.dart';
import 'package:projeto_calcula_despesas/data/repositories/sync_outbox_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Database> _openTestDatabase() => databaseFactoryFfi.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE groups_local (
              id TEXT PRIMARY KEY, name TEXT NOT NULL, destination TEXT NOT NULL,
              description TEXT NOT NULL, currency TEXT NOT NULL,
              types TEXT NOT NULL DEFAULT '[]', invite_code TEXT NOT NULL DEFAULT '',
              start_date TEXT, end_date TEXT,
              created_by TEXT NOT NULL, revision INTEGER NOT NULL DEFAULT 1,
              updated_at INTEGER NOT NULL, deleted_at INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE participants (
              id TEXT PRIMARY KEY, group_id TEXT NOT NULL, name TEXT NOT NULL,
              email TEXT, uid TEXT, status TEXT NOT NULL, joined_at INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE settlements (
              id TEXT PRIMARY KEY, group_id TEXT NOT NULL, from_participant_id TEXT NOT NULL,
              to_participant_id TEXT NOT NULL, amount_cents INTEGER NOT NULL, status TEXT NOT NULL,
              created_at INTEGER NOT NULL, settled_at INTEGER, revision INTEGER NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE expenses (
              id TEXT PRIMARY KEY, group_id TEXT NOT NULL, description TEXT NOT NULL,
              amount_cents INTEGER NOT NULL, original_amount_cents INTEGER NOT NULL DEFAULT 0, currency TEXT NOT NULL,
              exchange_rate TEXT NOT NULL, payer_id TEXT NOT NULL, category TEXT NOT NULL, division_mode TEXT NOT NULL DEFAULT 'equal',
              occurred_at INTEGER NOT NULL, notes TEXT NOT NULL,
              created_by TEXT NOT NULL DEFAULT '',
              receipt_local_path TEXT, receipt_remote_path TEXT,
              revision INTEGER NOT NULL, updated_at INTEGER NOT NULL, deleted_at INTEGER
            )
          ''');
          await db.execute('''
            CREATE TABLE expense_shares (
              expense_id TEXT NOT NULL, participant_id TEXT NOT NULL,
              amount_cents INTEGER NOT NULL, PRIMARY KEY(expense_id, participant_id)
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_outbox (
              operation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL, group_id TEXT, operation TEXT NOT NULL,
              payload TEXT NOT NULL, base_revision INTEGER NOT NULL,
              created_at INTEGER NOT NULL, status TEXT NOT NULL, last_error TEXT
            )
          ''');
          await db.execute('''
            CREATE TABLE sync_conflicts (
              operation_id TEXT PRIMARY KEY, entity_type TEXT NOT NULL,
              entity_id TEXT NOT NULL, local_payload TEXT NOT NULL,
              remote_payload TEXT NOT NULL, detected_at INTEGER NOT NULL,
              resolution TEXT, resolved_at INTEGER
            )
          ''');
        },
      ),
    );

void main() {
  late AppDatabase database;

  setUpAll(sqfliteFfiInit);

  setUp(() {
    database = AppDatabase(databaseFactory: _openTestDatabase);
  });

  tearDown(() async {
    await (await database.database).close();
  });

  Future<void> insertGroup(Database db) async {
    await db.insert('groups_local', {
      'id': 'trip',
      'name': 'Viagem',
      'destination': '',
      'description': '',
      'currency': 'BRL',
      'created_by': 'uid',
      'updated_at': 1,
    });
  }

  test('creates the group creator as a participant with an invite code', () async {
    final repository = GroupRepository(database);
    final group = await repository.createGroup(
      name: 'Viagem de teste',
      destination: 'Chile',
      description: '',
      currency: 'BRL',
      types: ['Viagem', 'Evento'],
      actorUid: 'uid',
      creatorName: 'Ana',
      creatorEmail: 'ana@example.com',
      syncEnabled: true,
    );

    final db = await database.database;
    final participants = await repository.participants(group.id);
    expect(participants, hasLength(1));
    expect(participants.single['uid'], 'uid');
    expect(participants.single['name'], 'Ana');
    expect(group.inviteCode, hasLength(12));
    expect((await db.query('sync_outbox')).map((row) => row['entity_type']),
        containsAll(['group', 'participant']));
  });

  test('records a settlement locally and queues it for sync', () async {
    final repository = GroupRepository(database);
    await repository.recordSettlement(
      groupId: 'trip',
      fromParticipantId: 'bruno',
      toParticipantId: 'ana',
      amountCents: 2500,
      actorUid: 'uid',
      syncEnabled: true,
    );

    final db = await database.database;
    final settlements = await repository.settlements('trip');
    expect(settlements, hasLength(1));
    expect(settlements.single['amount_cents'], 2500);
    final outbox = await db.query('sync_outbox');
    expect(outbox.single['entity_type'], 'settlement');
    expect(outbox.single['status'], 'pending');
  });

  test('persists an expense, its shares and outbox atomically', () async {
    final db = await database.database;
    await insertGroup(db);
    final repository = ExpenseRepository(database);
    final id = await repository.saveExpense(
      groupId: 'trip',
      actorUid: 'uid',
      baseRevision: 0,
      fields: {
        'description': 'Jantar',
        'amount_cents': 10001,
        'currency': 'BRL',
        'exchange_rate': '1',
        'payer_id': 'ana',
        'category': 'Alimentação',
        'occurred_at': 1,
        'notes': '',
        'created_by': 'uid',
      },
      sharesCents: {'ana': 5001, 'bia': 5000},
    );

    final savedExpenses = await db.query('expenses', where: 'id = ?', whereArgs: [id]);
    expect(savedExpenses.length, 1);
    expect(savedExpenses.single['created_by'], 'uid');
    expect((await db.query('expense_shares')).length, 2);
    final outbox = await db.query('sync_outbox');
    expect(outbox.length, 1);
    expect(outbox.single['status'], 'pending');
    expect(outbox.single['base_revision'], 0);
  });

  test('rejects invalid shares before writing local data', () async {
    final db = await database.database;
    await insertGroup(db);
    final repository = ExpenseRepository(database);

    await expectLater(
      repository.saveExpense(
        groupId: 'trip',
        actorUid: 'uid',
        baseRevision: 0,
        fields: {
          'description': 'Jantar',
          'amount_cents': 10000,
          'currency': 'BRL',
          'exchange_rate': '1',
          'payer_id': 'ana',
          'category': 'Alimentação',
          'occurred_at': 1,
          'notes': '',
        },
        sharesCents: {'ana': 9000},
      ),
      throwsArgumentError,
    );
    expect(await db.query('expenses'), isEmpty);
    expect(await db.query('sync_outbox'), isEmpty);
  });

  test('updates a group only at its expected revision and queues the change', () async {
    final repository = GroupRepository(database);
    final group = await repository.createGroup(
      name: 'Viagem',
      destination: 'Chile',
      description: '',
      currency: 'BRL',
      types: ['Viagem'],
      actorUid: 'uid',
      creatorName: 'Ana',
      syncEnabled: true,
    );

    await repository.updateGroup(
      group: group,
      name: 'Viagem atualizada',
      destination: 'Atacama',
      description: 'Férias',
      currency: 'CLP',
      types: ['Viagem', 'Passeio'],
      actorUid: 'uid',
      syncEnabled: true,
    );

    final db = await database.database;
    final saved = (await db.query('groups_local', where: 'id = ?', whereArgs: [group.id])).single;
    expect(saved['name'], 'Viagem atualizada');
    expect(saved['destination'], 'Atacama');
    expect(saved['revision'], 2);
    final update = (await db.query('sync_outbox', where: "entity_type = 'group' AND operation = 'update'")).single;
    expect(update['base_revision'], 1);
    expect(jsonDecode(update['payload']! as String)['currency'], 'CLP');
  });

  test('edits expense details without changing its financial split', () async {
    final db = await database.database;
    await insertGroup(db);
    final repository = ExpenseRepository(database);
    final id = await repository.saveExpense(
      groupId: 'trip',
      actorUid: 'uid',
      baseRevision: 0,
      fields: {
        'description': 'Jantar', 'amount_cents': 10000,
        'original_amount_cents': 10000, 'currency': 'BRL',
        'exchange_rate': '1', 'payer_id': 'ana', 'category': 'Alimentação',
        'occurred_at': 1, 'notes': '', 'created_by': 'uid',
      },
      sharesCents: {'ana': 6000, 'bia': 4000},
    );

    await repository.updateExpenseDetails(
      groupId: 'trip', expenseId: id, baseRevision: 1, actorUid: 'uid',
      description: 'Jantar atualizado', category: 'Passeios',
      occurredAt: 1234, notes: 'Incluiu sobremesa',
    );

    final saved = (await db.query('expenses', where: 'id = ?', whereArgs: [id])).single;
    expect(saved['description'], 'Jantar atualizado');
    expect(saved['amount_cents'], 10000);
    expect(saved['revision'], 2);
    final shares = await db.query('expense_shares', where: 'expense_id = ?', whereArgs: [id]);
    expect(shares.map((row) => row['amount_cents']).toSet(), {6000, 4000});
    final operation = (await db.query('sync_outbox', where: "entity_type = 'expense' AND operation = 'update'")).single;
    expect(operation['base_revision'], 1);
    expect(jsonDecode(operation['payload']! as String)['shares'], {'ana': 6000, 'bia': 4000});
  });

  test('choosing local conflict version retries against the remote revision', () async {
    final db = await database.database;
    await insertGroup(db);
    final expenseRepository = ExpenseRepository(database);
    final id = await expenseRepository.saveExpense(
      groupId: 'trip', actorUid: 'uid', baseRevision: 0,
      fields: {
        'description': 'Café', 'amount_cents': 2500,
        'original_amount_cents': 2500, 'currency': 'BRL',
        'exchange_rate': '1', 'payer_id': 'ana', 'category': 'Alimentação',
        'occurred_at': 1, 'notes': '', 'created_by': 'uid',
      },
      sharesCents: {'ana': 2500},
    );
    final syncRepository = SyncOutboxRepository(database);
    final operation = (await syncRepository.pending()).single;
    await syncRepository.markConflict(
      operation: operation,
      remotePayload: {'id': id, 'revision': 4, 'description': 'Versão remota'},
    );

    await syncRepository.resolveWithLocalVersion(operation.id);

    final queued = (await db.query('sync_outbox', where: 'operation_id = ?', whereArgs: [operation.id])).single;
    final conflict = (await db.query('sync_conflicts', where: 'operation_id = ?', whereArgs: [operation.id])).single;
    expect(queued['base_revision'], 4);
    expect(queued['status'], 'pending');
    expect(conflict['resolution'], 'local');
    expect(await syncRepository.conflicts(), isEmpty);
  });

  test('choosing remote conflict version replaces local expense and shares', () async {
    final db = await database.database;
    await insertGroup(db);
    final expenseRepository = ExpenseRepository(database);
    final id = await expenseRepository.saveExpense(
      groupId: 'trip', actorUid: 'uid', baseRevision: 0,
      fields: {
        'description': 'Versão local', 'amount_cents': 2500,
        'original_amount_cents': 2500, 'currency': 'BRL',
        'exchange_rate': '1', 'payer_id': 'ana', 'category': 'Outros',
        'occurred_at': 1, 'notes': '', 'created_by': 'uid',
      },
      sharesCents: {'ana': 2500},
    );
    final syncRepository = SyncOutboxRepository(database);
    final operation = (await syncRepository.pending()).single;
    await syncRepository.markConflict(
      operation: operation,
      remotePayload: {
        'id': id, 'groupId': 'trip', 'revision': 3,
        'description': 'Versão nuvem', 'amountCents': 5000,
        'currency': 'BRL', 'exchangeRate': '1', 'payerId': 'bia',
        'category': 'Alimentação', 'occurredAt': 10, 'shares': {'bia': 5000},
      },
    );

    await syncRepository.resolveWithRemoteVersion(operation.id);

    final saved = (await db.query('expenses', where: 'id = ?', whereArgs: [id])).single;
    expect(saved['description'], 'Versão nuvem');
    expect(saved['amount_cents'], 5000);
    expect(saved['revision'], 3);
    final shares = await db.query('expense_shares', where: 'expense_id = ?', whereArgs: [id]);
    expect(shares.single['participant_id'], 'bia');
    expect(shares.single['amount_cents'], 5000);
    final queued = (await db.query('sync_outbox', where: 'operation_id = ?', whereArgs: [operation.id])).single;
    expect(queued['status'], 'resolved_remote');
    expect(await syncRepository.conflicts(), isEmpty);
  });
}
