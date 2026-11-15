import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_calcula_despesas/data/services/exchange_rate_service.dart';

void main() {
  test('converts cents using decimal integer arithmetic and rounds half up', () {
    final rate = ExchangeRate(
      base: 'USD',
      quote: 'BRL',
      rate: '5.25',
      asOf: DateTime.utc(2026),
      source: 'test',
    );
    expect(rate.convertCents(100), 525);
    expect(rate.convertCents(1), 5);
  });

  test('rejects negative values', () {
    final rate = ExchangeRate(
      base: 'EUR',
      quote: 'BRL',
      rate: '6.1',
      asOf: DateTime.utc(2026),
      source: 'test',
    );
    expect(() => rate.convertCents(-1), throwsArgumentError);
  });
}
