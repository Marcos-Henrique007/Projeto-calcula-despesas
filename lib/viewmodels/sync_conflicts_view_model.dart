import 'package:flutter/foundation.dart';

import '../data/repositories/sync_outbox_repository.dart';

class SyncConflictsViewModel extends ChangeNotifier {
  SyncConflictsViewModel({
    required this._repository,
    required this._syncNow,
  });

  final SyncOutboxRepository _repository;
  final Future<void> Function() _syncNow;

  List<SyncConflict> _conflicts = const [];
  bool _isLoading = false;
  String? _error;
  String? _busyOperationId;

  List<SyncConflict> get conflicts => _conflicts;
  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get busyOperationId => _busyOperationId;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _conflicts = await _repository.conflicts();
    } catch (_) {
      _error = 'Não foi possível carregar os conflitos locais.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> useLocalVersion(SyncConflict conflict) =>
      _resolve(conflict, _repository.resolveWithLocalVersion);

  Future<bool> useRemoteVersion(SyncConflict conflict) =>
      _resolve(conflict, _repository.resolveWithRemoteVersion);

  Future<bool> _resolve(
    SyncConflict conflict,
    Future<void> Function(String operationId) resolve,
  ) async {
    _busyOperationId = conflict.operationId;
    _error = null;
    notifyListeners();
    try {
      await resolve(conflict.operationId);
      await _syncNow();
      await load();
      return true;
    } catch (_) {
      _error = 'Não foi possível resolver este conflito. Os dados foram preservados.';
      return false;
    } finally {
      _busyOperationId = null;
      notifyListeners();
    }
  }
}
