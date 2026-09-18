import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
import 'alertas_provider.dart';

class AlertasScreen extends StatefulWidget {
  const AlertasScreen({super.key});

  @override
  State<AlertasScreen> createState() => _AlertasScreenState();
}

class _AlertasScreenState extends State<AlertasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<AlertasProvider>();
      p.load();
      p.startPolling();
    });
  }

  @override
  void dispose() {
    context.read<AlertasProvider>().stopPolling();
    super.dispose();
  }

  Future<void> _openCreateDialog() async {
    final zoneCtrl = TextEditingController();
    final msgCtrl = TextEditingController();
    String level = 'warn';

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: MinerColors.card,
              title: const Text('Crear nueva alerta', style: TextStyle(color: MinerColors.text)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: zoneCtrl,
                      decoration: const InputDecoration(labelText: 'Zona'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: msgCtrl,
                      minLines: 2,
                      maxLines: 4,
                      decoration: const InputDecoration(labelText: 'Mensaje'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      key: ValueKey('level-$level'),
                      initialValue: level,
                      items: const [
                        DropdownMenuItem(value: 'info', child: Text('info')),
                        DropdownMenuItem(value: 'warn', child: Text('warn')),
                        DropdownMenuItem(value: 'danger', child: Text('danger')),
                      ],
                      onChanged: (v) {
                        setState(() => level = v ?? level);
                      },
                      decoration: const InputDecoration(labelText: 'Nivel'),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('Crear'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok != true) return;
    if (!mounted) return;

    await context.read<AlertasProvider>().create(
          zone: zoneCtrl.text.trim(),
          message: msgCtrl.text.trim(),
          level: level,
        );
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<AlertasProvider>();
    final f = p.filters;

    final zones = p.alerts.map((a) => a.zone).toSet().toList()..sort();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Gestión de Alertas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MinerColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('zone-${f.zone}'),
                  initialValue: f.zone,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas las zonas')),
                    for (final z in zones)
                      DropdownMenuItem(
                        value: z,
                        child: Text(z),
                      ),
                  ],
                  onChanged: (v) => p.setFilters(f.copyWith(zone: v, clearZone: v == null)),
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 170,
                child: DropdownButtonFormField<bool?>(
                  key: ValueKey('res-${f.resolved}'),
                  initialValue: f.resolved,
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Todas')),
                    DropdownMenuItem(value: false, child: Text('Pendientes')),
                    DropdownMenuItem(value: true, child: Text('Resueltas')),
                  ],
                  onChanged: (v) => p.setFilters(f.copyWith(resolved: v, clearResolved: v == null)),
                  decoration: const InputDecoration(labelText: 'Estado'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: p.isLoading ? null : _openCreateDialog,
                icon: const Icon(Icons.add),
                label: const Text('Nueva alerta'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: p.isLoading ? null : () => p.load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (p.error != null)
            Text(
              p.error!,
              style: const TextStyle(color: MinerColors.danger),
            ),
          const SizedBox(height: 10),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: DataTable2(
                  headingRowHeight: 42,
                  dataRowHeight: 50,
                  columnSpacing: 14,
                  minWidth: 900,
                  columns: const [
                    DataColumn2(label: Text('ID'), fixedWidth: 55),
                    DataColumn2(label: Text('Zona'), size: ColumnSize.S),
                    DataColumn2(label: Text('Nivel'), fixedWidth: 85),
                    DataColumn2(label: Text('Mensaje'), size: ColumnSize.L),
                    DataColumn2(label: Text('Fecha'), fixedWidth: 175),
                    DataColumn2(label: Text('Estado'), fixedWidth: 100),
                    DataColumn2(label: Text('Acciones'), fixedWidth: 155),
                  ],
                  rows: [
                    for (final a in p.alerts)
                      DataRow(
                        cells: [
                          DataCell(Text(a.id)),
                          DataCell(Text(a.zone)),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: a.level.toLowerCase().contains('danger')
                                    ? MinerColors.danger.withValues(alpha: 0.15)
                                    : (a.level.toLowerCase().contains('warn')
                                        ? MinerColors.warn.withValues(alpha: 0.15)
                                        : MinerColors.accent.withValues(alpha: 0.15)),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: a.level.toLowerCase().contains('danger')
                                      ? MinerColors.danger.withValues(alpha: 0.4)
                                      : (a.level.toLowerCase().contains('warn')
                                          ? MinerColors.warn.withValues(alpha: 0.4)
                                          : MinerColors.accent.withValues(alpha: 0.4)),
                                ),
                              ),
                              child: Text(
                                a.level.toUpperCase(),
                                style: TextStyle(
                                  color: a.level.toLowerCase().contains('danger')
                                      ? MinerColors.danger
                                      : (a.level.toLowerCase().contains('warn')
                                          ? MinerColors.warn
                                          : MinerColors.accent),
                                  fontWeight: FontWeight.w800,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 380,
                              child: Text(
                                a.message,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text(_formatDateTime(a.createdAt))),
                          DataCell(
                            Text(
                              a.resolved ? 'Resuelta' : 'Pendiente',
                              style: TextStyle(
                                color: a.resolved ? MinerColors.ok : MinerColors.warn,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          DataCell(
                            !a.resolved
                                ? ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () => p.resolve(a.id),
                                    child: const Text('Marcar resuelta', style: TextStyle(fontSize: 12)),
                                  )
                                : Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: MinerColors.ok.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(color: MinerColors.ok.withValues(alpha: 0.35)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, size: 14, color: MinerColors.ok),
                                        const SizedBox(width: 5),
                                        Text(
                                          a.resolvedAt != null
                                              ? '${a.resolvedAt!.hour.toString().padLeft(2, '0')}:${a.resolvedAt!.minute.toString().padLeft(2, '0')}:${a.resolvedAt!.second.toString().padLeft(2, '0')}'
                                              : 'Atendida',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: MinerColors.ok,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

