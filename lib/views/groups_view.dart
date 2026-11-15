import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/expense_repository.dart';
import '../data/repositories/group_repository.dart';
import '../data/repositories/sync_outbox_repository.dart';
import '../data/services/sync_coordinator.dart';
import '../data/services/receipt_storage_service.dart';
import '../data/services/group_report_service.dart';
import '../data/services/exchange_rate_service.dart';
import '../domain/models/travel_group.dart';
import '../domain/services/financial_calculator.dart';
import '../viewmodels/groups_view_model.dart';
import '../viewmodels/session_view_model.dart';
import 'auth_view.dart';
import 'group_details_view.dart';
import 'sync_conflicts_view.dart';
import '../widgets/theme_mode_button.dart';

class GroupsView extends StatelessWidget {
  const GroupsView({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    return ChangeNotifierProvider(
      key: ValueKey(session.actorId),
      create: (context) => GroupsViewModel(
        repository: context.read<GroupRepository>(),
        actorId: session.actorId,
        syncEnabled: !session.isGuest,
        syncNow: () => context.read<SyncCoordinator>().syncNow(),
      )..load(),
      child: const _GroupsContent(),
    );
  }
}

class _GroupsContent extends StatefulWidget {
  const _GroupsContent();

  @override
  State<_GroupsContent> createState() => _GroupsContentState();
}

class _GroupsContentState extends State<_GroupsContent> {
  SyncCoordinator? _syncCoordinator;
  bool _wasSyncing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coordinator = context.read<SyncCoordinator>();
    if (_syncCoordinator == coordinator) return;
    _syncCoordinator?.removeListener(_onSyncChanged);
    _syncCoordinator = coordinator;
    _wasSyncing = coordinator.isSyncing;
    coordinator.addListener(_onSyncChanged);
  }

  void _onSyncChanged() {
    final coordinator = _syncCoordinator;
    if (coordinator == null) return;
    if (_wasSyncing && !coordinator.isSyncing) {
      context.read<GroupsViewModel>().reloadLocal();
    }
    _wasSyncing = coordinator.isSyncing;
  }

