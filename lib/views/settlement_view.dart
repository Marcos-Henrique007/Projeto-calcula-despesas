import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../viewmodels/settlement_view_model.dart';
import '../models/settlement.dart';

import '../widgets/settlement_card.dart';
import '../widgets/balance_card.dart';
import '../widgets/category_card.dart';

class SettlementView extends StatelessWidget {
  const SettlementView({super.key});

  @override
  Widget build(BuildContext context) {

    final viewModel = context.watch<SettlementViewModel>();

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),

      appBar: AppBar(
        backgroundColor: const Color(0xFFF8F9FA),
        elevation: 0,

        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Text(
                  'Acerto de Contas',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                SizedBox(width: 7),

                Icon(
                  Icons.circle,
                  color: Color(0xFF10B981),
                  size: 7,
                ),
              ],
            ),

            Text(
              viewModel.tripName,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),

        actions: [
          IconButton(
            onPressed: () {
              _showMessage(context, 'Histórico sincronizado');
            },
            icon: const Icon(Icons.history),
          ),

          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              backgroundColor: Color(0xFFD1FAE5),
              child: Text(
                'CH',
                style: TextStyle(
                  color: Color(0xFF047857),
                  fontSize: 11,
                ),
              ),
            ),
          ),
        ],
      ),

      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 30),

        children: [

          // Resumo financeiro.
          _buildSummary(viewModel),

          const SizedBox(height: 22),

          // Liquidações.
          _buildSectionTitle(
            Icons.swap_horiz,
            'Quem paga a quem',
            '${viewModel.settlements.length} liquidações',
          ),

          const SizedBox(height: 12),

          ...viewModel.settlements.map((settlement) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),

              child: SettlementCard(
                settlement: settlement,

                onSettle: () {
                  viewModel.markAsSettled(settlement.id);

                  _showMessage(
                    context,
                    'Pagamento registrado com sucesso!',
                  );
                },

                onCopyPix: () {
                  _showMessage(
                    context,
                    'Chave PIX copiada!',
                  );
                },

                onWhatsapp: () {
                  _showMessage(
                    context,
                    'Abrindo WhatsApp...',
                  );
                },
              ),
            );
          }),

          const SizedBox(height: 12),

          // Saldos individuais.
          _buildSectionTitle(
            Icons.account_balance_wallet_outlined,
            'Saldos Individuais Líquidos',
            '${viewModel.balances.length} integrantes',
          ),

          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
              ),
            ),

            child: Column(
              children: [
                for (int i = 0; i < viewModel.balances.length; i++) ...[
                  BalanceCard(
                    balance: viewModel.balances[i],
                  ),

                  if (i != viewModel.balances.length - 1)
                    const Divider(height: 1),
                ],
              ],
            ),
          ),

          const SizedBox(height: 22),

          // Despesas por categoria.
          _buildSectionTitle(
            Icons.pie_chart_outline,
            'Despesas por Categoria',
            'R\$ 14.850 total',
          ),

          const SizedBox(height: 12),

          CategoryCard(
            categories: viewModel.categories,
          ),

          const SizedBox(height: 22),

          // Exportar relatório.
          SizedBox(
            height: 50,
            child: FilledButton.icon(
              onPressed: () {
                _showMessage(
                  context,
                  'Gerando relatório PDF...',
                );
              },

              icon: const Icon(Icons.picture_as_pdf),

              label: const Text(
                'Exportar Relatório PDF',
              ),

              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF059669),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Fechar grupo.
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {
                _confirmClose(context, viewModel);
              },

              icon: const Icon(Icons.lock_outline),

              label: const Text('Fechar Grupo'),
            ),
          ),
        ],
      ),

      bottomNavigationBar: _buildBottomNavigation(context),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showMessage(context, 'Adicionar novo gasto');
        },

        backgroundColor: const Color(0xFF059669),
        foregroundColor: Colors.white,

        child: const Icon(Icons.add),
      ),

      floatingActionButtonLocation:
      FloatingActionButtonLocation.centerDocked,
    );
  }

  // Cartão de resumo.
  Widget _buildSummary(SettlementViewModel viewModel) {

    return Container(
      padding: const EdgeInsets.all(20),

      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF059669),
            Color(0xFF0F766E),
            Color(0xFF065F46),
          ],
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

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [

          Row(
            children: [
              _buildTag('✦ DÍVIDAS SIMPLIFICADAS'),

              const Spacer(),

              _buildTag('8 PIX evitados'),
            ],
          ),

          const SizedBox(height: 16),

          const Text(
            'Apenas 3 transferências para zerar todo o grupo',

            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            'Em vez de 11 pagamentos cruzados, o algoritmo recalculou a rota financeira otimizada para o grupo.',

            style: TextStyle(
              color: Color(0xFFD1FAE5),
              fontSize: 12,
              height: 1.5,
            ),
          ),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: _buildMetric(
                  'TOTAL A LIQUIDAR',
                  _money(viewModel.totalToSettle),
                ),
              ),

              const SizedBox(width: 8),

              Expanded(
                child: _buildMetric(
                  'SEU SALDO A RECEBER',
                  '+${_money(600)}',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildMetric(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        children: [
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFA7F3D0),
              fontSize: 9,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // Título das seções.
  Widget _buildSectionTitle(
      IconData icon,
      String title,
      String trailing,
      ) {
    return Row(
      children: [
        Icon(
          icon,
          color: const Color(0xFF059669),
          size: 21,
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        Text(
          trailing,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }

  String _money(double value) {
    return 'R\$ ${value.toStringAsFixed(2).replaceAll('.', ',')}';
  }

  // Confirmação de fechamento.
  Future<void> _confirmClose(
      BuildContext context,
      SettlementViewModel viewModel,
      ) async {

    final confirmed = await showDialog<bool>(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text('Fechar grupo?'),

          content: const Text(
            'Deseja fechar as contas do grupo? Todas as liquidações serão marcadas como concluídas.',
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },

              child: const Text('Cancelar'),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(context, true);
              },

              child: const Text('Fechar grupo'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && context.mounted) {
      viewModel.closeGroup();

      _showMessage(
        context,
        'Grupo fechado com sucesso!',
      );
    }
  }

  // Notificações.
  static void _showMessage(
      BuildContext context,
      String message,
      ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // Barra inferior.
  Widget _buildBottomNavigation(BuildContext context) {

    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      notchMargin: 7,

      shape: const CircularNotchedRectangle(),

      child: SizedBox(
        height: 56,

        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,

          children: [
            _navItem(
              context,
              Icons.receipt_long,
              'Gastos',
            ),

            _navItem(
              context,
              Icons.call_split,
              'Divisão',
            ),

            const SizedBox(width: 42),

            _navItem(
              context,
              Icons.account_balance,
              'Acerto',
              selected: true,
            ),

            _navItem(
              context,
              Icons.group,
              'Membros',
            ),
          ],
        ),
      ),
    );
  }

  Widget _navItem(
      BuildContext context,
      IconData icon,
      String label, {
        bool selected = false,
      }) {
    return InkWell(
      onTap: () {
        _showMessage(
          context,
          'Navegação $label ainda não implementada.',
        );
      },

      child: SizedBox(
        width: 58,

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              icon,
              size: 21,
              color: selected
                  ? const Color(0xFF059669)
                  : const Color(0xFF94A3B8),
            ),

            const SizedBox(height: 2),

            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: selected
                    ? const Color(0xFF059669)
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}