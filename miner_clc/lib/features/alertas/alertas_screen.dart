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
                  'Alertas',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MinerColors.text,
                  ),
                ),
              ),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('filter-zone-${f.zone ?? 'all'}'),
                  initialValue: f.zone,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('Todas las zonas')),
                    for (final z in zones) DropdownMenuItem(value: z, child: Text(z)),
                  ],
                  onChanged: (v) => p.setFilters(f.copyWith(zone: v, clearZone: v == null)),
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<bool?>(
                  key: ValueKey('filter-resolved-${f.resolved?.toString() ?? 'all'}'),
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
                    DataColumn(label: Text('ID')),
                    DataColumn(label: Text('Zona')),
                    DataColumn(label: Text('Nivel')),
                    DataColumn(label: Text('Mensaje')),
                    DataColumn(label: Text('Fecha')),
                    DataColumn(label: Text('Estado')),
                    DataColumn(label: Text('Acciones')),
                  ],
                  rows: [
                    for (final a in p.alerts)
                      DataRow(
                        cells: [
                          DataCell(Text(a.id)),
                          DataCell(Text(a.zone)),
                          DataCell(
                            Text(
                              a.level,
                              style: TextStyle(
                                color: a.level.toLowerCase().contains('danger')
                                    ? MinerColors.danger
                                    : (a.level.toLowerCase().contains('warn')
                                        ? MinerColors.warn
                                        : MinerColors.accent),
                                fontWeight: FontWeight.w700,
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
                          DataCell(Text(a.createdAt.toString())),
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
                            Row(
                              children: [
                                if (!a.resolved)
                                  ElevatedButton(
                                    onPressed: () => p.resolve(a.id),
                                    child: const Text('Marcar resuelta'),
                                  )
                                else
                                  Text(
                                    a.resolvedAt == null ? '—' : a.resolvedAt.toString(),
                                    style: TextStyle(
                                      color: MinerColors.text.withValues(alpha: 0.75),
                                    ),
                                  ),
                              ],
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

