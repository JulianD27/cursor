import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:postgres/postgres.dart';

import 'models.dart';

class DbConfig {
  const DbConfig({
    required this.host,
    required this.port,
    required this.database,
    required this.username,
    required this.password,
  });

  final String host;
  final int port;
  final String database;
  final String username;
  final String password;

  static const localDefault = DbConfig(
    host: 'localhost',
    port: 5432,
    database: 'miner_clc',
    username: 'postgres',
    password: 'minercl c123',
  );
}

class DatabaseService {
  DatabaseService({DbConfig? config}) : _config = config ?? DbConfig.localDefault;

  final DbConfig _config;
  PostgreSQLConnection? _conn;
  Future<PostgreSQLConnection>? _opening;

  final Map<String, Set<String>> _columnsCache = {};

  Future<PostgreSQLConnection> _connection() async {
    final existing = _conn;
    if (existing != null && existing.isClosed == false) {
      return existing;
    }

    final opening = _opening;
    if (opening != null) return opening;

    final fut = () async {
      final c = PostgreSQLConnection(
        _config.host,
        _config.port,
        _config.database,
        username: _config.username,
        password: _config.password,
        timeoutInSeconds: 8,
        useSSL: false,
      );

      await c.open();
      _conn = c;
      return c;
    }();

    _opening = fut;
    try {
      return await fut;
    } finally {
      _opening = null;
    }
  }

  Future<void> close() async {
    final c = _conn;
    _conn = null;
    if (c != null && c.isClosed == false) {
      await c.close();
    }
  }

  Future<Set<String>> columnsOf(String table) async {
    final cached = _columnsCache[table];
    if (cached != null) return cached;

    final c = await _connection();
    final rows = await c.query(
      '''
SELECT column_name
FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = @table
ORDER BY ordinal_position
''',
      substitutionValues: {'table': table},
    );

    final cols = <String>{};
    for (final r in rows) {
      if (r.isNotEmpty && r.first is String) cols.add((r.first as String));
    }

    _columnsCache[table] = cols;
    return cols;
  }

  Future<String?> tryAuthenticate({
    required String username,
    required String password,
  }) async {
    final cols = await columnsOf('usuarios');

    // Column fallbacks (we adapt to existing schema).
    final userCol = cols.contains('username')
        ? 'username'
        : (cols.contains('usuario') ? 'usuario' : null);
    final passCol = cols.contains('password_hash')
        ? 'password_hash'
        : (cols.contains('password') ? 'password' : null);
    final idCol = cols.contains('id') ? 'id' : null;

    if (userCol == null || passCol == null) {
      throw StateError(
        'La tabla usuarios debe tener columnas de usuario (username/usuario) y contraseña (password_hash/password).',
      );
    }

    final selectId = idCol ?? 'NULL';
    final c = await _connection();

    final rows = await c.query(
      '''
SELECT $selectId, $passCol
FROM usuarios
WHERE $userCol = @u
LIMIT 1
''',
      substitutionValues: {'u': username},
    );

    if (rows.isEmpty) return null;

    final row = rows.first;
    final id = row[0]?.toString();
    final stored = row[1]?.toString() ?? '';

    if (_verifyPassword(stored: stored, provided: password)) {
      return id ?? username;
    }
    return null;
  }

