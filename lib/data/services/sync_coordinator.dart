// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'firestore_sync_service.dart';

class SyncCoordinator extends ChangeNotifier {
  SyncCoordinator({
    required FirebaseAuth auth,
    required Connectivity connectivity,
    required FirestoreSyncService syncService,
  })  : _auth = auth,
        _connectivity = connectivity,
        _syncService = syncService {
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) syncNow();
    });
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((results) {
      if (results.any((result) => result != ConnectivityResult.none)) {
        syncNow();
      }
    });
    if (_auth.currentUser != null) syncNow();
  }

  final FirebaseAuth _auth;
  final Connectivity _connectivity;
  final FirestoreSyncService _syncService;
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isSyncing = false;
  bool _syncRequestedWhileRunning = false;
  Future<void>? _activeSync;
  String? _lastError;
  int _lastSyncedCount = 0;

  bool get isSyncing => _isSyncing;
  String? get lastError => _lastError;
  int get lastSyncedCount => _lastSyncedCount;

  Future<void> joinByInviteCode(String code) async {
    if (_auth.currentUser == null) {
      throw StateError('Entre na sua conta para participar de um grupo.');
    }
    await _syncService.joinByInviteCode(code);
    await syncNow();
  }

  Future<void> syncNow() {
    if (_auth.currentUser == null) return Future.value();
    if (_isSyncing) {
      _syncRequestedWhileRunning = true;
      return _activeSync ?? Future.value();
    }
    final completer = Completer<void>();
    _activeSync = completer.future;
    unawaited(_runSync(completer));
    return completer.future;
  }

  Future<void> _runSync(Completer<void> completer) async {
    _isSyncing = true;
    _lastError = null;
    notifyListeners();
    try {
      do {
        _syncRequestedWhileRunning = false;
        _lastSyncedCount = await _syncService.syncPending();
      } while (_syncRequestedWhileRunning && _auth.currentUser != null);
    } catch (error) {
      _lastError = 'Falha ao sincronizar: $error';
    } finally {
      _isSyncing = false;
      _activeSync = null;
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
