import 'package:flutter/material.dart';

import '../theme.dart';

enum GasStatus { normal, precaucion, peligro }

class GasCard extends StatelessWidget {
  const GasCard({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.status,
    this.subtitle,
  });

  final String label;
  final num? value;
  final String unit;
  final GasStatus status;
  final String? subtitle;

  Color get _statusColor {
    return switch (status) {
      GasStatus.normal => MinerColors.ok,
      GasStatus.precaucion => MinerColors.warn,
      GasStatus.peligro => MinerColors.danger,
    };
  }

  @override
  Widget build(BuildContext context) {
    final display = value == null ? '—' : value!.toStringAsFixed(2);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                color: _statusColor,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MinerColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: MinerColors.text.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    '$display $unit',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: MinerColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

