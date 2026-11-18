import 'package:flutter/material.dart';

import '../models/settlement.dart';
import '../models/member_balance.dart';
import '../models/expense.dart';

class SettlementViewModel extends ChangeNotifier {

  final String tripName = 'Mochilão Chile & Atacama';

  final List<Settlement> _settlements = [
    const Settlement(
      id: '1',
      from: 'Gabriel Souza',
      to: 'Você',
      amount: 420.00,
      status: SettlementStatus.pending,
    ),
    const Settlement(
      id: '2',
      from: 'Sofia Ramos',
      to: 'Lucas M.',
      amount: 350.50,
      status: SettlementStatus.pending,
    ),
    const Settlement(
      id: '3',
      from: 'Bia Duarte',
      to: 'Você',
      amount: 180.00,
      status: SettlementStatus.pending,
    ),
  ];

  final List<MemberBalance> balances = const [
    MemberBalance(
      name: 'Você (Camila)',
      initials: 'CH',
      balance: 600.00,
    ),
    MemberBalance(
      name: 'Lucas M.',
      initials: 'LM',
      balance: 350.50,
    ),
    MemberBalance(
      name: 'Gabriel Souza',
      initials: 'GS',
      balance: -420.00,
    ),
    MemberBalance(
      name: 'Sofia Ramos',
      initials: 'SR',
      balance: -350.50,
    ),
    MemberBalance(
      name: 'Bia Duarte',
      initials: 'BD',
      balance: -180.00,
    ),
  ];

  final List<ExpenseCategory> categories = const [
    ExpenseCategory(
      name: 'Hospedagem',
      amount: 6237,
      percentage: 42,
      color: Color(0xFF10B981),
    ),
    ExpenseCategory(
      name: 'Alimentação',
      amount: 4158,
      percentage: 28,
      color: Color(0xFFF59E0B),
    ),
    ExpenseCategory(
      name: 'Passeios',
      amount: 2970,
      percentage: 20,
      color: Color(0xFF6366F1),
    ),
    ExpenseCategory(
      name: 'Transporte',
      amount: 1485,
      percentage: 10,
      color: Color(0xFF0EA5E9),
    ),
  ];

  List<Settlement> get settlements =>
      List.unmodifiable(_settlements);

  List<Settlement> get pendingSettlements {
    return _settlements
        .where((item) =>
    item.status == SettlementStatus.pending)
        .toList();
  }

  double get totalToSettle {
    return pendingSettlements.fold(
      0,
          (total, item) => total + item.amount,
    );
  }

  int get settledCount {
    return _settlements
        .where((item) =>
    item.status == SettlementStatus.settled)
        .length;
  }

  // Marca uma transferência como paga.
  void markAsSettled(String id) {
    final index = _settlements.indexWhere(
          (item) => item.id == id,
    );

    if (index == -1) return;

    _settlements[index] = _settlements[index].copyWith(
      status: SettlementStatus.settled,
    );

    notifyListeners();
  }

  // Finaliza todas as liquidações.
  void closeGroup() {
    for (int i = 0; i < _settlements.length; i++) {
      _settlements[i] = _settlements[i].copyWith(
        status: SettlementStatus.settled,
      );
    }

    notifyListeners();
  }
}