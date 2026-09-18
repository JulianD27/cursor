/// Configuración por entorno para MINER CLC (Cumplimiento Anexo A)
enum EnvironmentType {
  development,
  staging,
  production,
}

class EnvironmentConfig {
  const EnvironmentConfig({
    required this.environment,
    required this.dbHost,
    required this.dbPort,
    required this.dbName,
    required this.dbUser,
    required this.dbPassword,
    required this.useSSL,
    required this.connectionTimeoutSeconds,
    required this.logLevel,
    required this.googleClientId,
    required this.enableSensorsEmulator,
    required this.backupDirectory,
  });

  final EnvironmentType environment;
  final String dbHost;
  final int dbPort;
  final String dbName;
  final String dbUser;
  final String dbPassword;
  final bool useSSL;
  final int connectionTimeoutSeconds;
  final String logLevel; // 'DEBUG', 'INFO', 'WARNING', 'ERROR'
  final String googleClientId;
  final bool enableSensorsEmulator;
  final String backupDirectory;

  static EnvironmentConfig current = development;

  /// Perfil de Desarrollo (Local)
  static const EnvironmentConfig development = EnvironmentConfig(
    environment: EnvironmentType.development,
    dbHost: 'localhost',
    dbPort: 5432,
    dbName: 'miner_clc',
    dbUser: 'postgres',
    dbPassword: 'minercl c123',
    useSSL: false,
    connectionTimeoutSeconds: 8,
    logLevel: 'DEBUG',
    googleClientId: 'miner-clc-dev.apps.googleusercontent.com',
    enableSensorsEmulator: true,
    backupDirectory: 'backups/dev',
  );

  /// Perfil de Pruebas / Staging (Pre-producción)
  static const EnvironmentConfig staging = EnvironmentConfig(
    environment: EnvironmentType.staging,
    dbHost: '192.168.1.100',
    dbPort: 5432,
    dbName: 'miner_clc_staging',
    dbUser: 'miner_staging_user',
    dbPassword: 'SecuredStaging2026!',
    useSSL: true,
    connectionTimeoutSeconds: 15,
    logLevel: 'INFO',
    googleClientId: 'miner-clc-staging.apps.googleusercontent.com',
    enableSensorsEmulator: true,
    backupDirectory: 'backups/staging',
  );

  /// Perfil de Producción (Mina en operación)
  static const EnvironmentConfig production = EnvironmentConfig(
    environment: EnvironmentType.production,
    dbHost: 'db.minerclc.local',
    dbPort: 5432,
    dbName: 'miner_clc_prod',
    dbUser: 'miner_prod_app',
    dbPassword: 'ProdMineSafe#2026*Key',
    useSSL: true,
    connectionTimeoutSeconds: 20,
    logLevel: 'WARNING',
    googleClientId: 'miner-clc-prod.apps.googleusercontent.com',
    enableSensorsEmulator: false,
    backupDirectory: 'C:\\MinerData\\Backups',
  );

  bool get isDevelopment => environment == EnvironmentType.development;
  bool get isStaging => environment == EnvironmentType.staging;
  bool get isProduction => environment == EnvironmentType.production;
}
