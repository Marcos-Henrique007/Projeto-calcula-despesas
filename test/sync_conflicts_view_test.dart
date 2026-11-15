import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:projeto_calcula_despesas/data/local/database/app_database.dart';
import 'package:projeto_calcula_despesas/data/repositories/sync_outbox_repository.dart';
import 'package:projeto_calcula_despesas/views/sync_conflicts_view.dart';

class _FakeSyncOutboxRepository extends SyncOutboxRepository {
  _FakeSyncOutboxRepository() : super(AppDatabase());

  @override
  Future<List<SyncConflict>> conflicts() async => const [
        SyncConflict(
          operationId: 'op-1',
          entityType: 'expense',
          entityId: 'expense-1',
          localPayload: {'description': 'Local'},
          remotePayload: {'description': 'Nuvem'},
          detectedAt: 1794700000000,
        ),
      ];
}

void main() {
  testWidgets('shows conflict details and resolution choices', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: SyncConflictsView(
        repository: _FakeSyncOutboxRepository(),
        syncNow: () async {},
      ),
    ));
    await tester.pump();
    await tester.pump();

    expect(find.text('Despesa · expense-1'), findsOneWidget);
    await tester.tap(find.text('Despesa · expense-1'));
    await tester.pumpAndSettle();
    expect(find.text('Manter deste aparelho'), findsOneWidget);
    expect(find.text('Usar versão da nuvem'), findsOneWidget);
    expect(find.textContaining('"description": "Local"'), findsOneWidget);
  });
}
