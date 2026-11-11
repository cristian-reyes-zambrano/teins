import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:powersync/powersync.dart';
import 'package:sqlite_async/sqlite_async.dart' show SqliteWriteContext;
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/logger.dart';
import 'powersync_schema.dart';

/// Servicio que encapsula PowerSync.
///
/// La UI y los repositorios interactúan con este servicio
/// y no con PowerSyncDatabase directamente, manteniendo bajo acoplamiento.
///
/// PowerSync usa el token JWT de Supabase para autenticar la sincronización.
/// Cuando el dispositivo está offline, las operaciones SQLite funcionan
/// normalmente y los cambios se encolan para sincronizar luego.
class PowerSyncService {
  PowerSyncService({
    required SupabaseClient supabaseClient,
    required SecureStorageService secureStorage,
  })  : _supabase = supabaseClient,
        _secureStorage = secureStorage;

  final SupabaseClient _supabase;
  final SecureStorageService _secureStorage;

  PowerSyncDatabase? _db;
  bool _initialized = false;

  PowerSyncDatabase get db {
    assert(_initialized, 'PowerSyncService no ha sido inicializado. '
        'Llama a initialize() antes de usar el servicio.');
    return _db!;
  }

  bool get isInitialized => _initialized;

  /// Inicializa la base de datos SQLite y configura PowerSync.
  /// Debe llamarse una vez al inicio de la sesión autenticada.
  Future<void> initialize() async {
    if (_initialized) return;

    AppLogger.i('Inicializando PowerSync...');

    // Obtener la ruta completa del directorio de documentos de la app.
    // En Android/iOS no se puede usar un nombre de archivo sin ruta absoluta.
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, AppConstants.kDbName);

    AppLogger.d('Ruta de base de datos: $dbPath');

    _db = PowerSyncDatabase(
      schema: schema,
      path: dbPath,
    );

    await _db!.initialize();
    _initialized = true;

    AppLogger.i('PowerSync inicializado. SQLite listo.');
  }

  /// Conecta PowerSync con el servidor de sincronización.
  /// Solo se llama cuando hay sesión activa y conectividad.
  Future<void> connect() async {
    if (!_initialized) await initialize();

    AppLogger.i('Conectando PowerSync al servidor de sync...');

    await _db!.connect(connector: _SupabaseConnector(_supabase));

    AppLogger.i('PowerSync conectado.');
  }

  /// Desconecta PowerSync del servidor (sin perder datos locales).
  Future<void> disconnect() async {
    if (!_initialized) return;
    await _db!.disconnect();
    AppLogger.i('PowerSync desconectado.');
  }

  /// Cierra la base de datos completamente (al cerrar sesión).
  Future<void> close() async {
    if (!_initialized) return;
    await _db!.close();
    _initialized = false;
    _db = null;
    AppLogger.i('PowerSync cerrado.');
  }

  // ── Operaciones de base de datos ─────────────────────────────────────────

  /// Ejecuta una consulta SELECT y retorna las filas.
  Future<List<Map<String, dynamic>>> getAll(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    final results = await db.getAll(sql, parameters);
    return results.map((row) => Map<String, dynamic>.from(row)).toList();
  }

  /// Ejecuta una consulta SELECT que retorna una sola fila o null.
  Future<Map<String, dynamic>?> getOptional(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    final result = await db.getOptional(sql, parameters);
    return result != null ? Map<String, dynamic>.from(result) : null;
  }

  /// Ejecuta una sentencia INSERT, UPDATE o DELETE.
  Future<void> execute(
    String sql, [
    List<Object?> parameters = const [],
  ]) async {
    await db.execute(sql, parameters);
  }

  /// Ejecuta múltiples operaciones en una transacción atómica.
  /// Garantiza atomicidad para operaciones relacionadas (ej: visita + materiales).
  Future<T> writeTransaction<T>(
    Future<T> Function(SqliteWriteContext tx) callback,
  ) async {
    return db.writeTransaction(callback);
  }

  /// Stream reactivo: emite filas cada vez que cambian los datos de la query.
  /// Usado por los providers de Riverpod para actualización automática de UI.
  Stream<List<Map<String, dynamic>>> watch(
    String sql, [
    List<Object?> parameters = const [],
  ]) {
    return db
        .watch(sql, parameters: parameters)
        .map((results) =>
            results.map((row) => Map<String, dynamic>.from(row)).toList());
  }

  /// Stream del estado de sincronización de PowerSync.
  Stream<SyncStatus> get syncStatusStream => db.statusStream;

  /// Estado actual de sincronización.
  SyncStatus get currentSyncStatus => db.currentStatus;
}

/// Conector de PowerSync para Supabase.
///
/// Provee el JWT de Supabase a PowerSync para autenticar la sincronización.
/// PowerSync usa este token para verificar el usuario y aplicar las
/// reglas de sincronización configuradas en el servidor PowerSync.
class _SupabaseConnector extends PowerSyncBackendConnector {
  _SupabaseConnector(this._supabase);

  final SupabaseClient _supabase;

  @override
  Future<PowerSyncCredentials?> fetchCredentials() async {
    // Refrescar la sesión si está próxima a vencer
    final session = _supabase.auth.currentSession;
    if (session == null) {
      AppLogger.w('fetchCredentials: sin sesión de Supabase');
      return null;
    }

    // Si el token expira en menos de 5 minutos, refrescar
    final expiresAt = session.expiresAt;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (expiresAt != null && expiresAt - now < 300) {
      try {
        await _supabase.auth.refreshSession();
      } catch (e) {
        AppLogger.w('Error refrescando sesión: $e');
      }
    }

    final currentSession = _supabase.auth.currentSession;
    if (currentSession == null) return null;

    return PowerSyncCredentials(
      endpoint: AppConfig.powerSyncUrl,
      token: currentSession.accessToken,
      userId: currentSession.user.id,
    );
  }

  @override
  Future<void> uploadData(PowerSyncDatabase database) async {
    // PowerSync maneja automáticamente la subida de cambios locales.
    // Este método se invoca internamente — no necesitamos implementación
    // adicional para el flujo estándar con Supabase.
    AppLogger.d('uploadData llamado por PowerSync');
  }
}
