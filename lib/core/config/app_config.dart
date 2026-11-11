/// Centraliza la configuración de la aplicación según el entorno.
///
/// Las URLs y claves se inyectan desde variables compiladas mediante
/// --dart-define o un archivo de configuración en build-time.
/// Nunca hardcodear secretos en el código fuente.
class AppConfig {
  const AppConfig._();

  // ── Supabase ──────────────────────────────────────────────────────────────

  /// URL del proyecto Supabase. Proviene de --dart-define=SUPABASE_URL=...
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://lnsqfnkhblosbusewvua.supabase.co',
  );

  /// Clave pública anon de Supabase (safe para cliente móvil).
  /// Nunca usar service_role key en la app.
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imxuc3FmbmtoYmxvc2J1c2V3dnVhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI0Mzg3NDUsImV4cCI6MjEwODAxNDc0NX0._PqIFqjScrmHO2DqyzgQ0o17B1o4uDyXma0phcGZkcs',
  );

  // ── PowerSync ─────────────────────────────────────────────────────────────

  /// URL de la instancia PowerSync para sincronización offline.
  static const String powerSyncUrl = String.fromEnvironment(
    'POWERSYNC_URL',
    defaultValue: 'https://6ad67ee13b1803753bd3182f.powersync.journeyapps.com',
  );

  // ── Entorno ───────────────────────────────────────────────────────────────

  static const String _rawEnv = String.fromEnvironment(
    'APP_ENV',
    defaultValue: 'development',
  );

  static AppEnvironment get environment {
    switch (_rawEnv) {
      case 'production':
        return AppEnvironment.production;
      case 'staging':
        return AppEnvironment.staging;
      default:
        return AppEnvironment.development;
    }
  }

  static bool get isProduction => environment == AppEnvironment.production;
  static bool get isDevelopment => environment == AppEnvironment.development;

  // ── Logging ───────────────────────────────────────────────────────────────

  static const String _rawLogLevel = String.fromEnvironment(
    'LOG_LEVEL',
    defaultValue: 'debug',
  );

  static AppLogLevel get logLevel {
    switch (_rawLogLevel) {
      case 'error':
        return AppLogLevel.error;
      case 'warning':
        return AppLogLevel.warning;
      case 'info':
        return AppLogLevel.info;
      case 'none':
        return AppLogLevel.none;
      default:
        return AppLogLevel.debug;
    }
  }
}

enum AppEnvironment { development, staging, production }

enum AppLogLevel { debug, info, warning, error, none }
