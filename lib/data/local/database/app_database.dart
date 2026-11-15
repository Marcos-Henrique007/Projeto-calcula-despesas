import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  AppDatabase({this._databaseFactory});

  final Future<Database> Function()? _databaseFactory;
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await (_databaseFactory?.call() ?? _openDatabase());
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final root = await getDatabasesPath();
    return openDatabase(
      p.join(root, 'dividitrip.db'),
      version: 6,
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN division_mode TEXT NOT NULL DEFAULT 'equal'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE expenses ADD COLUMN created_by TEXT NOT NULL DEFAULT ''",
          );
        }
        if (oldVersion < 4) {
          await db.execute(
            "ALTER TABLE groups_local ADD COLUMN types TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE expenses ADD COLUMN original_amount_cents INTEGER NOT NULL DEFAULT 0',
          );
          await db.execute(
            'UPDATE expenses SET original_amount_cents = amount_cents',
          );
        }
        if (oldVersion < 6) {
          await db.execute(
            "ALTER TABLE groups_local ADD COLUMN invite_code TEXT NOT NULL DEFAULT ''",
          );
        }
      },
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE local_users (
            uid TEXT PRIMARY KEY,
            display_name TEXT NOT NULL,
            email TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE groups_local (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            destination TEXT NOT NULL,
            description TEXT NOT NULL,
            currency TEXT NOT NULL,
            types TEXT NOT NULL DEFAULT '[]',
            invite_code TEXT NOT NULL DEFAULT '',
            start_date TEXT,
            end_date TEXT,
            created_by TEXT NOT NULL,
            revision INTEGER NOT NULL DEFAULT 1,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER
          )
        ''');
        await db.execute('''
          CREATE TABLE participants (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            name TEXT NOT NULL,
            email TEXT,
            uid TEXT,
            status TEXT NOT NULL,
            joined_at INTEGER NOT NULL,
            FOREIGN KEY(group_id) REFERENCES groups_local(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE expenses (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            description TEXT NOT NULL,
            amount_cents INTEGER NOT NULL CHECK(amount_cents >= 0),
            original_amount_cents INTEGER NOT NULL DEFAULT 0,
            currency TEXT NOT NULL,
            exchange_rate TEXT NOT NULL,
            payer_id TEXT NOT NULL,
            category TEXT NOT NULL,
            division_mode TEXT NOT NULL DEFAULT 'equal',
            occurred_at INTEGER NOT NULL,
            notes TEXT NOT NULL,
            created_by TEXT NOT NULL DEFAULT '',
            receipt_local_path TEXT,
            receipt_remote_path TEXT,
            revision INTEGER NOT NULL DEFAULT 1,
            updated_at INTEGER NOT NULL,
            deleted_at INTEGER,
            FOREIGN KEY(group_id) REFERENCES groups_local(id)
          )
        ''');
        await db.execute('''
          CREATE TABLE expense_shares (
            expense_id TEXT NOT NULL,
            participant_id TEXT NOT NULL,
            amount_cents INTEGER NOT NULL CHECK(amount_cents >= 0),
            PRIMARY KEY(expense_id, participant_id),
            FOREIGN KEY(expense_id) REFERENCES expenses(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE settlements (
            id TEXT PRIMARY KEY,
            group_id TEXT NOT NULL,
            from_participant_id TEXT NOT NULL,
            to_participant_id TEXT NOT NULL,
            amount_cents INTEGER NOT NULL CHECK(amount_cents > 0),
            status TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            settled_at INTEGER,
            revision INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE exchange_rates (
            base_currency TEXT NOT NULL,
            quote_currency TEXT NOT NULL,
            rate TEXT NOT NULL,
            source TEXT NOT NULL,
            fetched_at INTEGER NOT NULL,
            PRIMARY KEY(base_currency, quote_currency)
          )
        ''');
        await db.execute('''
          CREATE TABLE sync_outbox (
            operation_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            group_id TEXT,
            operation TEXT NOT NULL,
            payload TEXT NOT NULL,
            base_revision INTEGER NOT NULL,
            created_at INTEGER NOT NULL,
            status TEXT NOT NULL DEFAULT 'pending',
            last_error TEXT
          )
        ''');
        await db.execute('''
          CREATE INDEX outbox_pending_idx ON sync_outbox(status, created_at)
        ''');
        await db.execute('''
          CREATE TABLE sync_conflicts (
            operation_id TEXT PRIMARY KEY,
            entity_type TEXT NOT NULL,
            entity_id TEXT NOT NULL,
            local_payload TEXT NOT NULL,
            remote_payload TEXT NOT NULL,
            detected_at INTEGER NOT NULL,
            resolution TEXT,
            resolved_at INTEGER
          )
        ''');
      },
    );
  }
}
