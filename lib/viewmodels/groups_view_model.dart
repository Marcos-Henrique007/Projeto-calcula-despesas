// ignore_for_file: prefer_initializing_formals

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import '../data/repositories/expense_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/services/receipt_storage_service.dart';
import '../data/services/group_report_service.dart';
import '../data/services/exchange_rate_service.dart';
import '../domain/models/travel_group.dart';
import '../domain/services/financial_calculator.dart';

class GroupsViewModel extends ChangeNotifier {
  GroupsViewModel({
    required GroupRepository repository,
    required String actorId,
    required bool syncEnabled,
    required Future<void> Function() syncNow,
  })  : _repository = repository,
        _actorId = actorId,
        _syncEnabled = syncEnabled,
        _syncNow = syncNow;

  final GroupRepository _repository;
  final String _actorId;
  final bool _syncEnabled;
  final Future<void> Function() _syncNow;
  List<TravelGroup> _groups = const [];
  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;

  List<TravelGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // Restore the cloud snapshot before loading the local-first list. This is
      // essential after Android clears app storage or the user reinstalls it.
      if (_syncEnabled) await _syncNow();
      _groups = await _repository.groupsFor(_actorId);
    } catch (_) {
      _error = 'Não foi possível carregar seus grupos locais.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> reloadLocal() async {
    try {
      _groups = await _repository.groupsFor(_actorId);
      _error = null;
    } catch (_) {
      _error = 'Não foi possível carregar seus grupos locais.';
    }
    notifyListeners();
  }

  Future<bool> updateGroup({
    required TravelGroup group,
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
  }) async {
    if (group.createdBy != _actorId) {
      _error = 'Somente quem criou o grupo pode editá-lo.';
      notifyListeners();
      return false;
    }
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.updateGroup(
        group: group,
        name: name,
        destination: destination,
        description: description,
        currency: currency,
        types: types,
        actorUid: _actorId,
        syncEnabled: _syncEnabled,
      );
      _groups = await _repository.groupsFor(_actorId);
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError
          ? error.message.toString()
          : error is StateError
              ? error.message.toString()
              : 'Falha ao editar o grupo.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteGroup(TravelGroup group) async {
    if (group.createdBy != _actorId) {
      _error = 'Somente quem criou o grupo pode excluí-lo.';
      notifyListeners();
      return false;
    }
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.deleteGroup(
        groupId: group.id,
        actorUid: _actorId,
        syncEnabled: _syncEnabled,
      );
      _groups = await _repository.groupsFor(_actorId);
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is StateError ? error.message.toString() : 'Falha ao excluir o grupo.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> create({
    required String name,
    required String destination,
    required String description,
    required String currency,
    required List<String> types,
    required String creatorName,
    String? creatorEmail,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _repository.createGroup(
        name: name,
        destination: destination,
        description: description,
        currency: currency,
        types: types,
        actorUid: _actorId,
        creatorName: creatorName,
        creatorEmail: creatorEmail,
        syncEnabled: _syncEnabled,
      );
      _groups = await _repository.groupsFor(_actorId);
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError ? error.message.toString() : 'Falha ao criar o grupo.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}

class GroupDetailsViewModel extends ChangeNotifier {
  GroupDetailsViewModel({
    required GroupRepository groupRepository,
    required ExpenseRepository expenseRepository,
    required ReceiptStorageService receiptStorage,
    required GroupReportService reportService,
    required ExchangeRateService exchangeRateService,
    required Connectivity connectivity,
    required FinancialCalculator calculator,
    required this.group,
    required String actorId,
    required bool syncEnabled,
    required Future<void> Function() syncNow,
  })  : _groupRepository = groupRepository,
        _expenseRepository = expenseRepository,
        _receiptStorage = receiptStorage,
        _reportService = reportService,
        _exchangeRateService = exchangeRateService,
        _connectivity = connectivity,
        _calculator = calculator,
        _actorId = actorId,
        _syncEnabled = syncEnabled,
        _syncNow = syncNow;

  final GroupRepository _groupRepository;
  final ExpenseRepository _expenseRepository;
  final ReceiptStorageService _receiptStorage;
  final GroupReportService _reportService;
  final ExchangeRateService _exchangeRateService;
  final Connectivity _connectivity;
  final FinancialCalculator _calculator;
  final TravelGroup group;
  final String _actorId;
  final bool _syncEnabled;
  final Future<void> Function() _syncNow;

  List<Map<String, Object?>> _participants = const [];
  List<Map<String, Object?>> _expenses = const [];
  List<Map<String, Object?>> _settlements = const [];
  List<DebtTransfer> _transfers = const [];
  Map<String, int> _balances = const {};
  int _expenseCount = 0;
  int _totalCents = 0;
  bool _isLoading = false;
  bool _isBusy = false;
  String? _error;

  List<Map<String, Object?>> get participants => _participants;
  List<Map<String, Object?>> get expenses => _expenses;
  List<Map<String, Object?>> get settlements => _settlements;
  List<DebtTransfer> get transfers => _transfers;
  int balanceFor(String participantId) => _balances[participantId] ?? 0;
  int get expenseCount => _expenseCount;
  int get totalCents => _totalCents;
  bool get isLoading => _isLoading;
  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      _participants = await _groupRepository.participants(group.id);
      _expenses = await _groupRepository.expenses(group.id);
      final ledgerRows = await _groupRepository.expenseLedger(group.id);
      final paid = <String, int>{};
      final shares = <ExpenseShare>[];
      final countedExpenses = <String>{};
      for (final row in ledgerRows) {
        final expenseId = row['expense_id']! as String;
        if (countedExpenses.add(expenseId)) {
          final payerId = row['payer_id']! as String;
          paid[payerId] =
              (paid[payerId] ?? 0) + (row['amount_cents']! as int);
        }
        final participantId = row['participant_id'] as String?;
        final shareCents = row['share_cents'] as int?;
        if (participantId != null && shareCents != null) {
          shares.add(ExpenseShare(participantId: participantId, cents: shareCents));
        }
      }
      _balances = Map<String, int>.from(_calculator.calculateBalances(
        paidCentsByParticipant: paid,
        shares: shares,
      ));
      _settlements = await _groupRepository.settlements(group.id);
      for (final settlement in _settlements) {
        final from = settlement['from_participant_id']! as String;
        final to = settlement['to_participant_id']! as String;
        final cents = settlement['amount_cents']! as int;
        _balances[from] = (_balances[from] ?? 0) + cents;
        _balances[to] = (_balances[to] ?? 0) - cents;
      }
      _transfers = _calculator.simplifyDebts(_balances);
      _expenseCount = await _groupRepository.expenseCount(group.id);
      _totalCents = await _groupRepository.expenseTotalCents(group.id);
    } catch (_) {
      _error = 'Não foi possível carregar os dados deste grupo.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addParticipant({required String name, String? email}) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _groupRepository.addParticipant(
        groupId: group.id,
        name: name,
        email: email,
        actorUid: _actorId,
        syncEnabled: _syncEnabled,
      );
      _participants = await _groupRepository.participants(group.id);
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError ? error.message.toString() : 'Falha ao adicionar participante.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> updateExpenseDetails({
    required Map<String, Object?> expense,
    required String description,
    required String category,
    required DateTime occurredAt,
    required String notes,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _expenseRepository.updateExpenseDetails(
        groupId: group.id,
        expenseId: expense['id']! as String,
        baseRevision: expense['revision']! as int,
        actorUid: _actorId,
        description: description,
        category: category,
        occurredAt: occurredAt.millisecondsSinceEpoch,
        notes: notes,
        queueSync: _syncEnabled,
      );
      await load();
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError
          ? error.message.toString()
          : error is StateError
              ? error.message.toString()
              : 'Falha ao editar a despesa.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> deleteExpense(Map<String, Object?> expense) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _expenseRepository.deleteExpense(
        groupId: group.id,
        expenseId: expense['id']! as String,
        baseRevision: expense['revision']! as int,
        actorUid: _actorId,
        queueSync: _syncEnabled,
      );
      await load();
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is StateError ? error.message.toString() : 'Falha ao excluir a despesa.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> shareReport() => _reportService.shareReport(
        groupName: group.name,
        currency: group.currency,
        totalCents: _totalCents,
        expenses: _expenses,
        participants: _participants,
        balances: _balances,
        settlements: _settlements,
      );

  Future<bool> recordPayment({
    required String fromParticipantId,
    required String toParticipantId,
    required int amountCents,
  }) async {
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _groupRepository.recordSettlement(
        groupId: group.id,
        fromParticipantId: fromParticipantId,
        toParticipantId: toParticipantId,
        amountCents: amountCents,
        actorUid: _actorId,
        syncEnabled: _syncEnabled,
      );
      await load();
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError ? error.message.toString() : 'Falha ao registrar o acerto.';
      return false;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<bool> addExpense({
    required String description,
    required int amountCents,
    required String currency,
    String? manualExchangeRate,
    required String payerParticipantId,
    required String category,
    required DateTime occurredAt,
    String? receiptSourcePath,
    String notes = '',
    required ExpenseDivisionMode divisionMode,
    List<String>? selectedParticipantIds,
    Map<String, int>? customValues,
  }) async {
    if (_participants.isEmpty) {
      _error = 'Adicione participantes antes de registrar uma despesa.';
      notifyListeners();
      return false;
    }
    _isBusy = true;
    _error = null;
    notifyListeners();
    String? receiptToCleanUp;
    try {
      final connectivity = await _connectivity.checkConnectivity();
      final rate = await _exchangeRateService.getRate(
        base: currency,
        quote: group.currency,
        online: connectivity.any((result) => result != ConnectivityResult.none),
        manualRate: manualExchangeRate?.trim().isEmpty == true
            ? null
            : manualExchangeRate?.trim(),
      );
      final convertedTotalCents = rate.convertCents(amountCents);
      final allIds =
          _participants.map((participant) => participant['id']! as String).toList();
      final values = customValues ?? const <String, int>{};
      final sourceShares = switch (divisionMode) {
        ExpenseDivisionMode.equal =>
          _calculator.splitEqually(amountCents, allIds),
        ExpenseDivisionMode.selected => _calculator.splitEqually(
            amountCents,
            selectedParticipantIds ?? const <String>[],
          ),
        ExpenseDivisionMode.exact => _calculator.splitExact(amountCents, values),
        ExpenseDivisionMode.percentages =>
          _calculator.splitByBasisPoints(amountCents, values),
        ExpenseDivisionMode.weights =>
          _calculator.splitByWeights(amountCents, values),
      };
      final convertedShares = sourceShares
          .map((share) => ExpenseShare(
                participantId: share.participantId,
                cents: rate.convertCents(share.cents),
              ))
          .toList();
      final remainder = convertedTotalCents -
          convertedShares.fold<int>(0, (sum, share) => sum + share.cents);
      if (convertedShares.isNotEmpty && remainder != 0) {
        var largestIndex = 0;
        for (var i = 1; i < convertedShares.length; i++) {
          if (convertedShares[i].cents > convertedShares[largestIndex].cents) {
            largestIndex = i;
          }
        }
        final largest = convertedShares[largestIndex];
        convertedShares[largestIndex] = ExpenseShare(
          participantId: largest.participantId,
          cents: largest.cents + remainder,
        );
      }
      final receiptPath = receiptSourcePath == null
          ? null
          : await _receiptStorage.saveReceipt(receiptSourcePath);
      receiptToCleanUp = receiptPath;
      await _expenseRepository.saveExpense(
        groupId: group.id,
        actorUid: _actorId,
        queueSync: _syncEnabled,
        baseRevision: 0,
        fields: {
          'description': description.trim(),
          'amount_cents': convertedTotalCents,
          'original_amount_cents': amountCents,
          'currency': currency,
          'exchange_rate': rate.rate,
          'payer_id': payerParticipantId,
          'category': category,
          'occurred_at': occurredAt.millisecondsSinceEpoch,
          'notes': notes.trim(),
          'receipt_local_path': receiptPath,
          'created_by': _actorId,
          'division_mode': divisionMode.name,
        },
        sharesCents: {
          for (final share in convertedShares) share.participantId: share.cents,
        },
      );
      receiptToCleanUp = null;
      _expenseCount = await _groupRepository.expenseCount(group.id);
      _totalCents = await _groupRepository.expenseTotalCents(group.id);
      _expenses = await _groupRepository.expenses(group.id);
      if (_syncEnabled) await _syncNow();
      return true;
    } catch (error) {
      _error = error is ArgumentError
          ? error.message.toString()
          : error is StateError
              ? error.message.toString()
              : 'Falha ao salvar a despesa.';
      return false;
    } finally {
      if (receiptToCleanUp != null) {
        try {
          await _receiptStorage.deleteReceipt(receiptToCleanUp);
        } catch (_) {}
      }
      _isBusy = false;
      notifyListeners();
    }
  }
}
