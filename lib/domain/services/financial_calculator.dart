enum ExpenseDivisionMode { equal, selected, exact, percentages, weights }

class ExpenseShare {
  const ExpenseShare({required this.participantId, required this.cents});

  final String participantId;
  final int cents;
}

class DebtTransfer {
  const DebtTransfer({
    required this.fromParticipantId,
    required this.toParticipantId,
    required this.cents,
  });

  final String fromParticipantId;
  final String toParticipantId;
  final int cents;
}

/// All amounts are integer cents. Proportional remainders go to the largest
/// fractional remainders, with participant order as a stable tie-breaker.
class FinancialCalculator {
  const FinancialCalculator();

  List<ExpenseShare> splitEqually(int totalCents, List<String> participantIds) {
    _validateTotal(totalCents);
    if (participantIds.isEmpty) {
      throw ArgumentError('Selecione ao menos um participante.');
    }
    _validateParticipants(participantIds);
    return _allocate(totalCents, participantIds, List.filled(participantIds.length, 1));
  }

  List<ExpenseShare> splitExact(
    int totalCents,
    Map<String, int> centsByParticipant,
  ) {
    _validateTotal(totalCents);
    _validateParticipants(centsByParticipant.keys.toList());
    if (centsByParticipant.values.any((value) => value < 0)) {
      throw ArgumentError('Os valores não podem ser negativos.');
    }
    final sum = centsByParticipant.values.fold<int>(0, (a, b) => a + b);
    if (sum != totalCents) {
      throw ArgumentError('A soma das parcelas deve ser igual ao total.');
    }
    return centsByParticipant.entries
        .map((entry) => ExpenseShare(participantId: entry.key, cents: entry.value))
        .toList(growable: false);
  }

  /// Percentages are basis points: 10000 means 100.00%.
  List<ExpenseShare> splitByBasisPoints(
    int totalCents,
    Map<String, int> basisPointsByParticipant,
  ) {
    _validateTotal(totalCents);
    _validateParticipants(basisPointsByParticipant.keys.toList());
    if (basisPointsByParticipant.values.any((value) => value < 0) ||
        basisPointsByParticipant.values.fold<int>(0, (a, b) => a + b) != 10000) {
      throw ArgumentError('As porcentagens devem somar 100%.');
    }
    return _allocate(
      totalCents,
      basisPointsByParticipant.keys.toList(),
      basisPointsByParticipant.values.toList(),
    );
  }

  List<ExpenseShare> splitByWeights(
    int totalCents,
    Map<String, int> weightsByParticipant,
  ) {
    _validateTotal(totalCents);
    _validateParticipants(weightsByParticipant.keys.toList());
    if (weightsByParticipant.values.any((weight) => weight < 0) ||
        weightsByParticipant.values.every((weight) => weight == 0)) {
      throw ArgumentError('Informe cotas positivas.');
    }
    return _allocate(
      totalCents,
      weightsByParticipant.keys.toList(),
      weightsByParticipant.values.toList(),
    );
  }

  /// The payer is credited the expense total and each participant is debited
  /// their share. Positive balances are creditors; negative balances owe money.
  Map<String, int> calculateBalances({
    required Map<String, int> paidCentsByParticipant,
    required Iterable<ExpenseShare> shares,
  }) {
    final balances = <String, int>{};
    for (final entry in paidCentsByParticipant.entries) {
      if (entry.value < 0) throw ArgumentError('Pagamento inválido.');
      balances[entry.key] = (balances[entry.key] ?? 0) + entry.value;
    }
    for (final share in shares) {
      if (share.cents < 0) throw ArgumentError('Parcela inválida.');
      balances[share.participantId] =
          (balances[share.participantId] ?? 0) - share.cents;
    }
    return Map.unmodifiable(balances);
  }

  List<DebtTransfer> simplifyDebts(Map<String, int> balancesCents) {
    final creditors = balancesCents.entries
        .where((entry) => entry.value > 0)
        .map((entry) => MapEntry(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final debtors = balancesCents.entries
        .where((entry) => entry.value < 0)
        .map((entry) => MapEntry(entry.key, -entry.value))
        .toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final net = balancesCents.values.fold<int>(0, (a, b) => a + b);
    if (net != 0) {
      throw ArgumentError('Os saldos precisam somar zero para gerar acertos.');
    }

    final transfers = <DebtTransfer>[];
    var debtorIndex = 0;
    var creditorIndex = 0;
    while (debtorIndex < debtors.length && creditorIndex < creditors.length) {
      final debtor = debtors[debtorIndex];
      final creditor = creditors[creditorIndex];
      final amount = debtor.value < creditor.value ? debtor.value : creditor.value;
      if (amount > 0) {
        transfers.add(DebtTransfer(
          fromParticipantId: debtor.key,
          toParticipantId: creditor.key,
          cents: amount,
        ));
      }
      debtors[debtorIndex] = MapEntry(debtor.key, debtor.value - amount);
      creditors[creditorIndex] = MapEntry(creditor.key, creditor.value - amount);
      if (debtors[debtorIndex].value == 0) debtorIndex++;
      if (creditors[creditorIndex].value == 0) creditorIndex++;
    }
    return List.unmodifiable(transfers);
  }

  List<ExpenseShare> _allocate(int total, List<String> ids, List<int> weights) {
    final weightTotal = weights.fold<int>(0, (a, b) => a + b);
    if (weightTotal == 0) throw ArgumentError('A soma dos pesos deve ser positiva.');
    final allocations = <int>[];
    final remainders = <int>[];
    var allocated = 0;
    for (final weight in weights) {
      final numerator = total * weight;
      final amount = numerator ~/ weightTotal;
      allocations.add(amount);
      remainders.add(numerator % weightTotal);
      allocated += amount;
    }
    final order = List<int>.generate(ids.length, (index) => index)
      ..sort((a, b) {
        final byRemainder = remainders[b].compareTo(remainders[a]);
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    for (var i = 0; i < total - allocated; i++) {
      allocations[order[i]]++;
    }
    return List<ExpenseShare>.generate(
      ids.length,
      (index) => ExpenseShare(participantId: ids[index], cents: allocations[index]),
      growable: false,
    );
  }

  void _validateTotal(int totalCents) {
    if (totalCents < 0) throw ArgumentError('O total não pode ser negativo.');
  }

  void _validateParticipants(List<String> ids) {
    if (ids.isEmpty || ids.any((id) => id.trim().isEmpty)) {
      throw ArgumentError('Informe participantes válidos.');
    }
    if (ids.toSet().length != ids.length) {
      throw ArgumentError('Um participante não pode aparecer mais de uma vez.');
    }
  }
}
