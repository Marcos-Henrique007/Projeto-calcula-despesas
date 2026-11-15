import 'package:flutter/material.dart';

import '../models/settlement.dart';

class SettlementCard extends StatelessWidget {
  final Settlement settlement;
  final VoidCallback onSettle;
  final VoidCallback onCopyPix;
  final VoidCallback onWhatsapp;

  const SettlementCard({
    super.key,
    required this.settlement,
    required this.onSettle,
    required this.onCopyPix,
    required this.onWhatsapp,
  });

  @override
  Widget build(BuildContext context) {
    final isSettled =
        settlement.status == SettlementStatus.settled;

    final receives = settlement.to == 'Você';

    final green = const Color(0xFF059669);
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [

          // Status e valor.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSettled
                      ? const Color(0xFFD1FAE5)
                      : receives
                      ? const Color(0xFFECFDF5)
                      : const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isSettled
                      ? 'Liquidado'
                      : receives
                      ? 'Você recebe'
                      : 'Pendente',
                  style: TextStyle(
                    color: isSettled || receives
                        ? green
                        : const Color(0xFFB45309),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const Spacer(),

              Text(
                'R\$ ${settlement.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: receives ? green : colors.onSurface,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Pessoas envolvidas na transferência.
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _Person(
                    name: settlement.from,
                    caption: 'DE',
                  ),
                ),

                const Icon(
                  Icons.trending_flat,
                  color: Colors.grey,
                ),

                Expanded(
                  child: _Person(
                    name: settlement.to,
                    caption: 'PARA',
                    alignEnd: true,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Ações.
          if (isSettled)
            const Row(
              children: [
                Icon(
                  Icons.done_all,
                  color: Color(0xFF059669),
                  size: 18,
                ),
                SizedBox(width: 6),
                Text(
                  'Pagamento confirmado',
                  style: TextStyle(
                    color: Color(0xFF047857),
                    fontSize: 12,
                  ),
                ),
              ],
            )
          else if (receives)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onCopyPix,
                    icon: const Icon(Icons.qr_code),
                    label: const Text('Copiar PIX'),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onWhatsapp,
                    icon: const Icon(Icons.chat),
                    label: const Text('Cobrar'),
                  ),
                ),
              ],
            )
          else
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: onSettle,
                icon: const Icon(Icons.check_circle),
                label: const Text('Marcar como pago'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF059669),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Person extends StatelessWidget {
  final String name;
  final String caption;
  final bool alignEnd;

  const _Person({
    required this.name,
    required this.caption,
    this.alignEnd = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          caption,
          style: const TextStyle(
            fontSize: 10,
            color: Color(0xFF94A3B8),
            fontWeight: FontWeight.bold,
          ),
        ),

        Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}