  Future<void> createUser({
    required String username,
    required String password,
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    final cols = await columnsOf('usuarios');

    final userCol = cols.contains('username')
        ? 'username'
        : (cols.contains('usuario') ? 'usuario' : null);
    final passCol = cols.contains('password_hash')
        ? 'password_hash'
        : (cols.contains('password') ? 'password' : null);

    if (userCol == null || passCol == null) {
      throw StateError(
        'La tabla usuarios debe tener columnas de usuario (username/usuario) y contraseña (password_hash/password).',
      );
    }

    final c = await _connection();

    // No permitir duplicados por usuario.
    final existing = await c.query(
      '''
SELECT 1
FROM usuarios
WHERE $userCol = @u
LIMIT 1
''',
      substitutionValues: {'u': username},
    );
    if (existing.isNotEmpty) {
      throw StateError('El usuario "$username" ya existe.');
    }

    // Preparamos columnas y valores, adaptándonos al esquema actual.
    final insertCols = <String>[userCol, passCol];
    final insertVals = <String>['@u', '@p'];
    final subs = <String, dynamic>{
      'u': username,
      'p': password,
    };

    // Si existe una columna "nombre" NOT NULL, usamos el dato proporcionado
    // (o el username como respaldo).
    if (cols.contains('nombre')) {
      insertCols.add('nombre');
      insertVals.add('@nombre');
      subs['nombre'] = (nombre.isNotEmpty ? nombre : username);
    }

    // Campos opcionales típicos: correo/email, documento, rol / creado_en / created_at.
    if (cols.contains('correo')) {
      insertCols.add('correo');
      insertVals.add('@correo');
      subs['correo'] = correo.isNotEmpty ? correo : null;
    } else if (cols.contains('email')) {
      insertCols.add('email');
      insertVals.add('@correo');
      subs['correo'] = correo.isNotEmpty ? correo : null;
    }

    final docCol = cols.contains('documento')
        ? 'documento'
        : (cols.contains('identificacion')
            ? 'identificacion'
            : (cols.contains('cedula') ? 'cedula' : null));
    if (docCol != null) {
      insertCols.add(docCol);
      insertVals.add('@doc');
      subs['doc'] = documento.isNotEmpty ? documento : null;
    }

    if (cols.contains('rol')) {
      insertCols.add('rol');
      insertVals.add('@rol');
      subs['rol'] = 'minero';
    }
    if (cols.contains('created_at')) {
      insertCols.add('created_at');
      insertVals.add('NOW()');
    } else if (cols.contains('creado_en')) {
      insertCols.add('creado_en');
      insertVals.add('NOW()');
    }

    await c.query(
      '''
INSERT INTO usuarios (${insertCols.join(', ')})
VALUES (${insertVals.join(', ')})
''',
      substitutionValues: subs,
    );
  }

  Future<void> updateUserProfile({
    required String username,
    required String nombre,
    required String correo,
    required String documento,
  }) async {
    final cols = await columnsOf('usuarios');

    final userCol = cols.contains('username')
        ? 'username'
        : (cols.contains('usuario') ? 'usuario' : null);
    if (userCol == null) {
      throw StateError('La tabla usuarios debe tener columna username/usuario para actualizar perfil.');
    }

    final setParts = <String>[];
    final subs = <String, dynamic>{'u': username};

    if (cols.contains('nombre')) {
      setParts.add('nombre = @nombre');
      subs['nombre'] = nombre.isNotEmpty ? nombre : username;
    }
    if (cols.contains('correo')) {
      setParts.add('correo = @correo');
      subs['correo'] = correo.isNotEmpty ? correo : null;
    } else if (cols.contains('email')) {
      setParts.add('email = @correo');
      subs['correo'] = correo.isNotEmpty ? correo : null;
    }

    final docCol = cols.contains('documento')
        ? 'documento'
        : (cols.contains('identificacion')
            ? 'identificacion'
            : (cols.contains('cedula') ? 'cedula' : null));
    if (docCol != null) {
      setParts.add('$docCol = @doc');
      subs['doc'] = documento.isNotEmpty ? documento : null;
    }

    if (setParts.isEmpty) return;

    final c = await _connection();
    await c.query(
      '''
UPDATE usuarios
SET ${setParts.join(', ')}
WHERE $userCol = @u
''',
      substitutionValues: subs,
    );
  }

  bool _verifyPassword({required String stored, required String provided}) {
    final trimmed = stored.trim();
    if (trimmed.isEmpty) return false;

    // Accept plaintext (common in demos) or SHA-256 hex.
    if (trimmed == provided) return true;

    final sha = sha256.convert(utf8.encode(provided)).toString();
    if (trimmed.toLowerCase() == sha.toLowerCase()) return true;

    // Accept "sha256:<hex>" formats.
    if (trimmed.toLowerCase().startsWith('sha256:')) {
      final hex = trimmed.substring('sha256:'.length).trim();
      if (hex.toLowerCase() == sha.toLowerCase()) return true;
    }

    return false;
  }

  Future<List<GasReading>> fetchLatestGasReadings({int limit = 200}) async {
    final cols = await columnsOf('lecturas_gases');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    final tsCol = cols.contains('timestamp')
        ? 'timestamp'
        : (cols.contains('fecha')
            ? 'fecha'
            : (cols.contains('created_at')
                ? 'created_at'
                : (cols.contains('registrado_en') ? 'registrado_en' : null)));

    if (zoneCol == null || tsCol == null) {
      throw StateError(
        'La tabla lecturas_gases debe tener columnas de zona (zona/zone) y fecha (timestamp/fecha/created_at/registrado_en).',
      );
    }

    String pick(String a, String b) => cols.contains(a) ? a : (cols.contains(b) ? b : '');

    final coCol = pick('co', 'CO');
    final o2Col = pick('o2', 'O2');
    final co2Col = pick('co2', 'CO2');
    final ch4Col = pick('ch4', 'CH4');
    final h2sCol = pick('h2s', 'H2S');
    final tCol = cols.contains('temperatura') ? 'temperatura' : (cols.contains('temp') ? 'temp' : '');

    final selectCols = <String>[
      zoneCol,
      tsCol,
      if (coCol.isNotEmpty) coCol,
      if (o2Col.isNotEmpty) o2Col,
      if (co2Col.isNotEmpty) co2Col,
      if (ch4Col.isNotEmpty) ch4Col,
      if (h2sCol.isNotEmpty) h2sCol,
      if (tCol.isNotEmpty) tCol,
    ];

    final c = await _connection();
    final rows = await c.query(
      '''
SELECT ${selectCols.join(', ')}
FROM lecturas_gases
ORDER BY $tsCol DESC
LIMIT @limit
''',
      substitutionValues: {'limit': limit},
    );

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime asDateTime(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final idx = {for (var i = 0; i < selectCols.length; i++) selectCols[i]: i};

    return rows.map((r) {
      final zone = (r[idx[zoneCol]!] ?? '').toString();
      final ts = asDateTime(r[idx[tsCol]!]);
      return GasReading(
        zone: zone,
        timestamp: ts,
        co: coCol.isEmpty ? null : asDouble(r[idx[coCol]!]),
        o2: o2Col.isEmpty ? null : asDouble(r[idx[o2Col]!]),
        co2: co2Col.isEmpty ? null : asDouble(r[idx[co2Col]!]),
        ch4: ch4Col.isEmpty ? null : asDouble(r[idx[ch4Col]!]),
        h2s: h2sCol.isEmpty ? null : asDouble(r[idx[h2sCol]!]),
        temperatura: tCol.isEmpty ? null : asDouble(r[idx[tCol]!]),
      );
    }).toList();
  }

  Future<List<GasReading>> fetchGasHistory({
    required String zone,
    int limit = 120,
  }) async {
    final cols = await columnsOf('lecturas_gases');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    final tsCol = cols.contains('timestamp')
        ? 'timestamp'
        : (cols.contains('fecha')
            ? 'fecha'
            : (cols.contains('created_at')
                ? 'created_at'
                : (cols.contains('registrado_en') ? 'registrado_en' : null)));

    if (zoneCol == null || tsCol == null) {
      throw StateError(
        'La tabla lecturas_gases debe tener columnas de zona (zona/zone) y fecha (timestamp/fecha/created_at/registrado_en).',
      );
    }

    String pick(String a, String b) => cols.contains(a) ? a : (cols.contains(b) ? b : '');

    final coCol = pick('co', 'CO');
    final o2Col = pick('o2', 'O2');
    final co2Col = pick('co2', 'CO2');
    final ch4Col = pick('ch4', 'CH4');
    final h2sCol = pick('h2s', 'H2S');
    final tCol = cols.contains('temperatura') ? 'temperatura' : (cols.contains('temp') ? 'temp' : '');

    final selectCols = <String>[
      zoneCol,
      tsCol,
      if (coCol.isNotEmpty) coCol,
      if (o2Col.isNotEmpty) o2Col,
      if (co2Col.isNotEmpty) co2Col,
      if (ch4Col.isNotEmpty) ch4Col,
      if (h2sCol.isNotEmpty) h2sCol,
      if (tCol.isNotEmpty) tCol,
    ];

    final c = await _connection();
    final rows = await c.query(
      '''
SELECT ${selectCols.join(', ')}
FROM lecturas_gases
WHERE $zoneCol = @zone
ORDER BY $tsCol DESC
LIMIT @limit
''',
      substitutionValues: {'zone': zone, 'limit': limit},
    );

    double? asDouble(dynamic v) {
      if (v == null) return null;
      if (v is num) return v.toDouble();
      return double.tryParse(v.toString());
    }

    DateTime asDateTime(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final idx = {for (var i = 0; i < selectCols.length; i++) selectCols[i]: i};

    return rows.map((r) {
      final z = (r[idx[zoneCol]!] ?? '').toString();
      final ts = asDateTime(r[idx[tsCol]!]);
      return GasReading(
        zone: z,
        timestamp: ts,
        co: coCol.isEmpty ? null : asDouble(r[idx[coCol]!]),
        o2: o2Col.isEmpty ? null : asDouble(r[idx[o2Col]!]),
        co2: co2Col.isEmpty ? null : asDouble(r[idx[co2Col]!]),
        ch4: ch4Col.isEmpty ? null : asDouble(r[idx[ch4Col]!]),
        h2s: h2sCol.isEmpty ? null : asDouble(r[idx[h2sCol]!]),
        temperatura: tCol.isEmpty ? null : asDouble(r[idx[tCol]!]),
      );
    }).toList();
  }

  Future<List<VentilationState>> fetchVentilation({int limit = 200}) async {
    final cols = await columnsOf('ventilacion');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    if (zoneCol == null) {
      throw StateError('La tabla ventilacion debe tener columna zona/zone.');
    }

    final modeCol = cols.contains('modo')
        ? 'modo'
        : (cols.contains('mode') ? 'mode' : (cols.contains('estado') ? 'estado' : null));
    final speedCol = cols.contains('velocidad')
        ? 'velocidad'
        : (cols.contains('speed') ? 'speed' : null);
    final tsCol = cols.contains('updated_at')
        ? 'updated_at'
        : (cols.contains('fecha') ? 'fecha' : (cols.contains('timestamp') ? 'timestamp' : null));

    Iterable<String>? maybe(String? v) => v == null ? null : [v];

    final selectCols = <String>[
      zoneCol,
      ...?maybe(modeCol),
      ...?maybe(speedCol),
      ...?maybe(tsCol),
    ];

    final c = await _connection();
    final orderBy = tsCol ?? zoneCol;
    final rows = await c.query(
      '''
SELECT ${selectCols.join(', ')}
FROM ventilacion
ORDER BY $orderBy DESC
LIMIT @limit
''',
      substitutionValues: {'limit': limit},
    );

    VentMode parseMode(dynamic v) {
      final s = (v ?? '').toString().toLowerCase().trim();
      if (s == 'on' || s == 'encendido' || s == '1' || s == 'true') return VentMode.on;
      if (s == 'off' || s == 'apagado' || s == '0' || s == 'false') return VentMode.off;
      return VentMode.auto;
    }

    int parseSpeed(dynamic v) {
      if (v is int) return v.clamp(0, 100);
      if (v is num) return v.toInt().clamp(0, 100);
      return int.tryParse(v.toString())?.clamp(0, 100) ?? 0;
    }

    DateTime parseDt(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final idx = {for (var i = 0; i < selectCols.length; i++) selectCols[i]: i};

    return rows.map((r) {
      final zone = (r[idx[zoneCol]!] ?? '').toString();
      final mode = modeCol == null ? VentMode.auto : parseMode(r[idx[modeCol]!]);
      final speed = speedCol == null ? 0 : parseSpeed(r[idx[speedCol]!]);
      final updated = tsCol == null ? DateTime.now() : parseDt(r[idx[tsCol]!]);
      return VentilationState(zone: zone, mode: mode, speed: speed, updatedAt: updated);
    }).toList();
  }

  Future<List<MinerAlert>> fetchAlerts({
    bool? resolved,
    String? zone,
    int limit = 200,
  }) async {
    final cols = await columnsOf('alertas');
    final idCol = cols.contains('id') ? 'id' : (cols.contains('alerta_id') ? 'alerta_id' : null);
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    final msgCol = cols.contains('mensaje')
        ? 'mensaje'
        : (cols.contains('message') ? 'message' : (cols.contains('descripcion') ? 'descripcion' : null));
    final lvlCol = cols.contains('nivel')
        ? 'nivel'
        : (cols.contains('level') ? 'level' : (cols.contains('severidad') ? 'severidad' : null));
    final createdCol = cols.contains('created_at')
        ? 'created_at'
        : (cols.contains('fecha')
            ? 'fecha'
            : (cols.contains('timestamp')
                ? 'timestamp'
                : (cols.contains('creado_en') ? 'creado_en' : null)));
    final resolvedCol = cols.contains('resuelta')
        ? 'resuelta'
        : (cols.contains('resolved') ? 'resolved' : null);
    final resolvedAtCol = cols.contains('resolved_at')
        ? 'resolved_at'
        : (cols.contains('resuelta_at') ? 'resuelta_at' : null);

    if (idCol == null || zoneCol == null || msgCol == null || createdCol == null) {
      throw StateError(
        'La tabla alertas debe tener id, zona, mensaje y fecha (created_at/fecha/timestamp/creado_en).',
      );
    }

    Iterable<String>? maybe(String? v) => v == null ? null : [v];

    final selectCols = <String>[
      idCol,
      zoneCol,
      msgCol,
      ...?maybe(lvlCol),
      createdCol,
      ...?maybe(resolvedCol),
      ...?maybe(resolvedAtCol),
    ];

    final where = <String>[];
    final subs = <String, dynamic>{'limit': limit};

    if (zone != null && zone.trim().isNotEmpty) {
      where.add('$zoneCol = @zone');
      subs['zone'] = zone.trim();
    }
    if (resolved != null && resolvedCol != null) {
      where.add('$resolvedCol = @resolved');
      subs['resolved'] = resolved;
    }

    final whereSql = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final c = await _connection();
    final rows = await c.query(
      '''
SELECT ${selectCols.join(', ')}
FROM alertas
$whereSql
ORDER BY $createdCol DESC
LIMIT @limit
''',
      substitutionValues: subs,
    );

    bool parseBool(dynamic v) {
      if (v is bool) return v;
      final s = (v ?? '').toString().toLowerCase().trim();
      return s == 'true' || s == '1' || s == 't' || s == 'si' || s == 'sí';
    }

    DateTime parseDt(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final idx = {for (var i = 0; i < selectCols.length; i++) selectCols[i]: i};

    return rows.map((r) {
      final id = (r[idx[idCol]!] ?? '').toString();
      final z = (r[idx[zoneCol]!] ?? '').toString();
      final msg = (r[idx[msgCol]!] ?? '').toString();
      final lvl = lvlCol == null ? 'info' : (r[idx[lvlCol]!] ?? 'info').toString();
      final created = parseDt(r[idx[createdCol]!]);
      final res = resolvedCol == null ? false : parseBool(r[idx[resolvedCol]!]);
      final resAt = resolvedAtCol == null ? null : parseDt(r[idx[resolvedAtCol]!]);
      return MinerAlert(
        id: id,
        zone: z,
        message: msg,
        level: lvl,
        createdAt: created,
        resolved: res,
        resolvedAt: resAt,
      );
    }).toList();
  }

  Future<void> createAlert({
    required String zone,
    required String message,
    String level = 'warn',
  }) async {
    final cols = await columnsOf('alertas');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    final msgCol = cols.contains('mensaje')
        ? 'mensaje'
        : (cols.contains('message') ? 'message' : (cols.contains('descripcion') ? 'descripcion' : null));
    final lvlCol = cols.contains('nivel')
        ? 'nivel'
        : (cols.contains('level') ? 'level' : (cols.contains('severidad') ? 'severidad' : null));
    final resolvedCol = cols.contains('resuelta')
        ? 'resuelta'
        : (cols.contains('resolved') ? 'resolved' : null);

    if (zoneCol == null || msgCol == null) {
      throw StateError('La tabla alertas debe tener zona y mensaje.');
    }

    final insertCols = <String>[zoneCol, msgCol];
    final insertVals = <String>['@zone', '@msg'];
    final subs = <String, dynamic>{
      'zone': zone,
      'msg': message,
    };

    if (lvlCol != null) {
      insertCols.add(lvlCol);
      insertVals.add('@level');
      subs['level'] = level;
    }
    if (resolvedCol != null) {
      insertCols.add(resolvedCol);
      insertVals.add('@resolved');
      subs['resolved'] = false;
    }

    final c = await _connection();
    await c.query(
      '''
INSERT INTO alertas (${insertCols.join(', ')})
VALUES (${insertVals.join(', ')})
''',
      substitutionValues: subs,
    );
  }

  Future<void> markAlertResolved({required String id}) async {
    final cols = await columnsOf('alertas');
    final idCol = cols.contains('id') ? 'id' : (cols.contains('alerta_id') ? 'alerta_id' : null);
    final resolvedCol = cols.contains('resuelta')
        ? 'resuelta'
        : (cols.contains('resolved') ? 'resolved' : null);
    final resolvedAtCol = cols.contains('resolved_at')
        ? 'resolved_at'
        : (cols.contains('resuelta_at') ? 'resuelta_at' : null);

    if (idCol == null || resolvedCol == null) {
      throw StateError('La tabla alertas debe tener id y resuelta/resolved.');
    }

    final setParts = <String>['$resolvedCol = @resolved'];
    final subs = <String, dynamic>{'resolved': true, 'id': id};

    if (resolvedAtCol != null) {
      setParts.add('$resolvedAtCol = NOW()');
    }

    final c = await _connection();
    await c.query(
      '''
UPDATE alertas
SET ${setParts.join(', ')}
WHERE $idCol = @id
''',
      substitutionValues: subs,
    );
  }

  Future<void> setVentilation({
    required String zone,
    required VentMode mode,
    required int speed,
  }) async {
    final cols = await columnsOf('ventilacion');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : null);
    if (zoneCol == null) {
      throw StateError('La tabla ventilacion debe tener zona/zone.');
    }

    final modeCol = cols.contains('modo')
        ? 'modo'
        : (cols.contains('mode') ? 'mode' : (cols.contains('estado') ? 'estado' : null));
    final speedCol = cols.contains('velocidad')
        ? 'velocidad'
        : (cols.contains('speed') ? 'speed' : null);
    final updatedCol = cols.contains('updated_at')
        ? 'updated_at'
        : (cols.contains('fecha') ? 'fecha' : (cols.contains('timestamp') ? 'timestamp' : null));

    final modeValue = switch (mode) {
      VentMode.on => 'ON',
      VentMode.off => 'OFF',
      VentMode.auto => 'AUTO',
    };

    // We try UPDATE first. If 0 rows affected and an id column isn't known,
    // we attempt an INSERT (best-effort upsert-like behavior).
    final setParts = <String>[];
    final subs = <String, dynamic>{'zone': zone};

    if (modeCol != null) {
      setParts.add('$modeCol = @mode');
      subs['mode'] = modeValue;
    }
    if (speedCol != null) {
      setParts.add('$speedCol = @speed');
      subs['speed'] = speed.clamp(0, 100);
    }
    if (updatedCol != null) {
      setParts.add('$updatedCol = NOW()');
    }

    if (setParts.isEmpty) return;

    final c = await _connection();
    final updated = await c.execute(
      '''
UPDATE ventilacion
SET ${setParts.join(', ')}
WHERE $zoneCol = @zone
''',
      substitutionValues: subs,
    );

    if (updated == 0) {
      final insertCols = <String>[zoneCol];
      final insertVals = <String>['@zone'];
      final insertSubs = <String, dynamic>{'zone': zone};

      if (modeCol != null) {
        insertCols.add(modeCol);
        insertVals.add('@mode');
        insertSubs['mode'] = modeValue;
      }
      if (speedCol != null) {
        insertCols.add(speedCol);
        insertVals.add('@speed');
        insertSubs['speed'] = speed.clamp(0, 100);
      }
      if (updatedCol != null) {
        insertCols.add(updatedCol);
        insertVals.add('NOW()');
      }

      await c.query(
        '''
INSERT INTO ventilacion (${insertCols.join(', ')})
VALUES (${insertVals.join(', ')})
''',
        substitutionValues: insertSubs,
      );
    }
  }
}

