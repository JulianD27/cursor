import 'dart:io';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../../db/models.dart';
import '../../../shared/theme.dart';

/// Nodo geográfico de una zona de la mina
class MineZoneNode {
  final int zoneId;
  final String zoneName;
  final int level; // 1, 2, 3
  final double xRatio; // 0.0 a 1.0
  final double yRatio; // 0.0 a 1.0
  final String description;
  final String coordinates; // Lat / Lon WGS-84
  final String utmCoords; // Coordenadas proyectadas UTM
  final int elevationMsnm; // Cota sobre el nivel del mar en metros
  final int depthMeters; // Profundidad bajo superficie

  const MineZoneNode({
    required this.zoneId,
    required this.zoneName,
    required this.level,
    required this.xRatio,
    required this.yRatio,
    required this.description,
    required this.coordinates,
    required this.utmCoords,
    required this.elevationMsnm,
    required this.depthMeters,
  });
}

/// Coordenadas georreferenciadas de las 5 zonas de MINER CLC en la concesión minera
const List<MineZoneNode> kMineZoneNodes = [
  MineZoneNode(
    zoneId: 1,
    zoneName: "Norte - Nivel 1",
    level: 1,
    xRatio: 0.36,
    yRatio: 0.32,
    description: "Bocamina principal y frente de arranque Norte (Portales de acceso)",
    coordinates: "5°32'44.2\" N, 73°21'18.5\" W",
    utmCoords: "18N 541280m E, 612840m N",
    elevationMsnm: 2640,
    depthMeters: 25,
  ),
  MineZoneNode(
    zoneId: 4,
    zoneName: "Oeste - Nivel 1",
    level: 1,
    xRatio: 0.16,
    yRatio: 0.52,
    description: "Galería de transporte y subestación eléctrica exterior",
    coordinates: "5°32'39.8\" N, 73°21'26.1\" W",
    utmCoords: "18N 541060m E, 612690m N",
    elevationMsnm: 2595,
    depthMeters: 70,
  ),
  MineZoneNode(
    zoneId: 5,
    zoneName: "Central - Nivel 2",
    level: 2,
    xRatio: 0.46,
    yRatio: 0.56,
    description: "Chimenea de ventilación central y cruce de labores subterráneas",
    coordinates: "5°32'35.0\" N, 73°21'19.0\" W",
    utmCoords: "18N 541250m E, 612550m N",
    elevationMsnm: 2540,
    depthMeters: 125,
  ),
  MineZoneNode(
    zoneId: 2,
    zoneName: "Sur - Nivel 2",
    level: 2,
    xRatio: 0.58,
    yRatio: 0.60,
    description: "Rampa de acceso sur, patio de acopio y cargador de mineral",
    coordinates: "5°32'28.1\" N, 73°21'22.4\" W",
    utmCoords: "18N 541160m E, 612340m N",
    elevationMsnm: 2485,
    depthMeters: 180,
  ),
  MineZoneNode(
    zoneId: 3,
    zoneName: "Este - Nivel 3",
    level: 3,
    xRatio: 0.74,
    yRatio: 0.52,
    description: "Profundidad máxima / Manto carbón / Mayor riesgo CH4",
    coordinates: "5°32'31.5\" N, 73°21'10.2\" W",
    utmCoords: "18N 541520m E, 612440m N",
    elevationMsnm: 2390,
    depthMeters: 275,
  ),
];

enum MineSensorStatus { ok, warn, danger }

