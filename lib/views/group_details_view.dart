import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/utils/money_input.dart';
import '../data/services/sync_coordinator.dart';
import '../domain/models/travel_group.dart';
import '../domain/services/financial_calculator.dart';
import '../viewmodels/groups_view_model.dart';
import '../viewmodels/session_view_model.dart';
import '../widgets/theme_mode_button.dart';

class GroupDetailsView extends StatefulWidget {
  const GroupDetailsView({required this.group, super.key});
  final TravelGroup group;

  @override
  State<GroupDetailsView> createState() => _GroupDetailsViewState();
}

class _GroupDetailsViewState extends State<GroupDetailsView> {
  final _membersKey = GlobalKey();
  final _expensesKey = GlobalKey();
  final _settlementsKey = GlobalKey();
  int _selectedDestination = 3;
  String _expenseCategoryFilter = 'Todas';
  String? _expensePayerFilter;
  DateTimeRange? _expenseDateRange;

  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final vm = context.watch<GroupDetailsViewModel>();
    final session = context.watch<SessionViewModel>();
    final filteredExpenses = vm.expenses.where((expense) {
      if (_expenseCategoryFilter != 'Todas' &&
          expense['category'] != _expenseCategoryFilter) {
        return false;
      }
      if (_expensePayerFilter != null &&
          expense['payer_id'] != _expensePayerFilter) {
        return false;
      }
      if (_expenseDateRange != null) {
        final date = DateUtils.dateOnly(DateTime.fromMillisecondsSinceEpoch(
          expense['occurred_at']! as int,
        ));
        final start = DateUtils.dateOnly(_expenseDateRange!.start);
        final end = DateUtils.dateOnly(_expenseDateRange!.end);
        if (date.isBefore(start) || date.isAfter(end)) return false;
      }
      return true;
    }).toList();
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Voltar',
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisSize: MainAxisSize.min, children: [
              Flexible(child: Text(group.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              const Icon(Icons.circle, color: Color(0xFF10B981), size: 7),
            ]),
            Text(
              group.destination.isEmpty ? 'Resumo do grupo' : group.destination,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Atualizar dados',
            onPressed: vm.isLoading
                ? null
                : () async {
                    await context.read<SyncCoordinator>().syncNow();
                    if (context.mounted) await vm.load();
                  },
            icon: const Icon(Icons.history),
          ),
          if (!session.isGuest && group.inviteCode.isNotEmpty)
            IconButton(
              tooltip: 'Copiar código de convite',
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: group.inviteCode));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Código de convite copiado.')),
                  );
                }
              },
              icon: const Icon(Icons.share_outlined),
            ),
          const ThemeModeButton(),
          const SizedBox(width: 4),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await context.read<SyncCoordinator>().syncNow();
                await vm.load();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (session.isGuest)
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Visitante: estes dados são salvos localmente e não são compartilhados.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    )
                  else if (group.isLocalOnly)
                    Card(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Text(
                          'Este grupo foi criado como visitante e continua somente neste aparelho. Gravações nele não são enviadas à nuvem.',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF059669), Color(0xFF065F46)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x18064738),
                          blurRadius: 15,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                group.destination.isEmpty
                                    ? 'RESUMO DO GRUPO'
                                    : group.destination.toUpperCase(),
                                style: const TextStyle(
                                  color: Color(0xFFD1FAE5),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Text(
                                formatCents(
                                  vm.totalCents,
                                  symbol: _symbol(group.currency),
                                ),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${vm.expenseCount} despesas · ${vm.participants.length} participantes',
                                style: const TextStyle(
                                  color: Color(0xFFD1FAE5),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.account_balance_wallet_outlined,
                            color: Colors.white, size: 38),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  if (_selectedDestination == 4) ...[
                    Row(
                    key: _membersKey,
                    children: [
                      Expanded(
                        child: Text('Participantes (${vm.participants.length})',
                            style: Theme.of(context).textTheme.titleMedium),
                      ),
                      TextButton.icon(
                        onPressed: () => _addParticipant(context, vm),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Adicionar'),
                      ),
                    ],
                  ),
                  if (vm.participants.isEmpty)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('Adicione quem participa deste grupo.'),
                      ),
                    )
                  else
                    ...vm.participants.map(
                      (participant) => ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            (participant['name']! as String)
                                .characters
                                .first
                                .toUpperCase(),
                          ),
                        ),
                        title: Text(participant['name']! as String),
                        subtitle: Text(
                          participant['email'] as String? ?? 'Participante local',
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  ],
                  if (_selectedDestination == 0) ...[
                  Text('Despesas', key: _expensesKey, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 155,
                        child: DropdownButtonFormField<String>(
                          initialValue: _expenseCategoryFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Categoria'),
                          items: [
                            'Todas',
                            ...vm.expenses.map((expense) => expense['category']! as String).toSet(),
                          ].map((category) => DropdownMenuItem(
                                value: category,
                                child: Text(category, overflow: TextOverflow.ellipsis),
                              )).toList(),
                          onChanged: (value) => setState(() =>
                              _expenseCategoryFilter = value ?? 'Todas'),
                        ),
                      ),
                      SizedBox(
                        width: 155,
                        child: DropdownButtonFormField<String?>(
                          initialValue: _expensePayerFilter,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Pagador'),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('Todos'),
                            ),
                            ...vm.participants.map((person) => DropdownMenuItem<String?>(
                                  value: person['id']! as String,
                                  child: Text(person['name']! as String,
                                      overflow: TextOverflow.ellipsis),
                                )),
                          ],
                          onChanged: (value) =>
                              setState(() => _expensePayerFilter = value),
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final range = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now().add(const Duration(days: 3650)),
                            initialDateRange: _expenseDateRange,
                          );
                          if (range != null) setState(() => _expenseDateRange = range);
                        },
                        icon: const Icon(Icons.date_range),
                        label: Text(_expenseDateRange == null
                            ? 'Período'
                            : '${_formatDate(_expenseDateRange!.start)} – ${_formatDate(_expenseDateRange!.end)}'),
                      ),
                      if (_expenseDateRange != null)
                        IconButton(
                          tooltip: 'Limpar período',
                          onPressed: () => setState(() => _expenseDateRange = null),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (vm.expenses.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.receipt_long),
                        title: Text('Nenhuma despesa cadastrada'),
                      ),
                    )
                  else if (filteredExpenses.isEmpty)
                    const Card(
                      child: ListTile(title: Text('Nenhuma despesa corresponde aos filtros.')),
                    )
                  else
                    ...filteredExpenses.map((expense) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.receipt_long),
                            title: Text(expense['description']! as String),
                            subtitle: Text(
                              '${expense['category']} · ${_formatDate(DateTime.fromMillisecondsSinceEpoch(expense['occurred_at']! as int))} · pagou ${_payerName(vm, expense['payer_id']! as String)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (expense['receipt_local_path'] is String)
                                  IconButton(
                                    tooltip: 'Ver comprovante',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () => showDialog<void>(
                                      context: context,
                                      builder: (dialogContext) => Dialog(
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Image.file(
                                            File(expense['receipt_local_path']! as String),
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                      ),
                                    ),
                                    icon: const Icon(Icons.attachment, size: 18),
                                  ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(formatCents(
                                      expense['amount_cents']! as int,
                                      symbol: _symbol(group.currency),
                                    )),
                                    if (expense['currency'] != group.currency)
                                      Text(
                                        'Original: ${formatCents(
                                          expense['original_amount_cents']! as int,
                                          symbol: _symbol(expense['currency']! as String),
                                        )}',
                                        style: Theme.of(context).textTheme.labelSmall,
                                      ),
                                  ],
                                ),
                                PopupMenuButton<String>(
                                  onSelected: (action) async {
                                    if (action == 'edit') {
                                      await _editExpense(context, vm, expense);
                                      return;
                                    }
                                    if (action != 'delete') return;
                                    final confirmed = await showDialog<bool>(
                                      context: context,
                                      builder: (dialogContext) => AlertDialog(
                                        title: const Text('Excluir despesa?'),
                                        content: Text('Deseja excluir “${expense['description']}”?'),
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
                                    if (confirmed == true && context.mounted) {
                                      final deleted = await vm.deleteExpense(expense);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text(deleted
                                              ? 'Despesa excluída.'
                                              : vm.error ?? 'Falha ao excluir despesa.')),
                                        );
                                      }
                                    }
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('Excluir'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )),
                  const SizedBox(height: 16),
                  ],
                  if (_selectedDestination == 1) ...[
                    Text('Formas de divisão', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    const Text('Escolha como cada despesa será repartida entre os participantes.'),
                    const SizedBox(height: 12),
                    _divisionModeCard(context, vm, Icons.people_outline, 'Igual entre todos', 'Divide o valor igualmente entre o grupo.', ExpenseDivisionMode.equal),
                    _divisionModeCard(context, vm, Icons.checklist, 'Participantes selecionados', 'Inclui somente as pessoas que você escolher.', ExpenseDivisionMode.selected),
                    _divisionModeCard(context, vm, Icons.payments_outlined, 'Valores exatos', 'Informe quanto cabe a cada pessoa.', ExpenseDivisionMode.exact),
                    _divisionModeCard(context, vm, Icons.percent, 'Por porcentagem', 'Distribui conforme percentuais que somam 100%.', ExpenseDivisionMode.percentages),
                    _divisionModeCard(context, vm, Icons.pie_chart_outline, 'Por cotas ou pesos', 'Divide proporcionalmente às cotas informadas.', ExpenseDivisionMode.weights),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: vm.isBusy ? null : () => _startExpense(context, vm),
                      icon: const Icon(Icons.add),
                      label: const Text('Criar despesa com divisão'),
                    ),
                  ],
                  if (_selectedDestination == 3) ...[
                  Text('Acerto de contas', key: _settlementsKey,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  if (vm.transfers.isEmpty)
                    const Card(
                      child: ListTile(
                        leading: Icon(Icons.check_circle_outline),
                        title: Text('As contas estão equilibradas.'),
                      ),
                    )
                  else
                    ...vm.transfers.map((transfer) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.swap_horiz),
                            title: Text(
                              '${_participantName(vm, transfer.fromParticipantId)} paga ${_participantName(vm, transfer.toParticipantId)}',
                            ),
                            subtitle: const Text('Transferência sugerida'),
                            trailing: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(formatCents(
                                  transfer.cents,
                                  symbol: _symbol(group.currency),
                                )),
                                TextButton(
                                  onPressed: vm.isBusy ? null : () async {
                                    final ok = await vm.recordPayment(
                                      fromParticipantId: transfer.fromParticipantId,
                                      toParticipantId: transfer.toParticipantId,
                                      amountCents: transfer.cents,
                                    );
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(ok
                                            ? 'Pagamento registrado.'
                                            : vm.error ?? 'Falha ao registrar pagamento.')),
                                      );
                                    }
                                  },
                                  child: const Text('Marcar como pago'),
                                ),
                              ],
                            ),
                          ),
                        )),
                  if (vm.settlements.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text('Pagamentos registrados', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...vm.settlements.map((settlement) => ListTile(
                          leading: const Icon(Icons.check_circle_outline),
                          title: Text('${_participantName(vm, settlement['from_participant_id']! as String)} pagou ${_participantName(vm, settlement['to_participant_id']! as String)}'),
                          subtitle: Text(_formatDate(DateTime.fromMillisecondsSinceEpoch(settlement['settled_at']! as int))),
                          trailing: Text(formatCents(
                            settlement['amount_cents']! as int,
                            symbol: _symbol(group.currency),
                          )),
                        )),
                  ],
                  if (_selectedDestination == 3) ...[
                    const SizedBox(height: 18),
                    Text('Saldos individuais', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ...vm.participants.map((participant) {
                      final id = participant['id']! as String;
                      final balance = vm.balanceFor(id);
                      final positive = balance >= 0;
                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text((participant['name']! as String).characters.first.toUpperCase())),
                          title: Text(participant['name']! as String),
                          subtitle: Text(positive ? 'Recebe no total' : 'Tem a pagar'),
                          trailing: Text(
                            '${positive ? '+' : '-'}${formatCents(balance.abs(), symbol: _symbol(group.currency))}',
                            style: TextStyle(color: positive ? const Color(0xFF059669) : const Color(0xFFDC2626), fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () async {
                        try {
                          await vm.shareReport();
                        } catch (error) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Não foi possível gerar o PDF: $error')),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.picture_as_pdf),
                      label: const Text('Exportar fechamento em PDF'),
                    ),
                  ],
                  ],
                  if (vm.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        vm.error!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ),
                ],
              ),
            ),
      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        notchMargin: 7,
        shape: const CircularNotchedRectangle(),
        child: SizedBox(
          height: 58,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(Icons.receipt_long, 'Gastos', 0),
              _navItem(Icons.call_split, 'Divisão', 1),
              const SizedBox(width: 48),
              _navItem(Icons.account_balance, 'Acerto', 3),
              _navItem(Icons.group, 'Membros', 4),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar despesa',
        onPressed: vm.isBusy ? null : () => _startExpense(context, vm),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _navItem(IconData icon, String label, int destination) {
    final selected = _selectedDestination == destination;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _navigateTo(destination),
      child: SizedBox(
        width: 62,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: selected ? const Color(0xFF059669) : const Color(0xFF94A3B8)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: selected ? const Color(0xFF059669) : const Color(0xFF94A3B8), fontWeight: selected ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  void _navigateTo(int destination) {
    setState(() => _selectedDestination = destination);
  }

  Widget _divisionModeCard(
    BuildContext context,
    GroupDetailsViewModel viewModel,
    IconData icon,
    String title,
    String description,
    ExpenseDivisionMode mode,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon, color: const Color(0xFF059669)),
        title: Text(title),
        subtitle: Text(description),
        trailing: const Icon(Icons.chevron_right),
        onTap: viewModel.participants.isEmpty || viewModel.isBusy
            ? null
            : () => _addExpense(context, viewModel, initialDivisionMode: mode),
      ),
    );
  }

  String _payerName(GroupDetailsViewModel vm, String id) =>
      _participantName(vm, id);

  String _participantName(GroupDetailsViewModel vm, String id) {
    for (final participant in vm.participants) {
      if (participant['id'] == id) return participant['name']! as String;
    }
    return 'Participante';
  }

  String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';

  String _symbol(String currency) => switch (currency) {
        'BRL' => 'R\$',
        'USD' => r'\$',
        'EUR' => '€',
        'GBP' => '£',
        'ARS' => r'\$',
        'CLP' => r'\$',
        _ => currency,
      };

  Future<void> _editExpense(
    BuildContext context,
    GroupDetailsViewModel vm,
    Map<String, Object?> expense,
  ) async {
    final description = TextEditingController(
      text: expense['description']! as String,
    );
    final notes = TextEditingController(text: expense['notes'] as String? ?? '');
    final formKey = GlobalKey<FormState>();
    const categories = [
      'Alimentação',
      'Restaurante',
      'Transporte',
      'Posto de gasolina',
      'Hospedagem',
      'Viagens',
      'Passeios',
      'Ingressos',
      'Compras',
      'Saúde e farmácia',
      'Outros',
    ];
    var category = categories.contains(expense['category'])
        ? expense['category']! as String
        : 'Outros';
    var occurredAt = DateTime.fromMillisecondsSinceEpoch(
      expense['occurred_at']! as int,
    );
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Editar despesa'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Informe a descrição.',
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Data da despesa'),
                      subtitle: Text(_formatDate(occurredAt)),
                      onTap: () async {
                        final selected = await showDatePicker(
                          context: dialogContext,
                          initialDate: occurredAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (selected != null) {
                          setDialogState(() => occurredAt = DateTime(
                                selected.year,
                                selected.month,
                                selected.day,
                                occurredAt.hour,
                                occurredAt.minute,
                              ));
                        }
                      },
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Observações',
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'O valor, pagador, cotação, comprovante e divisão permanecem iguais.',
                      style: Theme.of(dialogContext).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
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
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && context.mounted) {
      final ok = await vm.updateExpenseDetails(
        expense: expense,
        description: description.text,
        category: category,
        occurredAt: occurredAt,
        notes: notes.text,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok
                ? 'Despesa atualizada.'
                : vm.error ?? 'Falha ao editar a despesa.'),
          ),
        );
      }
    }
    description.dispose();
    notes.dispose();
  }

  Future<void> _addParticipant(
      BuildContext context, GroupDetailsViewModel vm) async {
    final name = TextEditingController();
    final email = TextEditingController();
    final key = GlobalKey<FormState>();
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Adicionar participante'),
        content: Form(
          key: key,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Nome'),
                validator: (value) => value?.trim().isNotEmpty == true
                    ? null
                    : 'Informe o nome.',
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'E-mail (opcional)'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) Navigator.pop(dialogContext, true);
            },
            child: const Text('Adicionar'),
          ),
        ],
      ),
    );
    if (accepted == true && context.mounted) {
      final ok = await vm.addParticipant(name: name.text, email: email.text);
      if (ok) await vm.load();
    }
    name.dispose();
    email.dispose();
  }

  Future<void> _startExpense(BuildContext context, GroupDetailsViewModel vm) async {
    if (vm.participants.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione participantes na aba Membros antes de lançar despesas.')),
      );
      return;
    }
    await _addExpense(context, vm);
  }

  String? _validateDivision({
    required ExpenseDivisionMode mode,
    required int? totalCents,
    required Set<String> selectedIds,
    required Map<String, TextEditingController> inputControllers,
  }) {
    if (totalCents == null || totalCents <= 0) return 'Informe um valor total válido.';
    if (mode == ExpenseDivisionMode.selected && selectedIds.isEmpty) {
      return 'Selecione ao menos uma pessoa para dividir.';
    }
    if (mode == ExpenseDivisionMode.equal || mode == ExpenseDivisionMode.selected) {
      return null;
    }

    final parsed = <String, int>{};
    for (final entry in inputControllers.entries) {
      final value = _parseDivisionInput(mode, entry.value.text);
      if (value == null || value < 0) {
        return 'Confira os valores informados para cada participante.';
      }
      parsed[entry.key] = value;
    }

    switch (mode) {
      case ExpenseDivisionMode.exact:
        final sum = parsed.values.fold<int>(0, (total, value) => total + value);
        return sum == totalCents
            ? null
            : 'Os valores devem somar ${formatCents(totalCents)}.';
      case ExpenseDivisionMode.percentages:
        final sum = parsed.values.fold<int>(0, (total, value) => total + value);
        return sum == 10000 ? null : 'As porcentagens devem somar 100%.';
      case ExpenseDivisionMode.weights:
        final sum = parsed.values.fold<int>(0, (total, value) => total + value);
        return sum > 0 ? null : 'Informe ao menos uma cota maior que zero.';
      case ExpenseDivisionMode.equal:
      case ExpenseDivisionMode.selected:
        return null;
    }
  }

  Future<void> _addExpense(
    BuildContext context,
    GroupDetailsViewModel vm, {
    ExpenseDivisionMode initialDivisionMode = ExpenseDivisionMode.equal,
  }) async {
    final description = TextEditingController();
    final amount = TextEditingController();
    final notes = TextEditingController();
    final exchangeRate = TextEditingController();
    final key = GlobalKey<FormState>();
    final imagePicker = ImagePicker();
    var occurredAt = DateTime.now();
    var expenseCurrency = widget.group.currency;
    XFile? selectedReceipt;
    final participants = vm.participants;
    final inputControllers = {
      for (final person in participants)
        person['id']! as String: TextEditingController(),
    };
    const categories = [
      'Alimentação',
      'Restaurante',
      'Transporte',
      'Posto de gasolina',
      'Hospedagem',
      'Viagens',
      'Passeios',
      'Ingressos',
      'Compras',
      'Saúde e farmácia',
      'Outros',
    ];
    var category = categories.first;
    var payerId = participants.first['id']! as String;
    var divisionMode = initialDivisionMode;
    final selectedIds = <String>{};
    String? divisionError;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Nova despesa'),
          content: Form(
            key: key,
            child: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: description,
                      decoration: const InputDecoration(labelText: 'Descrição'),
                      validator: (value) => value?.trim().isNotEmpty == true
                          ? null
                          : 'Informe a descrição.',
                    ),
                    TextFormField(
                      controller: amount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(labelText: 'Valor em $expenseCurrency'),
                      validator: (value) {
                        final cents = parseBrazilianMoneyToCents(value ?? '');
                        return cents != null && cents > 0
                            ? null
                            : 'Informe um valor maior que zero.';
                      },
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: expenseCurrency,
                      decoration: const InputDecoration(labelText: 'Moeda da despesa'),
                      items: const ['BRL', 'USD', 'EUR', 'GBP', 'ARS', 'CLP']
                          .map((code) => DropdownMenuItem(value: code, child: Text(code)))
                          .toList(),
                      onChanged: (value) => setDialogState(() {
                        expenseCurrency = value ?? widget.group.currency;
                        exchangeRate.clear();
                      }),
                    ),
                    if (expenseCurrency != widget.group.currency)
                      TextFormField(
                        controller: exchangeRate,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Cotação manual (1 $expenseCurrency em ${widget.group.currency})',
                          helperText: 'Deixe vazio para buscar a cotação atual ou usar a última salva.',
                        ),
                      ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.calendar_today_outlined),
                      title: const Text('Data da despesa'),
                      subtitle: Text(_formatDate(occurredAt)),
                      trailing: const Icon(Icons.edit_calendar_outlined),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: occurredAt,
                          firstDate: DateTime(2000),
                          lastDate: DateTime.now().add(const Duration(days: 3650)),
                        );
                        if (picked != null) {
                          setDialogState(() => occurredAt = DateTime(
                                picked.year, picked.month, picked.day,
                                occurredAt.hour, occurredAt.minute,
                              ));
                        }
                      },
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Comprovante (opcional)',
                          style: Theme.of(dialogContext).textTheme.labelLarge),
                    ),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () async {
                            final image = await imagePicker.pickImage(
                              source: ImageSource.gallery,
                              imageQuality: 85,
                              maxWidth: 1600,
                            );
                            if (image != null) {
                              setDialogState(() => selectedReceipt = image);
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Galeria'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final image = await imagePicker.pickImage(
                              source: ImageSource.camera,
                              imageQuality: 85,
                              maxWidth: 1600,
                            );
                            if (image != null) {
                              setDialogState(() => selectedReceipt = image);
                            }
                          },
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Câmera'),
                        ),
                      ],
                    ),
                    if (selectedReceipt != null)
                      Stack(
                        alignment: Alignment.topRight,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(selectedReceipt!.path),
                              height: 150,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          IconButton.filledTonal(
                            tooltip: 'Remover comprovante',
                            onPressed: () => setDialogState(() => selectedReceipt = null),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    DropdownButtonFormField<ExpenseDivisionMode>(
                      initialValue: divisionMode,
                      decoration: const InputDecoration(labelText: 'Forma de divisão'),
                      items: const [
                        DropdownMenuItem(value: ExpenseDivisionMode.equal, child: Text('Igual entre todos')),
                        DropdownMenuItem(value: ExpenseDivisionMode.selected, child: Text('Entre selecionados')),
                        DropdownMenuItem(value: ExpenseDivisionMode.exact, child: Text('Valores exatos')),
                        DropdownMenuItem(value: ExpenseDivisionMode.percentages, child: Text('Por porcentagem')),
                        DropdownMenuItem(value: ExpenseDivisionMode.weights, child: Text('Por cotas/pesos')),
                      ],
                      onChanged: (value) => setDialogState(() {
                        divisionMode = value ?? ExpenseDivisionMode.equal;
                        divisionError = null;
                      }),
                    ),
                    if (divisionMode == ExpenseDivisionMode.selected) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text('Selecione quem divide a despesa'),
                        ),
                      ),
                      ...participants.map((person) {
                        final id = person['id']! as String;
                        return CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(person['name']! as String),
                          value: selectedIds.contains(id),
                          onChanged: (checked) => setDialogState(() {
                            if (checked == true) {
                              selectedIds.add(id);
                            } else {
                              selectedIds.remove(id);
                            }
                            divisionError = null;
                          }),
                        );
                      }),
                      if (divisionError != null)
                        Text(divisionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    ],
                    if (divisionMode == ExpenseDivisionMode.exact ||
                        divisionMode == ExpenseDivisionMode.percentages ||
                        divisionMode == ExpenseDivisionMode.weights) ...[
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.only(top: 12, bottom: 6),
                          child: Text('Informe o valor para cada participante'),
                        ),
                      ),
                      ...participants.map((person) {
                        final id = person['id']! as String;
                        final hint = switch (divisionMode) {
                          ExpenseDivisionMode.exact => 'Valor',
                          ExpenseDivisionMode.percentages => 'Percentual',
                          ExpenseDivisionMode.weights => 'Cotas',
                          _ => '',
                        };
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: TextFormField(
                            controller: inputControllers[id],
                            keyboardType: TextInputType.numberWithOptions(
                              decimal: divisionMode != ExpenseDivisionMode.weights,
                            ),
                            decoration: InputDecoration(
                              labelText: '${person['name']} · $hint${divisionMode == ExpenseDivisionMode.exact ? ' ($expenseCurrency)' : ''}',
                            ),
                            validator: (value) => _parseDivisionInput(
                                      divisionMode, value ?? '',
                                    ) != null
                                ? null
                                : 'Informe um $hint válido ou zero.',
                          ),
                        );
                      }),
                    ],
                    if (divisionError != null && divisionMode != ExpenseDivisionMode.selected)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(divisionError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                      ),
                    DropdownButtonFormField<String>(
                      initialValue: payerId,
                      decoration: const InputDecoration(labelText: 'Quem pagou?'),
                      items: participants
                          .map((person) => DropdownMenuItem(
                                value: person['id']! as String,
                                child: Text(person['name']! as String),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => payerId = value ?? payerId),
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Categoria'),
                      items: categories
                          .map((item) => DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    TextFormField(
                      controller: notes,
                      maxLines: 3,
                      maxLength: 1000,
                      decoration: const InputDecoration(
                        labelText: 'Observações (opcional)',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                if (!key.currentState!.validate()) return;
                final totalCents = parseBrazilianMoneyToCents(amount.text);
                final validationMessage = _validateDivision(
                  mode: divisionMode,
                  totalCents: totalCents,
                  selectedIds: selectedIds,
                  inputControllers: inputControllers,
                );
                if (validationMessage != null) {
                  setDialogState(() => divisionError = validationMessage);
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: const Text('Salvar'),
            ),
          ],
        ),
      ),
    );

    if (accepted == true && context.mounted) {
      final cents = parseBrazilianMoneyToCents(amount.text);
      final customValues = <String, int>{};
      if (divisionMode == ExpenseDivisionMode.exact ||
          divisionMode == ExpenseDivisionMode.percentages ||
          divisionMode == ExpenseDivisionMode.weights) {
        for (final entry in inputControllers.entries) {
          customValues[entry.key] =
              _parseDivisionInput(divisionMode, entry.value.text) ?? 0;
        }
      }
      if (cents != null) {
        final ok = await vm.addExpense(
          description: description.text,
          amountCents: cents,
          currency: expenseCurrency,
          manualExchangeRate: exchangeRate.text,
          payerParticipantId: payerId,
          category: category,
          occurredAt: occurredAt,
          receiptSourcePath: selectedReceipt?.path,
          divisionMode: divisionMode,
          selectedParticipantIds: selectedIds.toList(),
          customValues: customValues,
          notes: notes.text,
        );
        if (ok) {
          await vm.load();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Despesa salva no dispositivo.')),
            );
          }
        } else if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(vm.error ?? 'Não foi possível salvar.')),
          );
        }
      }
    }
    description.dispose();
    amount.dispose();
    notes.dispose();
    exchangeRate.dispose();
    for (final controller in inputControllers.values) {
      controller.dispose();
    }
  }

  int? _parseDivisionInput(ExpenseDivisionMode mode, String input) {
    final value = input.trim();
    if (value.isEmpty) return 0;
    if (mode == ExpenseDivisionMode.exact) {
      return parseBrazilianMoneyToCents(value);
    }
    if (mode == ExpenseDivisionMode.weights) return int.tryParse(value);
    final normalized = value.contains(',')
        ? value.replaceAll('.', '').replaceFirst(',', '.')
        : value;
    final parts = normalized.split('.');
    if (parts.length > 2 || (parts.length == 2 && parts.last.length > 2)) {
      return null;
    }
    final whole = int.tryParse(parts.first);
    final decimals = parts.length == 1
        ? 0
        : int.tryParse(parts.last.padRight(2, '0'));
    if (whole == null || decimals == null) return null;
    return whole * 100 + decimals;
  }
}
