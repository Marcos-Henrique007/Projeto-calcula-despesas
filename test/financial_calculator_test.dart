import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_calcula_despesas/domain/services/financial_calculator.dart';

void main() {
  const calculator = FinancialCalculator();

  group('divisão financeira em centavos', () {
    test('divide igualmente e distribui o centavo restante de forma estável', () {
      final shares = calculator.splitEqually(1000, ['ana', 'bia', 'caio']);
      expect(shares.map((share) => share.cents).toList(), [334, 333, 333]);
      expect(shares.fold<int>(0, (sum, share) => sum + share.cents), 1000);
    });

    test('valida parcelas exatas', () {
      final shares = calculator.splitExact(1001, {'ana': 501, 'bia': 500});
      expect(shares.map((share) => share.cents).toList(), [501, 500]);
      expect(
        () => calculator.splitExact(1000, {'ana': 400, 'bia': 500}),
        throwsArgumentError,
      );
    });

    test('divide por porcentagens em basis points', () {
      final shares = calculator.splitByBasisPoints(
        10001,
        {'ana': 5000, 'bia': 3000, 'caio': 2000},
      );
      expect(shares.map((share) => share.cents).toList(), [5001, 3000, 2000]);
    });

    test('divide por cotas', () {
      final shares = calculator.splitByWeights(1000, {'ana': 1, 'bia': 2});
      expect(shares.map((share) => share.cents).toList(), [333, 667]);
    });
  });

  test('calcula saldos e simplifica transferências', () {
    final shares = calculator.splitEqually(40000, ['ana', 'bruno', 'carlos']);
    final balances = calculator.calculateBalances(
      paidCentsByParticipant: {'ana': 30000, 'bruno': 10000},
      shares: shares,
    );
    expect(balances.values.fold<int>(0, (sum, value) => sum + value), 0);
    final transfers = calculator.simplifyDebts(balances);
    expect(transfers.map((transfer) => transfer.cents).reduce((a, b) => a + b),
        16666);
    expect(transfers.map((transfer) => transfer.fromParticipantId).toSet(),
        {'bruno', 'carlos'});
  });

  test('rejeita percentuais inválidos e saldos que não fecham', () {
    expect(
      () => calculator.splitByBasisPoints(100, {'ana': 6000, 'bia': 3000}),
      throwsArgumentError,
    );
    expect(() => calculator.simplifyDebts({'ana': 100, 'bia': -50}),
        throwsArgumentError);
  });
}