/// Determina el estado del semáforo ambiental según las normas mineras
MineSensorStatus getGasReadingStatus(GasReading? reading) {
  if (reading == null) return MineSensorStatus.ok;

  // 1. Peligro crítico (Rojo)
  if ((reading.ch4 != null && reading.ch4! >= 2.0) ||
      (reading.co != null && reading.co! >= 50.0) ||
      (reading.o2 != null && reading.o2! < 19.5) ||
      (reading.h2s != null && reading.h2s! >= 10.0)) {
    return MineSensorStatus.danger;
  }

  // 2. Advertencia preventiva (Amarillo)
  if ((reading.ch4 != null && reading.ch4! >= 1.0) ||
      (reading.co != null && reading.co! >= 25.0) ||
      (reading.h2s != null && reading.h2s! >= 5.0) ||
      (reading.temperatura != null && reading.temperatura! >= 30.0)) {
    return MineSensorStatus.warn;
  }

  // 3. Seguro (Verde)
  return MineSensorStatus.ok;
}

Color getStatusColor(MineSensorStatus status) {
  switch (status) {
    case MineSensorStatus.ok:
      return MinerColors.ok; // 0xFF2ECC71
    case MineSensorStatus.warn:
      return MinerColors.warn; // 0xFFF1C40F
    case MineSensorStatus.danger:
      return MinerColors.danger; // 0xFFE74C3C
  }
}

/// Widget interactivo del mapa geográfico y plano esquemático subterráneo
class InteractiveMineMap extends StatefulWidget {
  final List<GasReading> latestReadings;
  final bool isFullScreen;
  final int initialViewMode;
  final String? initialCustomImagePath;

  const InteractiveMineMap({
    super.key,
    required this.latestReadings,
    this.isFullScreen = false,
    this.initialViewMode = 3, // Por defecto: 3 = 🌍 Geográfico Satelital GIS
    this.initialCustomImagePath,
  });

  @override
  State<InteractiveMineMap> createState() => _InteractiveMineMapState();
}

class _InteractiveMineMapState extends State<InteractiveMineMap> with SingleTickerProviderStateMixin {
  int _selectedLevel = 0; // 0 = Todos, 1 = Nivel 1, 2 = Nivel 2, 3 = Nivel 3
  late int _viewMode; // 3 = 🌍 Geográfico GIS, 1 = Blueprint HD, 0 = CAD Vectorial, 2 = Imagen Propia
  String? _customImagePath;
  late AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.initialViewMode;
    _customImagePath = widget.initialCustomImagePath;
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  GasReading? _findReadingForZone(String zoneName) {
    for (final r in widget.latestReadings) {
      if (r.zone.trim().toLowerCase() == zoneName.trim().toLowerCase()) {
        return r;
      }
    }
    return null;
  }

