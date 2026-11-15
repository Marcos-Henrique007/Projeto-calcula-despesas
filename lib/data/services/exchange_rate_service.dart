import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';

import '../local/database/app_database.dart';

class ExchangeRate {
  const ExchangeRate({
    required this.base,
    required this.quote,
    required this.rate,
    required this.asOf,
    required this.source,
  });

  final String base;
  final String quote;
  final String rate;
  final DateTime asOf;
  final String source;

  /// Converts amounts stored in cents without floating point arithmetic.
  int convertCents(int amountCents) {
    if (amountCents < 0) throw ArgumentError('O valor não pode ser negativo.');
    final parts = rate.split('.');
    final fraction = parts.length == 1 ? '' : parts[1];
    final numerator = BigInt.parse('${parts[0]}$fraction');
    final denominator = BigInt.from(10).pow(fraction.length);
    final scaled = BigInt.from(amountCents) * numerator;
    return ((scaled * BigInt.from(2) + denominator) ~/ (denominator * BigInt.from(2)))
        .toInt();
  }
}

class ExchangeRateService {
  ExchangeRateService({
    required this.database,
    http.Client? client,
    Uri? endpoint,
  })  : _client = client ?? http.Client(),
        _endpoint = endpoint ?? Uri.https('api.frankfurter.dev', '/v2/rates');

  static const supportedCurrencies = {'BRL', 'USD', 'EUR', 'GBP', 'ARS', 'CLP'};
  final AppDatabase database;
  final http.Client _client;
  final Uri _endpoint;

  Future<ExchangeRate> getRate({
    required String base,
    required String quote,
    required bool online,
    String? manualRate,
  }) async {
    _validateCurrency(base);
    _validateCurrency(quote);
    if (base == quote) {
      return ExchangeRate(
        base: base,
        quote: quote,
        rate: '1',
        asOf: DateTime.now(),
        source: 'identidade',
      );
    }
    if (manualRate != null) {
      _validateRate(manualRate);
      final rate = ExchangeRate(
        base: base,
        quote: quote,
        rate: manualRate,
        asOf: DateTime.now(),
        source: 'manual',
      );
      await _save(rate);
      return rate;
    }
    if (online) {
      try {
        final uri = _endpoint.replace(queryParameters: {
          'base': base.toLowerCase(),
          'quotes': quote.toLowerCase(),
        });
        final response = await _client.get(uri).timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) {
          throw StateError('A API de câmbio retornou ${response.statusCode}.');
        }
        final body = jsonDecode(response.body) as List<dynamic>;
        final match = body.cast<Map<String, dynamic>>().firstWhere(
              (item) => (item['quote'] as String).toUpperCase() == quote,
            );
        final rateString = (match['rate'] as num).toString();
        _validateRate(rateString);
        final result = ExchangeRate(
          base: base,
          quote: quote,
          rate: rateString,
          asOf: DateTime.parse(match['date'] as String),
          source: 'Frankfurter',
        );
        await _save(result);
        return result;
      } catch (_) {
        // Fall back to the last successfully saved rate when the API is down.
      }
    }
    final cached = await _read(base, quote);
    if (cached != null) return cached;
    throw StateError('Cotação indisponível. Conecte-se ou informe uma taxa manual.');
  }

  Future<void> _save(ExchangeRate rate) async {
    final db = await database.database;
    await db.insert(
      'exchange_rates',
      {
        'base_currency': rate.base,
        'quote_currency': rate.quote,
        'rate': rate.rate,
        'source': rate.source,
        'fetched_at': rate.asOf.millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<ExchangeRate?> _read(String base, String quote) async {
    final db = await database.database;
    final rows = await db.query(
      'exchange_rates',
      where: 'base_currency = ? AND quote_currency = ?',
      whereArgs: [base, quote],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return ExchangeRate(
      base: row['base_currency']! as String,
      quote: row['quote_currency']! as String,
      rate: row['rate']! as String,
      asOf: DateTime.fromMillisecondsSinceEpoch(row['fetched_at']! as int),
      source: row['source']! as String,
    );
  }

  void _validateCurrency(String currency) {
    if (!supportedCurrencies.contains(currency)) {
      throw ArgumentError('Moeda não suportada: $currency.');
    }
  }

  void _validateRate(String rate) {
    final parsed = RegExp(r'^\d+(\.\d{1,12})?$');
    if (!parsed.hasMatch(rate) || double.parse(rate) <= 0) {
      throw ArgumentError('Informe uma cotação positiva válida.');
    }
  }
}
