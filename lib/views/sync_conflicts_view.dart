import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/sync_outbox_repository.dart';
import '../viewmodels/sync_conflicts_view_model.dart';

class SyncConflictsView extends StatelessWidget {
  const SyncConflictsView({
    required this.repository,
    required this.syncNow,
    super.key,
  });

  final SyncOutboxRepository repository;
  final Future<void> Function() syncNow;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
        create: (_) => SyncConflictsViewModel(
          repository: repository,
          syncNow: syncNow,
        )..load(),
        child: const _SyncConflictsContent(),
      );
}

class _SyncConflictsContent extends StatelessWidget {
  const _SyncConflictsContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SyncConflictsViewModel>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Conflitos de sincronização'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            onPressed: viewModel.isLoading ? null : viewModel.load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: viewModel.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: viewModel.load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (viewModel.error != null)
                    Card(
                      color: Theme.of(context).colorScheme.errorContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(viewModel.error!),
                      ),
                    ),
                  if (viewModel.conflicts.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.cloud_done_outlined),
                        title: Text('Nenhum conflito pendente'),
                        subtitle: Text('As alterações locais estão sincronizadas.'),
                      ),
                    )
                  else ...[
                    const Text(
                      'O mesmo registro foi alterado em mais de um dispositivo. Escolha qual versão manter.',
                    ),
                    const SizedBox(height: 12),
                    ...viewModel.conflicts.map((conflict) {
                      final busy = viewModel.busyOperationId == conflict.operationId;
                      final label = switch (conflict.entityType) {
                        'group' => 'Grupo',
                        'expense' => 'Despesa',
                        'participant' => 'Participante',
                        'settlement' => 'Acerto',
                        _ => conflict.entityType,
                      };
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: ExpansionTile(
                          leading: const Icon(Icons.sync_problem_outlined),
                          title: Text('$label · ${conflict.entityId}'),
                          subtitle: Text(
                            'Detectado em ${_formatDate(conflict.detectedAt)}',
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Versão deste aparelho',
                                  style: Theme.of(context).textTheme.titleSmall),
                            ),
                            _PayloadPreview(payload: conflict.localPayload),
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text('Versão na nuvem',
                                  style: Theme.of(context).textTheme.titleSmall),
                            ),
                            _PayloadPreview(payload: conflict.remotePayload),
                            const SizedBox(height: 16),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                OutlinedButton.icon(
                                  onPressed: busy || viewModel.busyOperationId != null
                                      ? null
                                      : () => _confirmResolution(
                                            context,
                                            viewModel,
                                            conflict,
                                            useLocal: true,
                                          ),
                                  icon: const Icon(Icons.phone_android),
                                  label: const Text('Manter deste aparelho'),
                                ),
                                FilledButton.icon(
                                  onPressed: busy || viewModel.busyOperationId != null
                                      ? null
                                      : () => _confirmResolution(
                                            context,
                                            viewModel,
                                            conflict,
                                            useLocal: false,
                                          ),
                                  icon: const Icon(Icons.cloud_download_outlined),
                                  label: const Text('Usar versão da nuvem'),
                                ),
                                if (busy)
                                  const Padding(
                                    padding: EdgeInsets.all(12),
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
    );
  }

  Future<void> _confirmResolution(
    BuildContext context,
    SyncConflictsViewModel viewModel,
    SyncConflict conflict, {
    required bool useLocal,
  }) async {
    final keep = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(useLocal ? 'Manter a versão local?' : 'Usar a versão da nuvem?'),
        content: Text(
          useLocal
              ? 'A versão deste aparelho será reenviada sobre a versão remota atual.'
              : 'A versão local pendente será substituída pelos dados remotos deste registro.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
    if (keep != true || !context.mounted) return;
    final success = useLocal
        ? await viewModel.useLocalVersion(conflict)
        : await viewModel.useRemoteVersion(conflict);
    if (context.mounted && success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Conflito resolvido.')),
      );
    }
  }

  String _formatDate(int milliseconds) {
    final date = DateTime.fromMillisecondsSinceEpoch(milliseconds);
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

class _PayloadPreview extends StatelessWidget {
  const _PayloadPreview({required this.payload});

  final Map<String, Object?> payload;

  @override
  Widget build(BuildContext context) {
    final display = const JsonEncoder.withIndent('  ').convert(payload);
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 220),
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: SelectableText(
          display,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
              ),
        ),
      ),
    );
  }
}