  void _openDetailModal(MineZoneNode node, GasReading? reading, MineSensorStatus status) {
    showDialog(
      context: context,
      builder: (ctx) {
        final statusColor = getStatusColor(status);
        final statusText = switch (status) {
          MineSensorStatus.ok => 'CONDICIÓN NORMAL (SEGURO)',
          MineSensorStatus.warn => 'ADVERTENCIA PREVENTIVA',
          MineSensorStatus.danger => 'PELIGRO CRÍTICO (EVACUACIÓN)',
        };

        return AlertDialog(
          backgroundColor: const Color(0xFF222222),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: statusColor, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.sensors, color: statusColor, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  node.zoneName.toUpperCase(),
                  style: const TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  'NIVEL ${node.level}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  node.description,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFB0B0B0)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        status == MineSensorStatus.danger
                            ? Icons.warning_rounded
                            : (status == MineSensorStatus.warn ? Icons.info_outline : Icons.check_circle_outline),
                        color: statusColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'TELEMETRÍA EN TIEMPO REAL:',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white70, letterSpacing: 0.8),
                ),
                const SizedBox(height: 8),
                _buildTelemetryGrid(reading),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161E28),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF2C3E50)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.public, color: Color(0xFF4A90D9), size: 14),
                          SizedBox(width: 6),
                          Text(
                            'GEORREFERENCIACIÓN Y COORDENADAS GIS:',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF4A90D9), letterSpacing: 0.5),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Text('📍 WGS-84: ', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          Expanded(
                            child: Text(
                              node.coordinates,
                              style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          const Text('🌐 UTM: ', style: TextStyle(fontSize: 10, color: Color(0xFF888888))),
                          Expanded(
                            child: Text(
                              node.utmCoords,
                              style: const TextStyle(fontSize: 10, color: Color(0xFFB0B0B0), fontFamily: 'monospace'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFF2ECC71).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '⛰️ Cota: ${node.elevationMsnm} msnm',
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFF2ECC71), fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE67E22).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: const Color(0xFFE67E22).withValues(alpha: 0.4)),
                            ),
                            child: Text(
                              '⛏️ Profundidad: -${node.depthMeters} m',
                              style: const TextStyle(fontSize: 9.5, color: Color(0xFFE67E22), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar', style: TextStyle(color: Colors.white70)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTelemetryGrid(GasReading? r) {
    Widget cell(String label, String value, String unit, Color valColor) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF181818),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: const Color(0xFF333333)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF888888), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Row(
              children: [
                Text(
                  value,
                  style: TextStyle(fontFamily: 'Rajdhani', fontSize: 18, fontWeight: FontWeight.w700, color: valColor),
                ),
                const SizedBox(width: 3),
                Text(unit, style: const TextStyle(fontSize: 10, color: Color(0xFF888888))),
              ],
            ),
          ],
        ),
      );
    }

    final co = r?.co;
    final o2 = r?.o2;
    final ch4 = r?.ch4;
    final co2 = r?.co2;
    final h2s = r?.h2s;
    final temp = r?.temperatura;

    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      childAspectRatio: 1.5,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        cell('CO', co != null ? co.toStringAsFixed(1) : '—', 'ppm', (co != null && co >= 50) ? MinerColors.danger : Colors.white),
        cell('O2', o2 != null ? o2.toStringAsFixed(1) : '—', '%', (o2 != null && o2 < 19.5) ? MinerColors.danger : Colors.white),
        cell('CH4', ch4 != null ? ch4.toStringAsFixed(2) : '—', '%', (ch4 != null && ch4 >= 2.0) ? MinerColors.danger : (ch4 != null && ch4 >= 1.0 ? MinerColors.warn : Colors.white)),
        cell('CO2', co2 != null ? co2.toStringAsFixed(0) : '—', 'ppm', Colors.white),
        cell('H2S', h2s != null ? h2s.toStringAsFixed(1) : '—', 'ppm', (h2s != null && h2s >= 10) ? MinerColors.danger : Colors.white),
        cell('TEMP', temp != null ? temp.toStringAsFixed(1) : '—', '°C', (temp != null && temp >= 30) ? MinerColors.warn : Colors.white),
      ],
    );
  }

  void _openFullScreenMap() {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: const Color(0xFF141414),
          insetPadding: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: const BorderSide(color: Color(0xFF444444)),
          ),
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.public, color: MinerColors.accent, size: 22),
                          SizedBox(width: 10),
                          Text(
                            'MAPA GEOGRÁFICO Y PLANO SUBTERRÁNEO — VISTA COMPLETA (GIS)',
                            style: TextStyle(
                              fontFamily: 'Rajdhani',
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF333333)),
                  Expanded(
                    child: InteractiveMineMap(
                      latestReadings: widget.latestReadings,
                      isFullScreen: true,
                      initialViewMode: _viewMode,
                      initialCustomImagePath: _customImagePath,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de Herramientas superior: Selector de Plano, Filtros de nivel y Fullscreen (Responsivo)
        LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 640;

            final modeSelector = Container(
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF444444)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _modeBtn('🌍 Geográfico', 3),
                  _modeBtn('🗺️ Plano HD', 1),
                  _modeBtn('📐 CAD', 0),
                  InkWell(
                    onTap: () async {
                      try {
                        final res = await FilePicker.platform.pickFiles(type: FileType.image);
                        if (res != null && res.files.single.path != null) {
                          setState(() {
                            _customImagePath = res.files.single.path;
                            _viewMode = 2;
                          });
                        }
                      } catch (e) {
                        // ignore
                      }
                    },
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: _viewMode == 2 ? MinerColors.accent : Colors.transparent,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.file_upload_outlined, size: 12, color: Colors.white),
                          SizedBox(width: 3),
                          Text('Subir', style: TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );

            final levelSelector = Container(
              height: 28,
              decoration: BoxDecoration(
                color: const Color(0xFF222222),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: const Color(0xFF444444)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _levelBtn('Todos', 0),
                  _levelBtn('Niv 1', 1),
                  _levelBtn('Niv 2', 2),
                  _levelBtn('Niv 3', 3),
                ],
              ),
            );

            final fullscreenBtn = !widget.isFullScreen
                ? IconButton(
                    icon: const Icon(Icons.fullscreen, color: Colors.white70, size: 20),
                    tooltip: 'Ampliar plano en pantalla completa',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: _openFullScreenMap,
                  )
                : const SizedBox.shrink();

            if (isCompact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.map_outlined, color: MinerColors.accent, size: 18),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'MAPA Y PLANO DE LA MINA',
                          style: TextStyle(
                            fontFamily: 'Rajdhani',
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                            color: Colors.white,
                            letterSpacing: 1.0,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      fullscreenBtn,
                    ],
                  ),
                  const SizedBox(height: 6),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        modeSelector,
                        const SizedBox(width: 8),
                        levelSelector,
                      ],
                    ),
                  ),
                ],
              );
            }

            return Row(
              children: [
                const Icon(Icons.map_outlined, color: MinerColors.accent, size: 18),
                const SizedBox(width: 8),
                const Text(
                  'MAPA Y PLANO DE LA MINA',
                  style: TextStyle(
                    fontFamily: 'Rajdhani',
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Colors.white,
                    letterSpacing: 1.0,
                  ),
                ),
                const Spacer(),
                modeSelector,
                const SizedBox(width: 8),
                levelSelector,
                if (!widget.isFullScreen) ...[
                  const SizedBox(width: 8),
                  fullscreenBtn,
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 8),

        // Área del mapa esquemático interactivo con Zoom y Paneo
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF121212),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF333333)),
            ),
            clipBehavior: Clip.antiAlias,
            child: InteractiveViewer(
              boundaryMargin: const EdgeInsets.all(60),
              minScale: 0.6,
              maxScale: 3.5,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final h = constraints.maxHeight;

                  return Stack(
                    children: [
                      // ── CAPAS DE FONDO SEGÚN EL MODO SELECCIONADO ──
                      if (_viewMode == 3) ...[
                        // Modo 3: Mapa Geográfico Satelital HD (Ortofoto GIS)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/mine_geographic_satellite.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Filtro sutil para realzar la retícula y balizas
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.15),
                          ),
                        ),
                        // Retícula geodésica de coordenadas WGS-84
                        CustomPaint(
                          size: Size(w, h),
                          painter: _GeographicGridPainter(),
                        ),
                        // Trazado de galerías subterráneas proyectadas en superficie con luminosidad tenue
                        CustomPaint(
                          size: Size(w, h),
                          painter: _MineTunnelPainter(activeLevel: _selectedLevel, isGeographicOverlay: true),
                        ),
                      ] else if (_viewMode == 1) ...[
                        // Modo 1: Imagen Plano Blueprint HD de Ejemplo
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.asset(
                              'assets/images/mine_blueprint_cad.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Filtro tenue para resaltar las balizas LED
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.20),
                          ),
                        ),
                      ] else if (_viewMode == 2 && _customImagePath != null) ...[
                        // Modo 2: Plano propio subido por el usuario
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.file(
                              File(_customImagePath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            color: Colors.black.withValues(alpha: 0.20),
                          ),
                        ),
                      ] else ...[
                        // Modo 0: Trazado CAD Vectorial de túneles y cuadrícula milimétrica
                        CustomPaint(
                          size: Size(w, h),
                          painter: _MineGridPainter(),
                        ),
                        CustomPaint(
                          size: Size(w, h),
                          painter: _MineTunnelPainter(activeLevel: _selectedLevel),
                        ),
                      ],

                      // ── CAPA DE SENSORES Y BALIZAS LED EN TIEMPO REAL ──
                      for (final node in kMineZoneNodes)
                        if (_selectedLevel == 0 || node.level == _selectedLevel)
                          _buildSensorBeacon(node, w, h),

                      // ── BRÚJULA, ESCALA Y LEYENDA TÉCNICA ──
                      Positioned(
                        bottom: 8,
                        left: 8,
                        child: _buildMapLegend(),
                      ),
                      if (_viewMode == 3)
                        Positioned(
                          bottom: 8,
                          left: 175,
                          child: _buildGisScaleBar(),
                        ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: _buildCompass(),
                      ),
                      if (_viewMode == 3)
                        Positioned(
                          top: 8,
                          left: 8,
                          child: _buildGisHudBadge(),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _modeBtn(String label, int val) {
    final active = _viewMode == val;
    return InkWell(
      onTap: () => setState(() => _viewMode = val),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: active ? MinerColors.accent : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _levelBtn(String label, int val) {
    final active = _selectedLevel == val;
    return InkWell(
      onTap: () => setState(() => _selectedLevel = val),
      borderRadius: BorderRadius.circular(5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        color: active ? MinerColors.accent : Colors.transparent,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
            color: active ? Colors.white : const Color(0xFFB0B0B0),
          ),
        ),
      ),
    );
  }

  Widget _buildSensorBeacon(MineZoneNode node, double w, double h) {
    final reading = _findReadingForZone(node.zoneName);
    final status = getGasReadingStatus(reading);
    final color = getStatusColor(status);

    final posX = node.xRatio * w;
    final posY = node.yRatio * h;

    return Positioned(
      left: posX - 20,
      top: posY - 20,
      child: AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (context, child) {
          final pulse = (status == MineSensorStatus.danger)
              ? _pulseCtrl.value * 12
              : (_pulseCtrl.value * 5);

          return Tooltip(
            richMessage: TextSpan(
              text: '${node.zoneName} (Nivel ${node.level})\n',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              children: [
                TextSpan(text: '📍 ${node.coordinates}\n', style: const TextStyle(color: Color(0xFF4A90D9), fontSize: 10, fontFamily: 'monospace')),
                TextSpan(text: '⛰️ Cota: ${node.elevationMsnm} msnm | Prof: -${node.depthMeters}m\n', style: const TextStyle(color: Color(0xFF2ECC71), fontSize: 10)),
                TextSpan(text: 'CO: ${reading?.co?.toStringAsFixed(1) ?? "—"} ppm\n'),
                TextSpan(text: 'CH4: ${reading?.ch4?.toStringAsFixed(2) ?? "—"}%\n'),
                TextSpan(text: 'O2: ${reading?.o2?.toStringAsFixed(1) ?? "—"}%\n'),
                TextSpan(text: 'Temp: ${reading?.temperatura?.toStringAsFixed(1) ?? "—"}°C\n'),
                const TextSpan(
                  text: '👉 Toca para ver telemetría completa',
                  style: TextStyle(color: Color(0xFF4A90D9), fontSize: 10),
                ),
              ],
            ),
            child: GestureDetector(
              onTap: () => _openDetailModal(node, reading, status),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Halo pulsante exterior
                      Container(
                        width: 22 + pulse,
                        height: 22 + pulse,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: 0.20),
                          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
                        ),
                      ),
                      // Baliza central LED
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.8),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Center(
                          child: Icon(Icons.circle, color: Colors.white, size: 4),
                        ),
                      ),
                      // Etiqueta de la zona arriba
                      Transform.translate(
                        offset: const Offset(0, -22),
                        child: OverflowBox(
                          maxWidth: 80,
                          minWidth: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E1E1E).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: color.withValues(alpha: 0.6), width: 0.8),
                            ),
                            child: Text(
                              node.zoneName.split(' - ').first,
                              maxLines: 1,
                              softWrap: false,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: color,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMapLegend() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dot(MinerColors.ok),
          const Text(' Normal  ', style: TextStyle(fontSize: 9, color: Colors.white70)),
          _dot(MinerColors.warn),
          const Text(' Alerta  ', style: TextStyle(fontSize: 9, color: Colors.white70)),
          _dot(MinerColors.danger),
          const Text(' Peligro', style: TextStyle(fontSize: 9, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _dot(Color c) {
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(shape: BoxShape.circle, color: c),
    );
  }

  Widget _buildCompass() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C).withValues(alpha: 0.85),
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('N', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          Icon(Icons.navigation, size: 12, color: Colors.white70),
        ],
      ),
    );
  }
  Widget _buildGisHudBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF161E28).withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFF34495E)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.satellite_alt_outlined, color: Color(0xFF3498DB), size: 13),
              SizedBox(width: 6),
              Text(
                'ORTOFOTO GIS • SISTEMA WGS-84 / MAGNA-SIRGAS',
                style: TextStyle(
                  fontFamily: 'Rajdhani',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFE0E0E0),
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Proyección UTM Zona 18N | Concesión Minera CLC-2026 | Escala 1:2500',
            style: TextStyle(fontSize: 8.5, color: Color(0xFF85929E), fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }

  Widget _buildGisScaleBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1C).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFF333333)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: const BoxDecoration(
              color: Colors.white70,
              border: Border(
                left: BorderSide(color: Colors.white, width: 2),
                right: BorderSide(color: Colors.white, width: 2),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Text('50 m', style: TextStyle(fontSize: 9, color: Colors.white70, fontFamily: 'monospace', fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Pintor que dibuja la retícula geodésica WGS-84 con marcas métricas
class _GeographicGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFF4A90D9).withValues(alpha: 0.18)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final tickPaint = Paint()
      ..color = const Color(0xFF4A90D9).withValues(alpha: 0.60)
      ..strokeWidth = 1.0;

    final xSteps = [size.width * 0.25, size.width * 0.50, size.width * 0.75];
    final ySteps = [size.height * 0.25, size.height * 0.50, size.height * 0.75];

    for (final x in xSteps) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      canvas.drawLine(Offset(x, 0), Offset(x, 6), tickPaint);
      canvas.drawLine(Offset(x, size.height - 6), Offset(x, size.height), tickPaint);
    }

    for (final y in ySteps) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), linePaint);
      canvas.drawLine(Offset(0, y), Offset(6, y), tickPaint);
      canvas.drawLine(Offset(size.width - 6, y), Offset(size.width, y), tickPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor que dibuja la cuadrícula métrica de fondo
class _MineGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = const Color(0xFF222222)
      ..strokeWidth = 0.5;

    const step = 30.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Pintor CAD que dibuja las galerías, chimeneas y túneles subterráneos
class _MineTunnelPainter extends CustomPainter {
  final int activeLevel;
  final bool isGeographicOverlay;

  _MineTunnelPainter({required this.activeLevel, this.isGeographicOverlay = false});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Pintura de túnel principal
    final tunnelPaint = Paint()
      ..color = isGeographicOverlay ? const Color(0xFF00E5FF).withValues(alpha: 0.25) : const Color(0xFF2C2C2C)
      ..strokeWidth = isGeographicOverlay ? 8 : 16
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    // Pintura del eje central del túnel (eje de ventilación)
    final centerlinePaint = Paint()
      ..color = isGeographicOverlay ? const Color(0xFF00E5FF).withValues(alpha: 0.70) : const Color(0xFF4A90D9).withValues(alpha: 0.4)
      ..strokeWidth = isGeographicOverlay ? 2.0 : 1.8
      ..style = PaintingStyle.stroke;

    // Pintura de chimenea vertical / tiro de ventilación
    final shaftPaint = Paint()
      ..color = isGeographicOverlay ? const Color(0xFFFFD54F).withValues(alpha: 0.8) : const Color(0xFF555555)
      ..strokeWidth = isGeographicOverlay ? 5 : 8
      ..strokeCap = StrokeCap.square
      ..style = PaintingStyle.stroke;

    // Coordenadas calculadas sincronizadas con kMineZoneNodes
    final pNorte = Offset(w * kMineZoneNodes[0].xRatio, h * kMineZoneNodes[0].yRatio);
    final pOeste = Offset(w * kMineZoneNodes[1].xRatio, h * kMineZoneNodes[1].yRatio);
    final pCentral = Offset(w * kMineZoneNodes[2].xRatio, h * kMineZoneNodes[2].yRatio);
    final pSur = Offset(w * kMineZoneNodes[3].xRatio, h * kMineZoneNodes[3].yRatio);
    final pEste = Offset(w * kMineZoneNodes[4].xRatio, h * kMineZoneNodes[4].yRatio);

    // DIBUJO DE TÚNELES
    // 1. Galería Principal Norte -> Central -> Sur (Rampa de transporte)
    final mainTunnel = Path();
    mainTunnel.moveTo(pNorte.dx, pNorte.dy);
    mainTunnel.lineTo(pCentral.dx, pCentral.dy);
    mainTunnel.lineTo(pSur.dx, pSur.dy);

    // 2. Transversal Oeste -> Central -> Este (Frente de explotación)
    final crossTunnel = Path();
    crossTunnel.moveTo(pOeste.dx, pOeste.dy);
    crossTunnel.lineTo(pCentral.dx, pCentral.dy);
    crossTunnel.lineTo(pEste.dx, pEste.dy);

    // Dibujar galerías
    canvas.drawPath(mainTunnel, tunnelPaint);
    canvas.drawPath(crossTunnel, tunnelPaint);
    canvas.drawPath(mainTunnel, centerlinePaint);
    canvas.drawPath(crossTunnel, centerlinePaint);

    // Dibujar chimenea de ventilación central
    canvas.drawLine(
      Offset(pCentral.dx - 10, pCentral.dy - 10),
      Offset(pCentral.dx + 10, pCentral.dy + 10),
      shaftPaint,
    );
    canvas.drawLine(
      Offset(pCentral.dx - 10, pCentral.dy + 10),
      Offset(pCentral.dx + 10, pCentral.dy - 10),
      shaftPaint,
    );

    // Flechas de dirección de flujo de aire fresco (de Norte hacia Sur y Este)
    _drawAirflowArrow(canvas, Offset(w * 0.41, h * 0.44), -math.pi / 2.5);
    _drawAirflowArrow(canvas, Offset(w * 0.52, h * 0.58), math.pi / 3);
    _drawAirflowArrow(canvas, Offset(w * 0.60, h * 0.54), 0.2);
  }

  void _drawAirflowArrow(Canvas canvas, Offset pos, double angle) {
    final arrowPaint = Paint()
      ..color = isGeographicOverlay ? const Color(0xFF2ECC71).withValues(alpha: 0.8) : const Color(0xFF2ECC71).withValues(alpha: 0.5)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.save();
    canvas.translate(pos.dx, pos.dy);
    canvas.rotate(angle);

    final path = Path();
    path.moveTo(-6, -4);
    path.lineTo(0, 4);
    path.lineTo(6, -4);

    canvas.drawPath(path, arrowPaint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MineTunnelPainter oldDelegate) {
    return oldDelegate.activeLevel != activeLevel || oldDelegate.isGeographicOverlay != isGeographicOverlay;
  }
}
