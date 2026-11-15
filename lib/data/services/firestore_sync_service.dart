// ignore_for_file: prefer_initializing_formals

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sqflite/sqflite.dart' as sqlite;
import 'package:path/path.dart' as p;

import '../repositories/sync_outbox_repository.dart';
import '../local/database/app_database.dart';

class RemoteSyncConflict implements Exception {
  const RemoteSyncConflict(this.remoteData);
  final Map<String, Object?> remoteData;
}

/// Sends local outbox operations using a Firestore transaction. Operation
/// marker documents make retries idempotent; revision checks keep concurrent
/// edits from silently replacing each other.
class FirestoreSyncService {
  FirestoreSyncService({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    required FirebaseStorage storage,
    required SyncOutboxRepository outbox,
    required AppDatabase database,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage,
        _outbox = outbox,
        _database = database;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;
  final SyncOutboxRepository _outbox;
  final AppDatabase _database;

  Future<int> syncPending() async {
    var synced = 0;
    for (final operation in await _outbox.pending()) {
      try {
        final uploadedReceiptPath = await _send(operation);
        await _outbox.markSynced(
          operation,
          remoteReceiptPath: uploadedReceiptPath,
        );
        synced++;
      } on RemoteSyncConflict catch (conflict) {
        await _outbox.markConflict(
          operation: operation,
          remotePayload: conflict.remoteData,
        );
      } catch (error) {
        await _outbox.markFailed(operation.id, error);
        rethrow;
      }
    }
    await pullSharedGroups();
    return synced;
  }

  Future<void> joinByInviteCode(String rawCode) async {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) throw StateError('Entre na sua conta para usar um convite.');
    final code = rawCode.trim().toUpperCase();
    if (code.isEmpty) throw ArgumentError('Informe o código do grupo.');
    final inviteSnapshot = await _firestore.collection('invites').doc(code).get();
    final groupId = inviteSnapshot.data()?['groupId'] as String?;
    if (!inviteSnapshot.exists || groupId == null || groupId.isEmpty) {
      throw StateError('Código de convite inválido ou expirado.');
    }
    final membership = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(actorUid);
    final userGroup = _firestore
        .collection('users')
        .doc(actorUid)
        .collection('groups')
        .doc(groupId);
    await _firestore.runTransaction((transaction) async {
      final current = await transaction.get(membership);
      if (!current.exists) {
        transaction.set(membership, {
          'uid': actorUid,
          'role': 'member',
          'inviteCode': code,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      }
      transaction.set(userGroup, {
        'groupId': groupId,
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    final groupRef = _firestore.collection('groups').doc(groupId);
    final existingParticipant = await groupRef
        .collection('participants')
        .where('uid', isEqualTo: actorUid)
        .limit(1)
        .get();
    if (existingParticipant.docs.isEmpty) {
      await groupRef.collection('participants').doc(actorUid).set({
        'id': actorUid,
        'groupId': groupId,
        'name': _auth.currentUser?.displayName ?? _auth.currentUser?.email ?? 'Participante',
        'email': _auth.currentUser?.email,
        'uid': actorUid,
        'status': 'active',
        'createdBy': actorUid,
        'updatedBy': actorUid,
        'revision': 1,
        'joinedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await pullSharedGroups();
  }

  Future<void> pullSharedGroups() async {
    final actorUid = _auth.currentUser?.uid;
    if (actorUid == null) return;
    final memberships = await _firestore
        .collection('users')
        .doc(actorUid)
        .collection('groups')
        .get();
    for (final member in memberships.docs) {
      final groupId = member.id;
      final groupRef = _firestore.collection('groups').doc(groupId);
      final groupSnapshot = await groupRef.get();
      if (!groupSnapshot.exists) continue;
      final groupData = groupSnapshot.data()!;
      if (groupData['deletedAt'] != null) {
        final db = await _database.database;
        final pendingGroupOps = await db.query(
          'sync_outbox',
          columns: ['operation_id'],
          where: 'group_id = ? AND entity_type = ? AND status IN (?, ?)',
          whereArgs: [groupId, 'group', 'pending', 'conflict'],
          limit: 1,
        );
        if (pendingGroupOps.isEmpty) {
          await db.update(
            'groups_local',
            {
              'deleted_at': _timestampMillis(groupData['deletedAt']),
              'updated_at': _timestampMillis(groupData['updatedAt']),
              'revision': (groupData['revision'] as num?)?.toInt() ?? 1,
            },
            where: 'id = ?',
            whereArgs: [groupId],
          );
        }
        continue;
      }
      final childSnapshots = await Future.wait([
        groupRef.collection('participants').get(),
        groupRef.collection('expenses').get(),
        groupRef.collection('settlements').get(),
      ]);
      final localReceiptPaths = <String, String>{};
      for (final expenseDoc in childSnapshots[1].docs) {
        final remotePath = expenseDoc.data()['receiptRemotePath'] as String?;
        if (remotePath == null || remotePath.isEmpty) continue;
        final localPath = await _downloadReceipt(groupId, expenseDoc.id, remotePath);
        if (localPath != null) localReceiptPaths[expenseDoc.id] = localPath;
      }
      final db = await _database.database;
      await db.transaction((txn) async {
        final groupIdRow = groupSnapshot.id;
        final groupRevision = (groupData['revision'] as num?)?.toInt() ?? 1;
        final groupPending = await txn.query(
          'sync_outbox',
          columns: ['operation_id'],
          where: 'group_id = ? AND entity_type = ? AND status IN (?, ?)',
          whereArgs: [groupIdRow, 'group', 'pending', 'conflict'],
          limit: 1,
        );
        final localGroupRows = await txn.query(
          'groups_local',
          columns: ['revision'],
          where: 'id = ?',
          whereArgs: [groupIdRow],
          limit: 1,
        );
        if (groupPending.isEmpty &&
            (localGroupRows.isEmpty ||
                (localGroupRows.single['revision']! as int) <= groupRevision)) {
          await txn.insert(
            'groups_local',
            {
              'id': groupIdRow,
              'name': groupData['name'] ?? '',
              'destination': groupData['destination'] ?? '',
              'description': groupData['description'] ?? '',
              'currency': groupData['currency'] ?? 'BRL',
              'types': jsonEncode(groupData['types'] ?? const <String>[]),
              'invite_code': groupData['inviteCode'] ?? '',
              'start_date': groupData['startDate'],
              'end_date': groupData['endDate'],
              'created_by': groupData['createdBy'] ?? groupData['ownerUid'] ?? '',
              'revision': groupRevision,
              'updated_at': _timestampMillis(groupData['updatedAt']),
              'deleted_at': null,
            },
            conflictAlgorithm: sqlite.ConflictAlgorithm.replace,
          );
        }
        for (final participantDoc in childSnapshots[0].docs) {
          final data = participantDoc.data();
          final pending = await _hasPending(txn, groupIdRow, 'participant', participantDoc.id);
          if (pending) continue;
          await txn.insert('participants', {
            'id': participantDoc.id,
            'group_id': groupIdRow,
            'name': data['name'] ?? 'Participante',
            'email': data['email'],
            'uid': data['uid'],
            'status': data['status'] ?? 'active',
            'joined_at': _timestampMillis(data['joinedAt']),
          }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
        }
        for (final expenseDoc in childSnapshots[1].docs) {
          final data = expenseDoc.data();
          final pending = await _hasPending(txn, groupIdRow, 'expense', expenseDoc.id);
          final revision = (data['revision'] as num?)?.toInt() ?? 1;
          final localRows = await txn.query(
            'expenses',
            columns: ['revision'],
            where: 'id = ?',
            whereArgs: [expenseDoc.id],
            limit: 1,
          );
          if (pending ||
              (localRows.isNotEmpty &&
                  (localRows.single['revision']! as int) > revision)) {
            continue;
          }
          await txn.insert('expenses', {
            'id': expenseDoc.id,
            'group_id': groupIdRow,
            'description': data['description'] ?? '',
            'amount_cents': data['amountCents'] ?? 0,
            'original_amount_cents': data['originalAmountCents'] ?? data['amountCents'] ?? 0,
            'currency': data['currency'] ?? groupData['currency'] ?? 'BRL',
            'exchange_rate': data['exchangeRate']?.toString() ?? '1',
            'payer_id': data['payerId'] ?? '',
            'category': data['category'] ?? 'Outros',
            'division_mode': data['divisionMode'] ?? 'equal',
            'occurred_at': _timestampMillis(data['occurredAt']),
            'notes': data['notes'] ?? '',
            'created_by': data['createdBy'] ?? '',
            'receipt_local_path': localReceiptPaths[expenseDoc.id],
            'receipt_remote_path': data['receiptRemotePath'],
            'revision': revision,
            'updated_at': _timestampMillis(data['updatedAt']),
            'deleted_at': data['deletedAt'] == null ? null : _timestampMillis(data['deletedAt']),
          }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
          await txn.delete('expense_shares',
              where: 'expense_id = ?', whereArgs: [expenseDoc.id]);
          final rawShares = data['shares'];
          if (rawShares is Map) {
            for (final share in rawShares.entries) {
              await txn.insert('expense_shares', {
                'expense_id': expenseDoc.id,
                'participant_id': share.key.toString(),
                'amount_cents': (share.value as num).toInt(),
              }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
            }
          }
        }
        for (final settlementDoc in childSnapshots[2].docs) {
          final data = settlementDoc.data();
          if (await _hasPending(txn, groupIdRow, 'settlement', settlementDoc.id)) {
            continue;
          }
          await txn.insert('settlements', {
            'id': settlementDoc.id,
            'group_id': groupIdRow,
            'from_participant_id': data['fromParticipantId'] ?? '',
            'to_participant_id': data['toParticipantId'] ?? '',
            'amount_cents': data['amountCents'] ?? 0,
            'status': data['status'] ?? 'pending',
            'created_at': _timestampMillis(data['createdAt']),
            'settled_at': _timestampMillis(data['settledAt']),
            'revision': data['revision'] ?? 1,
          }, conflictAlgorithm: sqlite.ConflictAlgorithm.replace);
        }
      });
    }
  }

  Future<String?> _downloadReceipt(
    String groupId,
    String expenseId,
    String remotePath,
  ) async {
    try {
      final root = Directory(p.join(await sqlite.getDatabasesPath(), 'receipts'));
      await root.create(recursive: true);
      final fileName = remotePath.split('/').last;
      final localFile = File(p.join(root.path, '${groupId}_${expenseId}_$fileName'));
      if (!await localFile.exists()) {
        await _storage.ref(remotePath).writeToFile(localFile);
      }
      return localFile.path;
    } catch (_) {
      return null;
    }
  }

  Future<bool> _hasPending(
    sqlite.Transaction txn,
    String groupId,
    String entityType,
    String entityId,
  ) async {
    final rows = await txn.query(
      'sync_outbox',
      columns: ['operation_id'],
      where: 'group_id = ? AND entity_type = ? AND entity_id = ? AND status IN (?, ?)',
      whereArgs: [groupId, entityType, entityId, 'pending', 'conflict'],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  int _timestampMillis(Object? value) {
    if (value is Timestamp) return value.millisecondsSinceEpoch;
    if (value is num) return value.toInt();
    if (value is DateTime) return value.millisecondsSinceEpoch;
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<String?> _send(SyncOperation operation) async {
    final groupId = operation.groupId;
    if (groupId == null || groupId.isEmpty) {
      throw ArgumentError('A operação precisa estar relacionada a um grupo.');
    }
    final entity = _entityReference(operation);
    final actorUid = _auth.currentUser?.uid;
    final payload = Map<String, Object?>.from(operation.payload);
    String? uploadedReceiptPath;
    final localReceiptPath = payload.remove('receiptLocalPath') as String?;
    if (operation.entityType == 'expense' && localReceiptPath != null) {
      final file = File(localReceiptPath);
      if (!await file.exists()) {
        throw StateError('O comprovante local não está mais disponível para sincronizar.');
      }
      if (await file.length() >= 10 * 1024 * 1024) {
        throw StateError('O comprovante excede o limite de 10 MB do Firebase Storage.');
      }
      final extension = localReceiptPath.split('.').last.toLowerCase();
      final contentType = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
      final storageRef = _storage
          .ref()
          .child('groups/$groupId/expenses/${operation.entityId}/receipt.$extension');
      await storageRef.putFile(file, SettableMetadata(contentType: contentType));
      uploadedReceiptPath = storageRef.fullPath;
      payload['receiptRemotePath'] = uploadedReceiptPath;
    }
    if (actorUid == null) throw StateError('É necessário entrar para sincronizar.');
    final marker = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('_operations')
        .doc(operation.id);
    final ownerMembership = _firestore
        .collection('groups')
        .doc(groupId)
        .collection('members')
        .doc(actorUid);

    await _firestore.runTransaction((transaction) async {
      final markerSnapshot = await transaction.get(marker);
      if (markerSnapshot.exists) {
        final markerData = markerSnapshot.data();
        if (markerData?['entityId'] != operation.entityId ||
            markerData?['entityType'] != operation.entityType) {
          throw StateError('O ID de operação já está associado a outro registro.');
        }
        return;
      }

      final entitySnapshot = await transaction.get(entity);
      final remote = entitySnapshot.data();
      final remoteRevision = (remote?['revision'] as num?)?.toInt() ?? 0;
      if (remoteRevision != operation.baseRevision) {
        throw RemoteSyncConflict(
          Map<String, Object?>.from(remote ?? const <String, Object?>{}),
        );
      }

      if (operation.entityType == 'group' && operation.operation == 'create') {
        if (operation.payload['ownerUid'] != actorUid ||
            operation.payload['createdBy'] != actorUid) {
          throw StateError('O criador do grupo deve corresponder ao usuário autenticado.');
        }
        transaction.set(ownerMembership, {
          'uid': actorUid,
          'role': 'owner',
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(
          _firestore.collection('users').doc(actorUid).collection('groups').doc(groupId),
          {
            'groupId': groupId,
            'role': 'owner',
            'joinedAt': FieldValue.serverTimestamp(),
          },
        );
        final inviteCode = operation.payload['inviteCode'] as String?;
        if (inviteCode != null && inviteCode.isNotEmpty) {
          transaction.set(_firestore.collection('invites').doc(inviteCode), {
            'groupId': groupId,
            'createdBy': actorUid,
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
      }
      if (operation.operation == 'delete') {
        transaction.set(entity, {
          'deletedAt': FieldValue.serverTimestamp(),
          'revision': remoteRevision + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorUid,
        }, SetOptions(merge: true));
      } else {
        transaction.set(entity, {
          ...payload,
          'revision': remoteRevision + 1,
          'updatedAt': FieldValue.serverTimestamp(),
          'updatedBy': actorUid,
        }, SetOptions(merge: true));
      }
      transaction.set(marker, {
        'entityType': operation.entityType,
        'entityId': operation.entityId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    return uploadedReceiptPath;
  }

  DocumentReference<Map<String, dynamic>> _entityReference(
    SyncOperation operation,
  ) {
    final group = _firestore.collection('groups').doc(operation.groupId);
    return switch (operation.entityType) {
      'group' => group,
      'expense' => group.collection('expenses').doc(operation.entityId),
      'participant' => group.collection('participants').doc(operation.entityId),
      'settlement' => group.collection('settlements').doc(operation.entityId),
      _ => throw ArgumentError('Tipo de registro não suportado.'),
    };
  }
}
