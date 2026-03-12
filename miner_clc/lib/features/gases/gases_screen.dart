import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
import '../../shared/widgets/chart_widget.dart';
import '../../shared/widgets/gas_card.dart';
import 'gases_provider.dart';

class GasesScreen extends StatefulWidget {
  const GasesScreen({super.key});

  @override
  State<GasesScreen> createState() => _GasesScreenState();
}

class _GasesScreenState extends State<GasesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<GasesProvider>();
      p.loadLatest();
      p.startPolling();
    });
  }

  @override
  void dispose() {
    context.read<GasesProvider>().stopPolling();
    super.dispose();
  }

  GasStatus _statusFor({
    required String gas,
    required double? value,
  }) {
    if (value == null) return GasStatus.normal;

    // Thresholds are placeholders (adjust to your safety standard).
    return switch (gas) {
      'CO' => value < 25 ? GasStatus.normal : (value < 50 ? GasStatus.precaucion : GasStatus.peligro),
      'O2' => value >= 19.5 ? GasStatus.normal : (value >= 18 ? GasStatus.precaucion : GasStatus.peligro),
      'CO2' => value < 5000 ? GasStatus.normal : (value < 15000 ? GasStatus.precaucion : GasStatus.peligro),
      'CH4' => value < 1.0 ? GasStatus.normal : (value < 2.5 ? GasStatus.precaucion : GasStatus.peligro),
      'H2S' => value < 10 ? GasStatus.normal : (value < 20 ? GasStatus.precaucion : GasStatus.peligro),
      'T' => value < 35 ? GasStatus.normal : (value < 45 ? GasStatus.precaucion : GasStatus.peligro),
      _ => GasStatus.normal,
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<GasesProvider>();
    final selected = p.selectedZone;
    final zones = p.zones;

    final latestByZone = <String, dynamic>{};
    for (final r in p.latest) {
      latestByZone.putIfAbsent(r.zone, () => r);
    }

    final selectedLatest = selected == null ? null : latestByZone[selected];

    final historyPointsCO = p.history
        .take(60)
        .toList()
        .reversed
        .map((r) => ChartPoint(r.timestamp, (r.co ?? 0).toDouble()))
        .toList();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Monitoreo de Gases',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MinerColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 260,
                child: DropdownButtonFormField<String>(
                  key: ValueKey('zone-$selected'),
                  initialValue: selected,
                  items: [
                    for (final z in zones)
                      DropdownMenuItem(
                        value: z,
                        child: Text(z),
                      ),
                  ],
                  onChanged: p.isLoading
                      ? null
                      : (v) {
                          if (v == null) return;
                          p.loadHistory(zone: v);
                        },
                  decoration: const InputDecoration(labelText: 'Zona'),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: p.isLoading ? null : () => p.loadLatest(),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.error != null)
            Text(
              p.error!,
              style: const TextStyle(color: MinerColors.danger),
            ),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(
              builder: (context, c) {
                final leftWidth = (c.maxWidth * 0.56).clamp(420, 760).toDouble();
                return Row(
                  children: [
                    SizedBox(
                      width: leftWidth,
                      child: Column(
                        children: [
                          Expanded(
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: DataTable2(
                                  headingRowHeight: 42,
                                  dataRowHeight: 44,
                                  columnSpacing: 14,
                                  minWidth: 520,
                                  columns: const [
                                    DataColumn(label: Text('Zona')),
                                    DataColumn(label: Text('Fecha')),
                                    DataColumn(label: Text('CO')),
                                    DataColumn(label: Text('O₂')),
                                    DataColumn(label: Text('CO₂')),
                                    DataColumn(label: Text('CH₄')),
                                    DataColumn(label: Text('H₂S')),
                                    DataColumn(label: Text('Temp')),
                                  ],
                                  rows: [
                                    for (final r in latestByZone.values.take(200))
                                      DataRow(
                                        onSelectChanged: (_) => p.loadHistory(zone: r.zone),
                                        cells: [
                                          DataCell(Text(r.zone)),
                                          DataCell(Text(r.timestamp.toString())),
                                          DataCell(Text(r.co?.toStringAsFixed(2) ?? '—')),
                                          DataCell(Text(r.o2?.toStringAsFixed(2) ?? '—')),
                                          DataCell(Text(r.co2?.toStringAsFixed(2) ?? '—')),
                                          DataCell(Text(r.ch4?.toStringAsFixed(2) ?? '—')),
                                          DataCell(Text(r.h2s?.toStringAsFixed(2) ?? '—')),
                                          DataCell(Text(r.temperatura?.toStringAsFixed(1) ?? '—')),
                                        ],
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Expanded(
                            child: HistoryLineChart(
                              points: historyPointsCO,
                              label: selected == null ? 'Historial' : 'Historial CO • $selected',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            GasCard(
                              label: 'CO',
                              value: selectedLatest?.co,
                              unit: 'ppm',
                              status: _statusFor(gas: 'CO', value: selectedLatest?.co),
                              subtitle: selected ?? '—',
                            ),
                            GasCard(
                              label: 'O₂',
                              value: selectedLatest?.o2,
                              unit: '%',
                              status: _statusFor(gas: 'O2', value: selectedLatest?.o2),
                              subtitle: selected ?? '—',
                            ),
                            GasCard(
                              label: 'CO₂',
                              value: selectedLatest?.co2,
                              unit: 'ppm',
                              status: _statusFor(gas: 'CO2', value: selectedLatest?.co2),
                              subtitle: selected ?? '—',
                            ),
                            GasCard(
                              label: 'CH₄',
                              value: selectedLatest?.ch4,
                              unit: '%',
                              status: _statusFor(gas: 'CH4', value: selectedLatest?.ch4),
                              subtitle: selected ?? '—',
                            ),
                            GasCard(
                              label: 'H₂S',
                              value: selectedLatest?.h2s,
                              unit: 'ppm',
                              status: _statusFor(gas: 'H2S', value: selectedLatest?.h2s),
                              subtitle: selected ?? '—',
                            ),
                            GasCard(
                              label: 'Temperatura',
                              value: selectedLatest?.temperatura,
                              unit: '°C',
                              status: _statusFor(gas: 'T', value: selectedLatest?.temperatura),
                              subtitle: selected ?? '—',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

