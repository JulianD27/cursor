import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../shared/theme.dart';
import '../alertas/alertas_provider.dart';
import '../auth/auth_provider.dart';
import 'dashboard_provider.dart';
import 'widgets/interactive_mine_map.dart';

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
                    childAspectRatio: twoCols ? 1.6 : 1.35,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: MinerColors.card,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: MinerColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            )
                          ]
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            // Encabezado del carnet
                            Container(
                              height: 24,
                              width: double.infinity,
                              color: MinerColors.accent,
                              alignment: Alignment.center,
                              child: const Text(
                                'CREDENCIAL DE IDENTIFICACIÓN • MINER CLC',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    // Foto rectangular de carnet
                                    GestureDetector(
                                      onTap: () async {
                                        try {
                                          final result = await FilePicker.platform.pickFiles(type: FileType.image);
                                          if (result != null && result.files.single.path != null) {
                                            auth.setLocalPhoto(result.files.single.path);
                                          }
                                        } catch (e) {
                                          // Ignorar
                                        }
                                      },
                                      child: Container(
                                        width: 70,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          color: MinerColors.button,
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: MinerColors.border),
                                          image: auth.localPhotoPath != null
                                              ? DecorationImage(
                                                  image: FileImage(File(auth.localPhotoPath!)),
                                                  fit: BoxFit.cover,
                                                )
                                              : null,
                                        ),
                                        child: auth.localPhotoPath == null
                                            ? const Center(child: Icon(Icons.add_a_photo, color: MinerColors.textWithAlpha, size: 24))
                                            : null,
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Datos del trabajador
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            auth.displayName ?? (auth.userId ?? 'Usuario'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w900,
                                              color: MinerColors.text,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: MinerColors.accent.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: MinerColors.accent.withValues(alpha: 0.4)),
                                            ),
                                            child: Text(
                                              auth.role.toUpperCase(),
                                              style: const TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: MinerColors.accent,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              const Text('ID: ', style: TextStyle(fontSize: 10, color: MinerColors.textWithAlpha, fontWeight: FontWeight.bold)),
                                              Expanded(child: Text(auth.document?.isNotEmpty == true ? auth.document! : '—', style: const TextStyle(fontSize: 11, color: MinerColors.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                          const SizedBox(height: 2),
                                          Row(
                                            children: [
                                              const Text('EMAIL: ', style: TextStyle(fontSize: 10, color: MinerColors.textWithAlpha, fontWeight: FontWeight.bold)),
                                              Expanded(child: Text(auth.email ?? '—', style: const TextStyle(fontSize: 11, color: MinerColors.text), maxLines: 1, overflow: TextOverflow.ellipsis)),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Código QR falso decorativo
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Icon(Icons.qr_code_2, size: 40, color: Colors.black),
                                    )
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: InteractiveMineMap(
                            latestReadings: summary?.latestReadings ?? const [],
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

