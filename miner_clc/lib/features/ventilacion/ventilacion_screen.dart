import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../db/models.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/zone_card.dart';
import 'ventilacion_provider.dart';

class VentilacionScreen extends StatefulWidget {
  const VentilacionScreen({super.key});

  @override
  State<VentilacionScreen> createState() => _VentilacionScreenState();
}

class _VentilacionScreenState extends State<VentilacionScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final p = context.read<VentilacionProvider>();
      p.load();
      p.startPolling();
    });
  }

  @override
  void dispose() {
    context.read<VentilacionProvider>().stopPolling();
    super.dispose();
  }

  Color _modeColor(VentMode m) {
    return switch (m) {
      VentMode.on => MinerColors.ok,
      VentMode.off => MinerColors.danger,
      VentMode.auto => MinerColors.accent,
    };
  }

  String _modeLabel(VentMode m) {
    return switch (m) {
      VentMode.on => 'ON',
      VentMode.off => 'OFF',
      VentMode.auto => 'AUTO',
    };
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<VentilacionProvider>();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Ventilación',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: MinerColors.text,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: p.isLoading ? null : () => p.load(),
                icon: const Icon(Icons.refresh),
                label: const Text('Actualizar'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (p.isLoading) const LinearProgressIndicator(minHeight: 4),
          if (p.error != null) ...[
            const SizedBox(height: 10),
            Text(
              p.error!,
              style: const TextStyle(color: MinerColors.danger),
            ),
          ],
          const SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 520,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.1,
              ),
              itemCount: p.states.length,
              itemBuilder: (context, i) {
                final s = p.states[i];
                final mode = s.mode;
                final color = _modeColor(mode);

                return ZoneCard(
                  zone: s.zone,
                  subtitle: 'Modo: ${_modeLabel(mode)} • Velocidad: ${s.speed}%\nActualizado: ${s.updatedAt}',
                  statusColor: color,
                  trailing: SizedBox(
                    width: 220,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _ModeButton(
                              label: 'ON',
                              selected: mode == VentMode.on,
                              onTap: p.isLoading ? null : () => p.setMode(s.zone, VentMode.on),
                            ),
                            _ModeButton(
                              label: 'OFF',
                              selected: mode == VentMode.off,
                              onTap: p.isLoading ? null : () => p.setMode(s.zone, VentMode.off),
                            ),
                            _ModeButton(
                              label: 'AUTO',
                              selected: mode == VentMode.auto,
                              onTap: p.isLoading ? null : () => p.setMode(s.zone, VentMode.auto),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Text('0', style: TextStyle(color: MinerColors.text, fontSize: 12)),
                            Expanded(
                              child: Slider(
                                value: s.speed.toDouble(),
                                min: 0,
                                max: 100,
                                divisions: 20,
                                activeColor: MinerColors.accent,
                                onChanged: p.isLoading || mode == VentMode.off
                                    ? null
                                    : (v) => p.setSpeed(s.zone, v.round()),
                              ),
                            ),
                            const Text('100', style: TextStyle(color: MinerColors.text, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: selected ? MinerColors.accent : MinerColors.border),
          foregroundColor: MinerColors.text,
          backgroundColor: selected ? MinerColors.button : MinerColors.card,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label),
      ),
    );
  }
}

