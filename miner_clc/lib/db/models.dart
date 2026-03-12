class GasReading {
  GasReading({
    required this.zone,
    required this.timestamp,
    this.co,
    this.o2,
    this.co2,
    this.ch4,
    this.h2s,
    this.temperatura,
  });

  final String zone;
  final DateTime timestamp;
  final double? co;
  final double? o2;
  final double? co2;
  final double? ch4;
  final double? h2s;
  final double? temperatura;
}

enum VentMode { on, off, auto }

class VentilationState {
  VentilationState({
    required this.zone,
    required this.mode,
    required this.speed,
    required this.updatedAt,
  });

  final String zone;
  final VentMode mode;
  final int speed; // 0-100
  final DateTime updatedAt;
}

class MinerAlert {
  MinerAlert({
    required this.id,
    required this.zone,
    required this.message,
    required this.level,
    required this.createdAt,
    required this.resolved,
    this.resolvedAt,
  });

  final String id;
  final String zone;
  final String message;
  final String level; // e.g. info/warn/danger
  final DateTime createdAt;
  final bool resolved;
  final DateTime? resolvedAt;
}

