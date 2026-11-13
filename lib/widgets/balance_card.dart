import 'package:flutter/material.dart';

import '../models/member_balance.dart';

class BalanceCard extends StatelessWidget {
  final MemberBalance balance;

  const BalanceCard({
    super.key,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    final positive = balance.isCreditor;

    final color = positive
        ? const Color(0xFF059669)
        : const Color(0xFFF43F5E);

    final formatted =
    balance.balance.abs().toStringAsFixed(2).replaceAll('.', ',');

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 13,
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: positive
                ? const Color(0xFFD1FAE5)
                : const Color(0xFFF1F5F9),
            child: Text(
              balance.initials,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  balance.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),

                Text(
                  positive ? 'Recebe no total' : 'Tem a pagar',
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),

          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${positive ? '+' : '-'}R\$ $formatted',
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),

              Text(
                positive ? 'POSITIVO' : 'A PAGAR',
                style: const TextStyle(
                  color: Color(0xFF94A3B8),
                  fontSize: 9,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}