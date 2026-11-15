import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_calcula_despesas/core/utils/money_input.dart';

void main() {
  test('parses Brazilian thousands and decimal separators into cents', () {
    expect(parseBrazilianMoneyToCents('1.234,56'), 123456);
    expect(parseBrazilianMoneyToCents('12,5'), 1250);
    expect(parseBrazilianMoneyToCents('1234.56'), 123456);
    expect(parseBrazilianMoneyToCents('R\$ 0,05'), 5);
  });

  test('rejects invalid or negative amounts', () {
    expect(parseBrazilianMoneyToCents(''), isNull);
    expect(parseBrazilianMoneyToCents('-5,00'), isNull);
    expect(parseBrazilianMoneyToCents('1,234'), isNull);
  });
}
