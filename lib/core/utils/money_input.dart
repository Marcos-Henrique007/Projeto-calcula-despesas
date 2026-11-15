int? parseBrazilianMoneyToCents(String input) {
  var value = input.trim().replaceAll(RegExp(r'[^0-9,.-]'), '');
  if (value.isEmpty || value.startsWith('-')) return null;

  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceFirst(',', '.');
  }
  final parts = value.split('.');
  if (parts.length > 2 ||
      parts.first.isEmpty ||
      (parts.length == 2 && parts.last.length > 2)) {
    return null;
  }
  final whole = int.tryParse(parts.first);
  final fraction = parts.length == 1
      ? 0
      : int.tryParse(parts.last.padRight(2, '0'));
  if (whole == null || fraction == null) return null;
  return whole * 100 + fraction;
}

String formatCents(int cents, {String symbol = 'R\$'}) {
  final absolute = cents.abs();
  final whole = absolute ~/ 100;
  final fraction = (absolute % 100).toString().padLeft(2, '0');
  final wholeText = whole.toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => '.',
      );
  final sign = cents < 0 ? '-' : '';
  return '$sign$symbol $wholeText,$fraction';
}
