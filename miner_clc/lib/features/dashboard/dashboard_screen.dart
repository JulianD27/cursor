import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
import '../alertas/alertas_provider.dart';
import '../auth/auth_provider.dart';
import 'dashboard_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DashboardProvider>().load();
      context.read<AlertasProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final dash = context.watch<DashboardProvider>();
    final summary = dash.summary;
    final auth = context.watch<AuthProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: MinerColors.text,
            ),
          ),
          const SizedBox(height: 12),
          if (dash.error != null)
            Text(
              dash.error!,
              style: const TextStyle(color: MinerColors.danger),
            ),
          if (dash.isLoading && summary == null)
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Expanded(
              child: LayoutBuilder(
                builder: (context, c) {
                  final twoCols = c.maxWidth >= 920;
                  return GridView.count(
                    crossAxisCount: twoCols ? 2 : 1,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: twoCols ? 2.2 : 1.8,
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              const CircleAvatar(
                                radius: 26,
                                backgroundColor: MinerColors.button,
                                child: Icon(Icons.person, size: 28, color: MinerColors.text),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      auth.displayName ?? (auth.userId ?? 'Usuario'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                        color: MinerColors.text,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      auth.email ?? 'Correo no registrado',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: MinerColors.text.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      auth.document == null || auth.document!.isEmpty
                                          ? 'Documento: —'
                                          : 'Documento: ${auth.document}',
                                      style: TextStyle(
                                        color: MinerColors.text.withValues(alpha: 0.75),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Zonas activas',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MinerColors.text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  for (final z in (summary?.activeZones ?? const <String>[]))
                                    Chip(
                                      label: Text(z),
                                      backgroundColor: MinerColors.sidebar,
                                      labelStyle: const TextStyle(color: MinerColors.text),
                                      side: const BorderSide(color: MinerColors.border),
                                    ),
                                  if ((summary?.activeZones ?? const <String>[]).isEmpty)
                                    Text(
                                      'Sin zonas detectadas',
                                      style: TextStyle(
                                        color: MinerColors.text.withValues(alpha: 0.75),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Alertas recientes',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MinerColors.text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: (summary?.recentAlerts ?? const []).length,
                                  separatorBuilder: (context, index) => const Divider(height: 12),
                                  itemBuilder: (context, i) {
                                    final a = summary!.recentAlerts[i];
                                    final color = a.level.toLowerCase().contains('danger') ||
                                            a.level.toLowerCase().contains('high')
                                        ? MinerColors.danger
                                        : (a.level.toLowerCase().contains('warn')
                                            ? MinerColors.warn
                                            : MinerColors.accent);
                                    return Row(
                                      children: [
                                        Container(
                                          width: 10,
                                          height: 34,
                                          decoration: BoxDecoration(
                                            color: color,
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                '${a.zone} • ${a.createdAt}',
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: MinerColors.text.withValues(alpha: 0.75),
                                                  fontSize: 12,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                a.message,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: MinerColors.text,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(
                                          a.resolved ? Icons.check_circle : Icons.warning_amber_rounded,
                                          color: a.resolved ? MinerColors.ok : color,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Últimas lecturas de gases',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MinerColors.text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Expanded(
                                child: ListView.separated(
                                  itemCount: (summary?.latestReadings ?? const []).length,
                                  separatorBuilder: (context, index) => const Divider(height: 12),
                                  itemBuilder: (context, i) {
                                    final r = summary!.latestReadings[i];
                                    return Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${r.zone} • ${r.timestamp}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(color: MinerColors.text),
                                          ),
                                        ),
                                        Text(
                                          'CO: ${r.co?.toStringAsFixed(2) ?? '—'}',
                                          style: TextStyle(
                                            color: MinerColors.text.withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ],
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Configuración',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: MinerColors.text,
                                ),
                              ),
                              const SizedBox(height: 10),
                              SwitchListTile(
                                value: true,
                                onChanged: (_) {},
                                dense: true,
                                title: const Text(
                                  'Tema oscuro',
                                  style: TextStyle(color: MinerColors.text),
                                ),
                                subtitle: Text(
                                  'Interfaz optimizada para salas de control.',
                                  style: TextStyle(
                                    color: MinerColors.textWithAlpha,
                                  ),
                                ),
                              ),
                              SwitchListTile(
                                value: true,
                                onChanged: (_) {},
                                dense: true,
                                title: const Text(
                                  'Actualizar datos automáticamente',
                                  style: TextStyle(color: MinerColors.text),
                                ),
                                subtitle: Text(
                                  'Lecturas de gases y estados de ventilación cada pocos segundos.',
                                  style: TextStyle(
                                    color: MinerColors.textWithAlpha,
                                  ),
                                ),
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

