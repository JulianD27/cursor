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
  }) {
    _validate();
  }

  final String zone;
  final DateTime timestamp;
  final double? co;
  final double? o2;
  final double? co2;
  final double? ch4;
  final double? h2s;
  final double? temperatura;

  /// Valida los datos de la lectura
  void _validate() {
    if (zone.trim().isEmpty) {
      throw ArgumentError('Zone no puede estar vacía');
    }

    // Al menos un valor debe ser válido
    final hasValues = co != null ||
        o2 != null ||
        co2 != null ||
        ch4 != null ||
        h2s != null ||
        temperatura != null;

    if (!hasValues) {
      throw ArgumentError('Al menos un valor de gas debe ser proporcionado');
    }

    // Validar rangos
    if (co != null && (co! < 0 || co! > 1000)) {
      throw ArgumentError('CO fuera de rango: $co (0-1000 ppm)');
    }
    if (o2 != null && (o2! < 0 || o2! > 100)) {
      throw ArgumentError('O2 fuera de rango: $o2 (0-100 %)');
    }
    if (co2 != null && (co2! < 0 || co2! > 100)) {
      throw ArgumentError('CO2 fuera de rango: $co2 (0-100 %)');
    }
    if (ch4 != null && (ch4! < 0 || ch4! > 100)) {
      throw ArgumentError('CH4 fuera de rango: $ch4 (0-100 %)');
    }
    if (h2s != null && (h2s! < 0 || h2s! > 100)) {
      throw ArgumentError('H2S fuera de rango: $h2s (0-100 ppm)');
    }
    if (temperatura != null && (temperatura! < -40 || temperatura! > 80)) {
      throw ArgumentError('Temperatura fuera de rango: $temperatura (-40 a 80°C)');
    }
  }

  /// Copia esta lectura con valores actualizados
  GasReading copyWith({
    String? zone,
    DateTime? timestamp,
    double? co,
    double? o2,
    double? co2,
    double? ch4,
    double? h2s,
    double? temperatura,
  }) {
    return GasReading(
      zone: zone ?? this.zone,
      timestamp: timestamp ?? this.timestamp,
      co: co ?? this.co,
      o2: o2 ?? this.o2,
      co2: co2 ?? this.co2,
      ch4: ch4 ?? this.ch4,
      h2s: h2s ?? this.h2s,
      temperatura: temperatura ?? this.temperatura,
    );
  }

  /// Convierte a JSON para serialización
  Map<String, dynamic> toJson() => {
    'zone': zone,
    'timestamp': timestamp.toIso8601String(),
    'co': co,
    'o2': o2,
    'co2': co2,
    'ch4': ch4,
    'h2s': h2s,
    'temperatura': temperatura,
  };

  @override
  String toString() =>
      'GasReading(zone: $zone, timestamp: $timestamp, co: $co, o2: $o2, co2: $co2, ch4: $ch4, h2s: $h2s, temp: $temperatura)';
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

class UserAccount {
  UserAccount({
    required this.id,
    required this.username,
    required this.displayName,
    this.email,
    this.document,
    this.googleId,
    this.authProvider = 'local',
    this.photoUrl,
    this.isEmailVerified = false,
    this.role = 'minero',
  });

  final String id;
  final String username;
  final String displayName;
  final String? email;
  final String? document;
  final String? googleId;
  final String authProvider; // 'local' | 'google'
  final String? photoUrl;
  final bool isEmailVerified;
  final String role;
}

class AuditLogEntry {
  AuditLogEntry({
    required this.id,
    required this.usuarioId,
    required this.accion,
    required this.modulo,
    this.detalles,
    this.nivel = 'INFO',
    this.ipOrigen = '127.0.0.1',
    required this.creadoEn,
  });

  final int id;
  final String usuarioId;
  final String accion;
  final String modulo;
  final String? detalles;
  final String nivel;
  final String ipOrigen;
  final DateTime creadoEn;
}

class BackupEntry {
  BackupEntry({
    required this.id,
    required this.nombreArchivo,
    required this.tamanoBytes,
    this.checksumSha256,
    this.tipo = 'COMPLETO',
    this.usuario = 'sistema',
    this.estado = 'EXITOSO',
    this.detalles,
    required this.creadoEn,
  });

  final int id;
  final String nombreArchivo;
  final int tamanoBytes;
  final String? checksumSha256;
  final String tipo;
  final String usuario;
  final String estado;
  final String? detalles;
  final DateTime creadoEn;
}

