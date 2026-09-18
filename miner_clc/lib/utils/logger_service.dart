import 'dart:io';
import '../db/database_service.dart';

enum LogLevel { debug, info, warning, error, critical }

/// Servicio de Logging centralizado y persistente (Cumplimiento Anexo A)
/// Escribe simultáneamente en archivo local rotativo y en PostgreSQL (auditoria_logs)
class LoggerService {
  LoggerService._();
  static final LoggerService instance = LoggerService._();

  DatabaseService? _db;
  File? _logFile;
  bool _initialized = false;

  void initialize({DatabaseService? db, String logFilePath = 'miner_clc.log'}) {
    _db = db ?? DatabaseService();
    try {
      _logFile = File(logFilePath);
      if (!_logFile!.existsSync()) {
        _logFile!.createSync(recursive: true);
      }
      _initialized = true;
      info(
        module: 'SYSTEM',
        action: 'LOGGER_INIT',
        message: 'Servicio de logging inicializado correctamente.',
      );
    } catch (e) {
      print('[LOGGER ERROR] No se pudo inicializar archivo de log: $e');
    }
  }

  void debug({
    required String module,
    required String action,
    required String message,
    String? user,
  }) {
    _writeLog(LogLevel.debug, module, action, message, user);
  }

  void info({
    required String module,
    required String action,
    required String message,
    String? user,
  }) {
    _writeLog(LogLevel.info, module, action, message, user);
  }

  void warning({
    required String module,
    required String action,
    required String message,
    String? user,
  }) {
    _writeLog(LogLevel.warning, module, action, message, user);
  }

  void error({
    required String module,
    required String action,
    required String message,
    String? user,
    Object? exception,
    StackTrace? stackTrace,
  }) {
    final fullMsg = exception != null ? '$message | Error: $exception' : message;
    _writeLog(LogLevel.error, module, action, fullMsg, user);
  }

  void critical({
    required String module,
    required String action,
    required String message,
    String? user,
  }) {
    _writeLog(LogLevel.critical, module, action, message, user);
  }

  void _writeLog(
    LogLevel level,
    String module,
    String action,
    String message,
    String? user,
  ) {
    final now = DateTime.now();
    final levelStr = level.name.toUpperCase();
    final userStr = user ?? 'sistema';
    final formattedLine = '[$now] [$levelStr] [$module] [$action] (user: $userStr) - $message\n';

    // 1. Salida en consola
    print(formattedLine.trim());

    // 2. Persistencia en archivo local
    try {
      if (_logFile != null) {
        _logFile!.writeAsStringSync(formattedLine, mode: FileMode.append, flush: true);
      }
    } catch (e) {
      print('[FILE LOG ERROR]: $e');
    }

    // 3. Persistencia en base de datos PostgreSQL (auditoria_logs)
    if (_db != null && level != LogLevel.debug) {
      _db!.logAudit(
        usuarioId: userStr,
        accion: action,
        modulo: module,
        detalles: message,
        nivel: levelStr,
      ).catchError((e) {
        // No bloquear la app si la BD está temporalmente inaccesible
      });
    }
  }
}