  @override
  void dispose() {
    _syncCoordinator?.removeListener(_onSyncChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionViewModel>();
    final vm = context.watch<GroupsViewModel>();
    final sync = context.watch<SyncCoordinator>();
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFD1FAE5),
              child: Icon(Icons.travel_explore, color: Color(0xFF047857)),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('DividiTrip'),
                Text(
                  session.isGuest ? 'Modo visitante' : 'Conta sincronizada',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          if (!session.isGuest)
            IconButton(
              tooltip: 'Entrar em grupo com código',
              onPressed: () => _joinGroup(context),
              icon: const Icon(Icons.group_add_outlined),
            ),
          if (!session.isGuest)
            IconButton(
              tooltip: 'Conflitos de sincronização',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SyncConflictsView(
                    repository: context.read<SyncOutboxRepository>(),
                    syncNow: () => context.read<SyncCoordinator>().syncNow(),
                  ),
                ),
              ),
              icon: const Icon(Icons.sync_problem_outlined),
            ),
          const ThemeModeButton(),
          if (session.isGuest)
            TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AuthView()),
              ),
              child: const Text('Entrar'),
            )
          else
            IconButton(
              tooltip: 'Sair',
              onPressed: session.signOut,
              icon: const Icon(Icons.logout),
            ),
        ],
      ),
      body: Column(
        children: [
          if (!session.isGuest && (sync.isSyncing || sync.lastError != null))
            Material(
              color: sync.lastError == null
                  ? Theme.of(context).colorScheme.surfaceContainerLow
                  : Theme.of(context).colorScheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 12, 8),
                child: Row(
                  children: [
                    if (sync.isSyncing)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.cloud_off_outlined),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(sync.lastError ?? 'Sincronizando seus dados...'),
                    ),
                    if (!sync.isSyncing)
                      TextButton(
                        onPressed: () async {
                          await sync.syncNow();
                          await vm.reloadLocal();
                        },
                        child: const Text('Tentar'),
                      ),
                  ],
                ),
              ),
            ),
          if (session.isGuest)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: Theme.of(context).colorScheme.surfaceContainerLow,
              child: Row(
                children: [
                  Icon(Icons.phone_android, color: Color(0xFF047857)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Visitante: grupos e despesas ficam neste aparelho. Entre para compartilhar e sincronizar.',
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF059669), Color(0xFF065F46)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0x33FFFFFF),
                    child: Icon(Icons.luggage_outlined, color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Olá, ${session.displayName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${vm.groups.length} grupos de viagem',
                          style: const TextStyle(color: Color(0xFFD1FAE5)),
                        ),
                      ],
                    ),
                  ),
                  if (!session.isGuest)
                    IconButton(
                      tooltip: 'Sincronizar agora',
                      onPressed: () =>
                          context.read<SyncCoordinator>().syncNow(),
                      icon: const Icon(Icons.sync, color: Colors.white),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.error != null
                    ? Center(child: Text(vm.error!))
                    : vm.groups.isEmpty
                        ? const Center(
                            child: Text('Crie seu primeiro grupo para começar.'),
                          )
                        : RefreshIndicator(
                            onRefresh: vm.load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: vm.groups.length,
                              itemBuilder: (context, index) {
                                final group = vm.groups[index];
                                return Card(
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      child: Icon(Icons.luggage_outlined),
                                    ),
                                    title: Text(group.name),
                                    subtitle: Text(
                                      [group.destination, ...group.types, group.currency]
                                          .where((text) => text.isNotEmpty)
                                          .join(' · '),
                                    ),
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(group.isLocalOnly
                                            ? Icons.cloud_off_outlined
                                            : Icons.chevron_right),
                                        if (group.createdBy == session.actorId)
                                          PopupMenuButton<String>(
                                            tooltip: 'Opções do grupo',
                                            onSelected: (action) {
                                              if (action == 'edit') {
                                                _createGroup(context, existingGroup: group);
                                              } else if (action == 'delete') {
                                                _deleteGroup(context, vm, group);
                                              }
                                            },
                                            itemBuilder: (_) => const [
                                              PopupMenuItem(
                                                value: 'edit',
                                                child: Text('Editar grupo'),
                                              ),
                                              PopupMenuItem(
                                                value: 'delete',
                                                child: Text('Excluir grupo'),
                                              ),
                                            ],
                                          ),
                                      ],
                                    ),
                                    onTap: () => _openGroup(context, group),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: vm.isBusy ? null : () => _createGroup(context),
        icon: const Icon(Icons.add),
        label: const Text('Novo grupo'),
      ),
    );
  }

  Future<void> _deleteGroup(
    BuildContext context,
    GroupsViewModel viewModel,
    TravelGroup group,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir grupo?'),
        content: Text('O grupo “${group.name}” e suas despesas serão removidos deste aparelho.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final deleted = await viewModel.deleteGroup(group);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(deleted
            ? 'Grupo excluído.'
            : viewModel.error ?? 'Falha ao excluir o grupo.')),
      );
    }
  }

  Future<void> _joinGroup(BuildContext context) async {
    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Entrar em um grupo'),
        content: TextField(
          controller: codeController,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(labelText: 'Código de convite'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, codeController.text),
            child: const Text('Entrar'),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (code == null || !context.mounted) return;
    final syncCoordinator = context.read<SyncCoordinator>();
    final groupsViewModel = context.read<GroupsViewModel>();
    try {
      await syncCoordinator.joinByInviteCode(code);
      if (!context.mounted) return;
      await groupsViewModel.load();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Você entrou no grupo e os dados foram sincronizados.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível entrar no grupo: $error')),
        );
      }
    }
  }

  Future<void> _createGroup(
    BuildContext context, {
    TravelGroup? existingGroup,
  }) async {
    final formKey = GlobalKey<FormState>();
    final name = TextEditingController(text: existingGroup?.name ?? '');
    final destination = TextEditingController(text: existingGroup?.destination ?? '');
    final description = TextEditingController(text: existingGroup?.description ?? '');
    const availableTypes = ['Viagem', 'Evento', 'Passeio', 'Restaurante', 'Compras', 'Outro'];
    final selectedTypes = <String>{...?existingGroup?.types};
    var currency = existingGroup?.currency ?? 'BRL';
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(existingGroup == null ? 'Criar grupo' : 'Editar grupo'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => value?.trim().isNotEmpty == true
                      ? null
                      : 'Informe o nome do grupo.',
                ),
                TextField(
                  controller: destination,
                  decoration: const InputDecoration(labelText: 'Destino'),
                ),
                TextField(
                  controller: description,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 4),
                    child: Text('Tipo de grupo (selecione todos que se aplicam)',
                        style: Theme.of(dialogContext).textTheme.labelLarge),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  children: availableTypes.map((type) {
                    final selected = selectedTypes.contains(type);
                    return FilterChip(
                      label: Text(type),
                      selected: selected,
                      onSelected: (value) => setDialogState(() {
                        if (value) {
                          selectedTypes.add(type);
                        } else {
                          selectedTypes.remove(type);
                        }
                      }),
                    );
                  }).toList(),
                ),
                DropdownButtonFormField<String>(
                  initialValue: currency,
                  decoration: const InputDecoration(labelText: 'Moeda'),
                  items: const ['BRL', 'USD', 'EUR', 'GBP', 'ARS', 'CLP']
                      .map((code) => DropdownMenuItem(
                            value: code,
                            child: Text(code),
                          ))
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => currency = value ?? 'BRL'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, true);
                }
              },
              child: Text(existingGroup == null ? 'Criar' : 'Salvar'),
            ),
          ],
        ),
      ),
    );
    if (accepted == true && context.mounted) {
      final viewModel = context.read<GroupsViewModel>();
      final ok = existingGroup == null
          ? await viewModel.create(
              name: name.text,
              destination: destination.text,
              description: description.text,
              currency: currency,
              types: selectedTypes.toList(),
              creatorName: context.read<SessionViewModel>().displayName,
              creatorEmail: context.read<SessionViewModel>().user?.email,
            )
          : await viewModel.updateGroup(
              group: existingGroup,
              name: name.text,
              destination: destination.text,
              description: description.text,
              currency: currency,
              types: selectedTypes.toList(),
            );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? existingGroup == null
                  ? 'Grupo criado.'
                  : 'Grupo atualizado.'
              : viewModel.error ?? 'Falha ao salvar o grupo.'),
        ),
      );
    }
    name.dispose();
    destination.dispose();
    description.dispose();
  }

  void _openGroup(BuildContext context, TravelGroup group) {
    final session = context.read<SessionViewModel>();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider(
          create: (context) => GroupDetailsViewModel(
            groupRepository: context.read<GroupRepository>(),
            expenseRepository: context.read<ExpenseRepository>(),
            receiptStorage: context.read<ReceiptStorageService>(),
            reportService: context.read<GroupReportService>(),
            exchangeRateService: context.read<ExchangeRateService>(),
            connectivity: context.read<Connectivity>(),
            calculator: context.read<FinancialCalculator>(),
            group: group,
            actorId: session.actorId,
            syncEnabled: !session.isGuest && !group.isLocalOnly,
            syncNow: () => context.read<SyncCoordinator>().syncNow(),
          )..load(),
          child: GroupDetailsView(group: group),
        ),
      ),
    );
  }
}
