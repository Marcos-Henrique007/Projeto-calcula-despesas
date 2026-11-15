import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class GroupReportService {
  Future<void> shareReport({
    required String groupName,
    required String currency,
    required int totalCents,
    required List<Map<String, Object?>> expenses,
    required List<Map<String, Object?>> participants,
    required Map<String, int> balances,
    required List<Map<String, Object?>> settlements,
  }) async {
    final participantNames = {
      for (final participant in participants)
        participant['id']! as String: participant['name']! as String,
    };
    final categoryTotals = <String, int>{};
    for (final expense in expenses) {
      final category = expense['category']! as String;
      categoryTotals[category] =
          (categoryTotals[category] ?? 0) + (expense['amount_cents']! as int);
    }

    final document = pw.Document();
    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Text('Fechamento: $groupName'),
          ),
          pw.Text('Moeda principal: $currency'),
          pw.Text('Total gasto: ${_money(totalCents, currency)}'),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Despesas')),
          if (expenses.isEmpty)
            pw.Text('Nenhuma despesa registrada.')
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey400, width: .5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(1),
                3: const pw.FlexColumnWidth(1.5),
              },
              children: [
                _row(['Descrição', 'Categoria', 'Data', 'Valor'], header: true),
                ...expenses.map((expense) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    expense['occurred_at']! as int,
                  );
                  return _row([
                    expense['description']! as String,
                    expense['category']! as String,
                    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                    _money(expense['amount_cents']! as int, currency),
                  ]);
                }),
              ],
            ),
          pw.SizedBox(height: 16),
          pw.Header(level: 1, child: pw.Text('Gastos por categoria')),
          ...categoryTotals.entries.map(
            (entry) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text('${entry.key}: ${_money(entry.value, currency)}'),
            ),
          ),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Saldos individuais')),
          ...participants.map((participant) {
            final id = participant['id']! as String;
            final balance = balances[id] ?? 0;
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 4),
              child: pw.Text(
                '${participantNames[id]}: ${balance >= 0 ? 'recebe' : 'deve'} ${_money(balance.abs(), currency)}',
              ),
            );
          }),
          pw.SizedBox(height: 12),
          pw.Header(level: 1, child: pw.Text('Pagamentos registrados')),
          if (settlements.isEmpty)
            pw.Text('Nenhum pagamento registrado.')
          else
            ...settlements.map((settlement) {
              final from = participantNames[settlement['from_participant_id']] ??
                  'Participante';
              final to = participantNames[settlement['to_participant_id']] ??
                  'Participante';
              return pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  '$from pagou $to: ${_money(settlement['amount_cents']! as int, currency)}',
                ),
              );
            }),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await document.save(),
      filename: 'fechamento_dividitrip.pdf',
    );
  }

  pw.TableRow _row(List<String> cells, {bool header = false}) => pw.TableRow(
        decoration: header ? const pw.BoxDecoration(color: PdfColors.grey200) : null,
        children: cells
            .map((cell) => pw.Padding(
                  padding: const pw.EdgeInsets.all(5),
                  child: pw.Text(
                    cell,
                    style: pw.TextStyle(
                      fontWeight: header ? pw.FontWeight.bold : pw.FontWeight.normal,
                      fontSize: 9,
                    ),
                  ),
                ))
            .toList(),
      );

  String _money(int cents, String currency) {
    final whole = cents ~/ 100;
    final fraction = (cents % 100).toString().padLeft(2, '0');
    final grouped = whole.toString().replaceAllMapped(
          RegExp(r'B(?=(d{3})+(?!d))'),
          (_) => '.',
        );
    return '$currency $grouped,$fraction';
  }
}
