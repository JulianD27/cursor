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

  static const Map<int, String> _zonaIds = {
    1: "Norte - Nivel 1",
    2: "Sur - Nivel 2",
    3: "Este - Nivel 3",
    4: "Oeste - Nivel 1",
    5: "Central - Nivel 2",
  };

  static const Map<String, int> _idToZona = {
    "Norte - Nivel 1": 1,
    "Sur - Nivel 2": 2,
    "Este - Nivel 3": 3,
    "Oeste - Nivel 1": 4,
    "Central - Nivel 2": 5,
  };

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
        'La tabla usuarios debe tener columnas de usuario (username/usuario) y contraseÃ±a (password_hash/password).',
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
        'La tabla usuarios debe tener columnas de usuario (username/usuario) y contraseÃ±a (password_hash/password).',
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

    // Preparamos columnas y valores, adaptÃ¡ndonos al esquema actual.
    final passwordValue = passCol == 'password_hash' ? _hashPassword(password) : password;
    final insertCols = <String>[userCol, passCol];
    final insertVals = <String>['@u', '@p'];
    final subs = <String, dynamic>{
      'u': username,
      'p': passwordValue,
    };

    // Si existe una columna "nombre" NOT NULL, usamos el dato proporcionado
    // (o el username como respaldo).
    if (cols.contains('nombre')) {
      insertCols.add('nombre');
      insertVals.add('@nombre');
      subs['nombre'] = (nombre.isNotEmpty ? nombre : username);
    }

    // Campos opcionales tÃ­picos: correo/email, documento, rol / creado_en / created_at.
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

  Future<void> resetPassword({
    required String username,
    required String identificacion,
    required String newPassword,
  }) async {
    final cols = await columnsOf('usuarios');

    final userCol = cols.contains('username')
        ? 'username'
        : (cols.contains('usuario') ? 'usuario' : null);
    final idCol = cols.contains('identificacion')
        ? 'identificacion'
        : (cols.contains('documento')
            ? 'documento'
            : (cols.contains('cedula') ? 'cedula' : null));
    final passCol = cols.contains('password_hash')
        ? 'password_hash'
        : (cols.contains('password') ? 'password' : null);

    if (userCol == null || idCol == null || passCol == null) {
      throw StateError(
        'La tabla usuarios debe tener columnas de usuario, identificacion/documento/cedula y contraseÃ±a.',
      );
    }

    final c = await _connection();
    final rows = await c.query(
      '''
SELECT 1
FROM usuarios
WHERE $userCol = @u AND $idCol = @doc
LIMIT 1
''',
      substitutionValues: {'u': username, 'doc': identificacion},
    );

    if (rows.isEmpty) {
      throw StateError('Usuario o documento de identidad incorrecto.');
    }

    await c.query(
      '''
UPDATE usuarios
SET $passCol = @p
WHERE $userCol = @u AND $idCol = @doc
''',
      substitutionValues: {
        'p': passCol == 'password_hash' ? _hashPassword(newPassword) : newPassword,
        'u': username,
        'doc': identificacion,
      },
    );
  }

  Future<UserAccount> authenticateWithGoogle({
    required String googleId,
    required String email,
    required String name,
    String? photoUrl,
  }) async {
    final cols = await columnsOf('usuarios');
    final c = await _connection();

    final userCol = cols.contains('username') ? 'username' : (cols.contains('usuario') ? 'usuario' : 'usuario');
    final idCol = cols.contains('id') ? 'id' : 'id';
    final emailCol = cols.contains('email') ? 'email' : (cols.contains('correo') ? 'correo' : null);

    // Buscar si ya existe por google_id o por email
    final queryCondition = (cols.contains('google_id') && emailCol != null)
        ? 'google_id = @gid OR $emailCol = @email'
        : (emailCol != null ? '$emailCol = @email' : '$userCol = @u');

    final existing = await c.query(
      '''
SELECT $idCol, $userCol, nombre, ${emailCol ?? 'NULL'} as email, ${cols.contains('foto_url') ? 'foto_url' : 'NULL'} as foto
FROM usuarios
WHERE $queryCondition
LIMIT 1
''',
      substitutionValues: {
        'gid': googleId,
        'email': email,
        'u': email.split('@').first,
      },
    );

    if (existing.isNotEmpty) {
      final row = existing.first;
      final id = (row[0] ?? '').toString();
      final username = (row[1] ?? email.split('@').first).toString();
      final displayName = (row[2] ?? name).toString();

      // Actualizar Ãºltimo acceso y google_id si faltaba
      final updates = <String>[];
      final updateSubs = <String, dynamic>{'id': int.tryParse(id) ?? id};

      if (cols.contains('ultimo_acceso')) updates.add('ultimo_acceso = NOW()');
      if (cols.contains('google_id')) {
        updates.add('google_id = @gid');
        updateSubs['gid'] = googleId;
      }
      if (cols.contains('email_verificado')) updates.add('email_verificado = TRUE');
      if (cols.contains('foto_url') && photoUrl != null) {
        updates.add('foto_url = @photo');
        updateSubs['photo'] = photoUrl;
      }

      if (updates.isNotEmpty) {
        await c.query(
          '''
UPDATE usuarios
SET ${updates.join(', ')}
WHERE $idCol = @id
''',
          substitutionValues: updateSubs,
        );
      }

      await logAudit(
        usuarioId: username,
        accion: 'LOGIN_GOOGLE',
        modulo: 'AUTH',
        detalles: 'Inicio de sesiÃ³n exitoso con cuenta Google real: $email',
        nivel: 'INFO',
      );

      return UserAccount(
        id: id,
        username: username,
        displayName: displayName.isNotEmpty ? displayName : name,
        email: email,
        googleId: googleId,
        authProvider: 'google',
        photoUrl: photoUrl,
        isEmailVerified: true,
      );
    }

    // Si no existe, registrar nuevo usuario proveniente de Google
    final baseUsername = email.split('@').first.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    var finalUsername = baseUsername;

    final userCheck = await c.query(
      'SELECT 1 FROM usuarios WHERE $userCol = @u LIMIT 1',
      substitutionValues: {'u': finalUsername},
    );
    if (userCheck.isNotEmpty) {
      finalUsername = '${baseUsername}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    }

    final passCol = cols.contains('password_hash') ? 'password_hash' : 'password';
    final dummyPass = _hashPassword('google_oauth_$googleId');

    final insCols = <String>[userCol, passCol, 'nombre'];
    final insVals = <String>['@u', '@p', '@nombre'];
    final insSubs = <String, dynamic>{
      'u': finalUsername,
      'p': dummyPass,
      'nombre': name.isNotEmpty ? name : finalUsername,
    };

    if (emailCol != null) {
      insCols.add(emailCol);
      insVals.add('@email');
      insSubs['email'] = email;
    }
    if (cols.contains('google_id')) {
      insCols.add('google_id');
      insVals.add('@gid');
      insSubs['gid'] = googleId;
    }
    if (cols.contains('auth_provider')) {
      insCols.add('auth_provider');
      insVals.add('@provider');
      insSubs['provider'] = 'google';
    }
    if (cols.contains('foto_url') && photoUrl != null) {
      insCols.add('foto_url');
      insVals.add('@foto');
      insSubs['foto'] = photoUrl;
    }
    if (cols.contains('email_verificado')) {
      insCols.add('email_verificado');
      insVals.add('TRUE');
    }
    if (cols.contains('rol')) {
      insCols.add('rol');
      insVals.add('@rol');
      insSubs['rol'] = 'minero';
    }
    if (cols.contains('created_at')) {
      insCols.add('created_at');
      insVals.add('NOW()');
    } else if (cols.contains('creado_en')) {
      insCols.add('creado_en');
      insVals.add('NOW()');
    }
    if (cols.contains('ultimo_acceso')) {
      insCols.add('ultimo_acceso');
      insVals.add('NOW()');
    }

    final insertRes = await c.query(
      '''
INSERT INTO usuarios (${insCols.join(', ')})
VALUES (${insVals.join(', ')})
RETURNING $idCol
''',
      substitutionValues: insSubs,
    );

    final newId = insertRes.isNotEmpty ? insertRes.first[0]?.toString() ?? finalUsername : finalUsername;

    await logAudit(
      usuarioId: finalUsername,
      accion: 'REGISTRO_GOOGLE',
      modulo: 'AUTH',
      detalles: 'Nuevo usuario registrado con cuenta de Google real: $email',
      nivel: 'INFO',
    );

    return UserAccount(
      id: newId,
      username: finalUsername,
      displayName: name,
      email: email,
      googleId: googleId,
      authProvider: 'google',
      photoUrl: photoUrl,
      isEmailVerified: true,
    );
  }

  Future<void> logAudit({
    required String usuarioId,
    required String accion,
    required String modulo,
    String? detalles,
    String nivel = 'INFO',
    String ipOrigen = '127.0.0.1',
  }) async {
    try {
      final c = await _connection();
      await c.query(
        '''
INSERT INTO auditoria_logs (usuario_id, accion, modulo, detalles, nivel, ip_origen, creado_en)
VALUES (@u, @acc, @mod, @det, @niv, @ip, NOW())
''',
        substitutionValues: {
          'u': usuarioId,
          'acc': accion,
          'mod': modulo,
          'det': detalles,
          'niv': nivel,
          'ip': ipOrigen,
        },
      );
    } catch (e) {
      print('Advertencia al registrar auditorÃ­a: $e');
    }
  }

  Future<List<AuditLogEntry>> fetchAuditLogs({int limit = 50}) async {
    try {
      final c = await _connection();
      final rows = await c.query(
        '''
SELECT id, usuario_id, accion, modulo, detalles, nivel, ip_origen, creado_en
FROM auditoria_logs
ORDER BY creado_en DESC
LIMIT @limit
''',
        substitutionValues: {'limit': limit},
      );

      return rows.map((r) => AuditLogEntry(
        id: (r[0] is int) ? r[0] as int : int.tryParse(r[0].toString()) ?? 0,
        usuarioId: (r[1] ?? 'sistema').toString(),
        accion: (r[2] ?? '').toString(),
        modulo: (r[3] ?? '').toString(),
        detalles: r[4]?.toString(),
        nivel: (r[5] ?? 'INFO').toString(),
        ipOrigen: (r[6] ?? '127.0.0.1').toString(),
        creadoEn: (r[7] is DateTime) ? r[7] as DateTime : DateTime.tryParse(r[7].toString()) ?? DateTime.now(),
      )).toList();
    } catch (e) {
      print('Error al consultar logs de auditorÃ­a: $e');
      return [];
    }
  }

  Future<void> registerBackup({
    required String nombreArchivo,
    required int tamanoBytes,
    required String checksumSha256,
    String tipo = 'COMPLETO',
    String usuario = 'sistema',
    String estado = 'EXITOSO',
    String? detalles,
  }) async {
    try {
      final c = await _connection();
      await c.query(
        '''
INSERT INTO respaldos_historial (nombre_archivo, tamano_bytes, checksum_sha256, tipo, usuario, estado, detalles, creado_en)
VALUES (@nom, @tam, @chk, @tipo, @usu, @est, @det, NOW())
''',
        substitutionValues: {
          'nom': nombreArchivo,
          'tam': tamanoBytes,
          'chk': checksumSha256,
          'tipo': tipo,
          'usu': usuario,
          'est': estado,
          'det': detalles,
        },
      );
      await logAudit(
        usuarioId: usuario,
        accion: 'RESPALDO_DATOS',
        modulo: 'DATABASE',
        detalles: 'Respaldo generado: $nombreArchivo ($tamanoBytes bytes)',
        nivel: 'INFO',
      );
    } catch (e) {
      print('Error registrando historial de respaldo: $e');
    }
  }

  Future<List<BackupEntry>> fetchBackups({int limit = 20}) async {
    try {
      final c = await _connection();
      final rows = await c.query(
        '''
SELECT id, nombre_archivo, tamano_bytes, checksum_sha256, tipo, usuario, estado, detalles, creado_en
FROM respaldos_historial
ORDER BY creado_en DESC
LIMIT @limit
''',
        substitutionValues: {'limit': limit},
      );

      return rows.map((r) => BackupEntry(
        id: (r[0] is int) ? r[0] as int : int.tryParse(r[0].toString()) ?? 0,
        nombreArchivo: (r[1] ?? '').toString(),
        tamanoBytes: (r[2] is num) ? (r[2] as num).toInt() : int.tryParse(r[2].toString()) ?? 0,
        checksumSha256: r[3]?.toString(),
        tipo: (r[4] ?? 'COMPLETO').toString(),
        usuario: (r[5] ?? 'sistema').toString(),
        estado: (r[6] ?? 'EXITOSO').toString(),
        detalles: r[7]?.toString(),
        creadoEn: (r[8] is DateTime) ? r[8] as DateTime : DateTime.tryParse(r[8].toString()) ?? DateTime.now(),
      )).toList();
    } catch (e) {
      print('Error al consultar historial de respaldos: $e');
      return [];
    }
  }

  String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
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
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
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
      var zone = (r[idx[zoneCol]!] ?? '').toString();
      if (zoneCol == 'zona_id') {
        final zid = int.tryParse(zone);
        if (zid != null && _zonaIds.containsKey(zid)) {
          zone = _zonaIds[zid]!;
        }
      }
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
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
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
      substitutionValues: {'zone': zoneCol == 'zona_id' ? (_idToZona[zone] ?? 1) : zone, 'limit': limit},
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
      var z = (r[idx[zoneCol]!] ?? '').toString();
      if (zoneCol == 'zona_id') {
        final zid = int.tryParse(z);
        if (zid != null && _zonaIds.containsKey(zid)) {
          z = _zonaIds[zid]!;
        }
      }
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

  List<String> _ventilationModeColumns(Set<String> cols) {
    final modeCols = <String>[];
    if (cols.contains('estado')) modeCols.add('estado');
    if (cols.contains('modo')) modeCols.add('modo');
    if (cols.contains('mode')) modeCols.add('mode');
    return modeCols;
  }

  String? _ventilationUpdatedColumn(Set<String> cols) {
    if (cols.contains('actualizado_en')) return 'actualizado_en';
    if (cols.contains('updated_at')) return 'updated_at';
    if (cols.contains('fecha')) return 'fecha';
    if (cols.contains('timestamp')) return 'timestamp';
    return null;
  }

  Future<List<VentilationState>> fetchVentilation({int limit = 200}) async {
    final cols = await columnsOf('ventilacion');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    if (zoneCol == null) {
      throw StateError('La tabla ventilacion debe tener columna zona/zone.');
    }

    final modeCols = _ventilationModeColumns(cols);
    final speedCol = cols.contains('velocidad')
        ? 'velocidad'
        : (cols.contains('speed') ? 'speed' : null);
    final tsCol = _ventilationUpdatedColumn(cols);

    Iterable<String>? maybe(String? v) => v == null ? null : [v];

    final selectCols = <String>[
      zoneCol,
      ...modeCols,
      ...?maybe(speedCol),
      ...?maybe(tsCol),
    ];

    final c = await _connection();
    final orderBy = tsCol ?? zoneCol;
    final rows = await c.query(
      '''
SELECT ${selectCols.join(', ')}
FROM (
  SELECT ${selectCols.join(', ')},
         ROW_NUMBER() OVER (PARTITION BY $zoneCol ORDER BY $orderBy DESC) AS rn
  FROM ventilacion
) v
WHERE rn = 1
ORDER BY $zoneCol
LIMIT @limit
''',
      substitutionValues: {'limit': limit},
    );

    VentMode parseMode(dynamic estadoValue, dynamic modoValue, int speed) {
      String normalized(String? raw) {
        return (raw ?? '').toString().toLowerCase().trim();
      }

      final estado = normalized(estadoValue as String?);
      if (estado.isNotEmpty) {
        if (estado == 'on' || estado == 'encendido' || estado == '1' || estado == 'true') {
          return VentMode.on;
        }
        if (estado == 'off' || estado == 'apagado' || estado == '0' || estado == 'false') {
          return VentMode.off;
        }
        if (estado == 'auto' || estado == 'automatico') {
          return VentMode.auto;
        }
      }

      final modo = normalized(modoValue as String?);
      if (modo.isNotEmpty) {
        if (modo == 'on' || modo == 'encendido' || modo == '1' || modo == 'true') {
          return VentMode.on;
        }
        if (modo == 'off' || modo == 'apagado' || modo == '0' || modo == 'false') {
          return VentMode.off;
        }
        if (modo == 'auto' || modo == 'automatico') {
          return VentMode.auto;
        }
        if (modo == 'manual') {
          return speed > 0 ? VentMode.on : VentMode.off;
        }
      }

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
      var zone = (r[idx[zoneCol]!] ?? '').toString();
      if (zoneCol == 'zona_id') {
        final zid = int.tryParse(zone);
        if (zid != null && _zonaIds.containsKey(zid)) {
          zone = _zonaIds[zid]!;
        }
      }
      final speed = speedCol == null ? 0 : parseSpeed(r[idx[speedCol]!]);
      final mode = modeCols.isEmpty
          ? VentMode.auto
          : parseMode(
              modeCols.contains('estado') ? r[idx['estado']!] : null,
              modeCols.contains('modo') ? r[idx['modo']!] : null,
              speed,
            );
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
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    final msgCol = cols.contains('mensaje')
        ? 'mensaje'
        : (cols.contains('message') ? 'message' : (cols.contains('descripcion') ? 'descripcion' : null));
    final tipoCol = cols.contains('tipo') ? 'tipo' : null;
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
      ...?maybe(tipoCol),
      createdCol,
      ...?maybe(resolvedCol),
      ...?maybe(resolvedAtCol),
    ];

    final where = <String>[];
    final subs = <String, dynamic>{'limit': limit};

    if (zone != null && zone.trim().isNotEmpty) {
      where.add('$zoneCol = @zone');
      subs['zone'] = zoneCol == 'zona_id' ? (_idToZona[zone.trim()] ?? 1) : zone.trim();
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
      return s == 'true' || s == '1' || s == 't' || s == 'si' || s == 'sÃ­';
    }

    DateTime parseDt(dynamic v) {
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString()) ?? DateTime.now();
    }

    final idx = {for (var i = 0; i < selectCols.length; i++) selectCols[i]: i};

    return rows.map((r) {
      final id = (r[idx[idCol]!] ?? '').toString();
      var z = (r[idx[zoneCol]!] ?? '').toString();
      if (zoneCol == 'zona_id') {
        final zid = int.tryParse(z);
        if (zid != null && _zonaIds.containsKey(zid)) {
          z = _zonaIds[zid]!;
        }
      }
      final msg = (r[idx[msgCol]!] ?? '').toString();
      final lvlRaw = (tipoCol != null && r[idx[tipoCol]!] != null)
          ? r[idx[tipoCol]!]
          : (lvlCol != null && r[idx[lvlCol]!] != null ? r[idx[lvlCol]!] : 'info');
      final lvl = lvlRaw.toString().trim();
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
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    final msgCol = cols.contains('mensaje')
        ? 'mensaje'
        : (cols.contains('message') ? 'message' : (cols.contains('descripcion') ? 'descripcion' : null));
    final lvlCol = cols.contains('nivel')
        ? 'nivel'
        : (cols.contains('level') ? 'level' : (cols.contains('severidad') ? 'severidad' : null));
    final tipoCol = cols.contains('tipo') ? 'tipo' : null;
    final resolvedCol = cols.contains('resuelta')
        ? 'resuelta'
        : (cols.contains('resolved') ? 'resolved' : null);

    if (zoneCol == null || msgCol == null) {
      throw StateError('La tabla alertas debe tener zona y mensaje.');
    }

    final insertCols = <String>[zoneCol, msgCol];
    final insertVals = <String>['@zone', '@msg'];
    final subs = <String, dynamic>{
      'zone': zoneCol == 'zona_id' ? (_idToZona[zone] ?? 1) : zone,
      'msg': message,
    };

    if (lvlCol != null) {
      insertCols.add(lvlCol);
      insertVals.add('@level');
      subs['level'] = level;
    }
    if (tipoCol != null && tipoCol != lvlCol) {
      insertCols.add(tipoCol);
      insertVals.add('@tipo');
      subs['tipo'] = level;
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
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    if (zoneCol == null) {
      throw StateError('La tabla ventilacion debe tener zona/zone.');
    }

    final validModeCols = _ventilationModeColumns(cols);
    final speedCol = cols.contains('velocidad')
        ? 'velocidad'
        : (cols.contains('speed') ? 'speed' : null);
    final updatedCol = _ventilationUpdatedColumn(cols);

    final modeValue = switch (mode) {
      VentMode.on => 'ON',
      VentMode.off => 'OFF',
      VentMode.auto => 'AUTO',
    };

    final setParts = <String>[];
    final subs = <String, dynamic>{
      'zone': zoneCol == 'zona_id' ? (_idToZona[zone] ?? 1) : zone,
      'speed': speed.clamp(0, 100),
    };

    if (validModeCols.contains('estado')) {
      setParts.add('estado = @estado');
      subs['estado'] = modeValue;
    }
    if (validModeCols.contains('modo')) {
      setParts.add('modo = @modo');
      subs['modo'] = mode == VentMode.auto ? 'AUTO' : 'MANUAL';
    } else if (validModeCols.contains('mode')) {
      setParts.add('mode = @mode');
      subs['mode'] = modeValue;
    }
    if (speedCol != null) {
      setParts.add('$speedCol = @speed');
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
      final insertSubs = <String, dynamic>{'zone': zoneCol == 'zona_id' ? (_idToZona[zone] ?? 1) : zone};

      if (validModeCols.contains('estado')) {
        insertCols.add('estado');
        insertVals.add('@estado');
        insertSubs['estado'] = modeValue;
      }
      if (validModeCols.contains('modo')) {
        insertCols.add('modo');
        insertVals.add('@modo');
        insertSubs['modo'] = mode == VentMode.auto ? 'AUTO' : 'MANUAL';
      } else if (validModeCols.contains('mode')) {
        insertCols.add('mode');
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

  /// Inserta una nueva lectura de gases desde los sensores
  /// Esta es una operaciÃ³n crÃ­tica que debe validar datos antes de guardar
  Future<void> insertGasReading({
    required GasReading reading,
  }) async {
    // ValidaciÃ³n de datos
    if (reading.zone.trim().isEmpty) {
      throw ArgumentError('La zona no puede estar vacÃ­a');
    }

    // Al menos un valor de gas debe ser vÃ¡lido
    final hasGasValues = reading.co != null ||
        reading.o2 != null ||
        reading.co2 != null ||
        reading.ch4 != null ||
        reading.h2s != null;

    if (!hasGasValues) {
      throw ArgumentError('Al menos un valor de gas debe ser proporcionado');
    }

    // Validar que los valores de gases estÃ©n en rangos razonables
    _validateGasValue('CO', reading.co, 0, 1000);
    _validateGasValue('O2', reading.o2, 0, 100);
    _validateGasValue('CO2', reading.co2, 0, 100);
    _validateGasValue('CH4', reading.ch4, 0, 100);
    _validateGasValue('H2S', reading.h2s, 0, 100);
    _validateGasValue('Temperatura', reading.temperatura, -40, 80);

    final cols = await columnsOf('lecturas_gases');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    final tsCol = cols.contains('timestamp')
        ? 'timestamp'
        : (cols.contains('fecha')
            ? 'fecha'
            : (cols.contains('created_at')
                ? 'created_at'
                : (cols.contains('registrado_en') 
                    ? 'registrado_en'
                    : null)));

    if (zoneCol == null || tsCol == null) {
      throw StateError(
        'La tabla lecturas_gases debe tener columnas de zona y timestamp',
      );
    }

    final insertCols = <String>[zoneCol, tsCol];
    final insertVals = <String>['@zone', '@ts'];
    final subs = <String, dynamic>{
      'zone': zoneCol == 'zona_id' ? (_idToZona[reading.zone] ?? 1) : reading.zone,
      'ts': reading.timestamp,
    };

    String pick(String a, String b) => cols.contains(a) ? a : (cols.contains(b) ? b : '');

    // Agregar valores de gases (solo si existen)
    final coCol = pick('co', 'CO');
    if (coCol.isNotEmpty && reading.co != null) {
      insertCols.add(coCol);
      insertVals.add('@co');
      subs['co'] = reading.co;
    }

    final o2Col = pick('o2', 'O2');
    if (o2Col.isNotEmpty && reading.o2 != null) {
      insertCols.add(o2Col);
      insertVals.add('@o2');
      subs['o2'] = reading.o2;
    }

    final co2Col = pick('co2', 'CO2');
    if (co2Col.isNotEmpty && reading.co2 != null) {
      insertCols.add(co2Col);
      insertVals.add('@co2');
      subs['co2'] = reading.co2;
    }

    final ch4Col = pick('ch4', 'CH4');
    if (ch4Col.isNotEmpty && reading.ch4 != null) {
      insertCols.add(ch4Col);
      insertVals.add('@ch4');
      subs['ch4'] = reading.ch4;
    }

    final h2sCol = pick('h2s', 'H2S');
    if (h2sCol.isNotEmpty && reading.h2s != null) {
      insertCols.add(h2sCol);
      insertVals.add('@h2s');
      subs['h2s'] = reading.h2s;
    }

    final tCol = cols.contains('temperatura') ? 'temperatura' : (cols.contains('temp') ? 'temp' : '');
    if (tCol.isNotEmpty && reading.temperatura != null) {
      insertCols.add(tCol);
      insertVals.add('@temp');
      subs['temp'] = reading.temperatura;
    }

    try {
      final c = await _connection();
      await c.query(
        '''
INSERT INTO lecturas_gases (${insertCols.join(', ')})
VALUES (${insertVals.join(', ')})
''',
        substitutionValues: subs,
      );
    } catch (e) {
      throw DatabaseException('Error al guardar lectura de gases: ${e.toString()}');
    }
  }

  /// Inserta mÃºltiples lecturas de gases de forma eficiente
  /// Agrupa operaciones para mejor rendimiento
  Future<void> insertGasReadingsBatch({
    required List<GasReading> readings,
  }) async {
    if (readings.isEmpty) {
      throw ArgumentError('La lista de lecturas no puede estar vacÃ­a');
    }

    for (final reading in readings) {
      try {
        await insertGasReading(reading: reading);
      } catch (e) {
        // Continuar con prÃ³ximas lecturas pero registrar error
        print('Error insertando lectura para zona ${reading.zone}: $e');
      }
    }
  }

  /// Valida que un valor de gas estÃ© dentro de los rangos permitidos
  void _validateGasValue(
    String name,
    double? value,
    double min,
    double max,
  ) {
    if (value == null) return;
    if (value < min || value > max) {
      throw ArgumentError(
        '$name fuera de rango: $value (rango permitido: $min-$max)',
      );
    }
  }

  /// Obtiene estadÃ­sticas de lecturas de gases para una zona
  Future<Map<String, double>> getGasStatistics({
    required String zone,
    int limitMinutes = 60,
  }) async {
    final cols = await columnsOf('lecturas_gases');
    final zoneCol = cols.contains('zona')
        ? 'zona'
        : (cols.contains('zone') ? 'zone' : (cols.contains('zona_id') ? 'zona_id' : null));
    final tsCol = cols.contains('timestamp')
        ? 'timestamp'
        : (cols.contains('fecha')
            ? 'fecha'
            : (cols.contains('created_at')
                ? 'created_at'
                : (cols.contains('registrado_en') ? 'registrado_en' : null)));

    if (zoneCol == null || tsCol == null) {
      throw StateError('Columnas requeridas no encontradas en lecturas_gases');
    }

    String pick(String a, String b) => cols.contains(a) ? a : (cols.contains(b) ? b : '');

    final coCol = pick('co', 'CO');
    final o2Col = pick('o2', 'O2');
    final co2Col = pick('co2', 'CO2');
    final ch4Col = pick('ch4', 'CH4');
    final h2sCol = pick('h2s', 'H2S');
    final tCol = cols.contains('temperatura') ? 'temperatura' : (cols.contains('temp') ? 'temp' : '');

    try {
      final c = await _connection();
      final rows = await c.query(
        '''
SELECT 
  ${coCol.isEmpty ? 'NULL' : 'AVG(CAST($coCol AS DECIMAL))'}::DECIMAL as co_avg,
  ${o2Col.isEmpty ? 'NULL' : 'AVG(CAST($o2Col AS DECIMAL))'}::DECIMAL as o2_avg,
  ${co2Col.isEmpty ? 'NULL' : 'AVG(CAST($co2Col AS DECIMAL))'}::DECIMAL as co2_avg,
  ${ch4Col.isEmpty ? 'NULL' : 'AVG(CAST($ch4Col AS DECIMAL))'}::DECIMAL as ch4_avg,
  ${h2sCol.isEmpty ? 'NULL' : 'AVG(CAST($h2sCol AS DECIMAL))'}::DECIMAL as h2s_avg,
  ${tCol.isEmpty ? 'NULL' : 'AVG(CAST($tCol AS DECIMAL))'}::DECIMAL as temp_avg
FROM lecturas_gases
WHERE $zoneCol = @zone
  AND $tsCol > NOW() - INTERVAL '@minutes minutes'
''',
        substitutionValues: {
          'zone': zoneCol == 'zona_id' ? (_idToZona[zone] ?? 1) : zone,
          'minutes': limitMinutes,
        },
      );

      if (rows.isEmpty) {
        return {};
      }

      final row = rows.first;
      final stats = <String, double>{};

      if (coCol.isNotEmpty && row[0] != null) stats['CO'] = (row[0] as num).toDouble();
      if (o2Col.isNotEmpty && row[1] != null) stats['O2'] = (row[1] as num).toDouble();
      if (co2Col.isNotEmpty && row[2] != null) stats['CO2'] = (row[2] as num).toDouble();
      if (ch4Col.isNotEmpty && row[3] != null) stats['CH4'] = (row[3] as num).toDouble();
      if (h2sCol.isNotEmpty && row[4] != null) stats['H2S'] = (row[4] as num).toDouble();
      if (tCol.isNotEmpty && row[5] != null) stats['Temperatura'] = (row[5] as num).toDouble();

      return stats;
    } catch (e) {
      throw DatabaseException('Error al obtener estadÃ­sticas: ${e.toString()}');
    }
  }

  /// Limpia lecturas antiguas para optimizar almacenamiento
  Future<int> cleanOldReadings({int retentionDays = 30}) async {
    try {
      final c = await _connection();
      final cols = await columnsOf('lecturas_gases');
      final tsCol = cols.contains('timestamp')
          ? 'timestamp'
          : (cols.contains('fecha')
              ? 'fecha'
              : (cols.contains('created_at')
                  ? 'created_at'
                  : (cols.contains('registrado_en') ? 'registrado_en' : null)));

      if (tsCol == null) {
        throw StateError('Columna de timestamp no encontrada');
      }

      final result = await c.execute(
        '''
DELETE FROM lecturas_gases
WHERE $tsCol < NOW() - INTERVAL '@days days'
''',
        substitutionValues: {'days': retentionDays},
      );

      return result;
    } catch (e) {
      throw DatabaseException('Error limpiando lecturas antiguas: ${e.toString()}');
    }
  }
}

/// ExcepciÃ³n personalizada para errores de base de datos
class DatabaseException implements Exception {
  DatabaseException(this.message);
  final String message;

  @override
  String toString() => 'DatabaseException: $message';
}

