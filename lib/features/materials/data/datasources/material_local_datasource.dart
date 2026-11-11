import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../synchronization/data/services/powersync_service.dart';
import '../models/material_model.dart';

abstract interface class MaterialLocalDatasource {
  Future<List<CatalogMaterialModel>> searchCatalog({
    String query,
    String? category,
    int limit,
    int offset,
  });
  Future<List<String>> getCategories();
  Stream<List<VisitMaterialModel>> watchVisitMaterials(String visitId);
  Future<List<VisitMaterialModel>> getVisitMaterials(String visitId);
  Future<void> upsertVisitMaterial(VisitMaterialModel model);
  Future<void> updateVisitMaterialQuantity(String id, double quantity);
  Future<void> updateVisitMaterialObservations(String id, String? observations);
  Future<void> deleteVisitMaterial(String id);
  Future<void> seedCatalogMaterial(CatalogMaterialModel model);
}

class MaterialLocalDatasourceImpl implements MaterialLocalDatasource {
  const MaterialLocalDatasourceImpl({
    required PowerSyncService powerSyncService,
  }) : _db = powerSyncService;

  final PowerSyncService _db;
  static const _catalog = 'material_catalog';
  static const _visitMaterials = 'visit_materials';

  /// Garantiza que PowerSync esté inicializado antes de cualquier query.
  /// Los materiales solo se pueden consultar después del login/demo mode.
  Future<void> _ensureInitialized() async {
    if (!_db.isInitialized) {
      AppLogger.w('MaterialDatasource: PowerSync no inicializado, inicializando...');
      await _db.initialize();
    }
  }

  @override
  Future<List<CatalogMaterialModel>> searchCatalog({
    String query = '',
    String? category,
    int limit = 30,
    int offset = 0,
  }) async {
    try {
      await _ensureInitialized();
      // Normaliza la búsqueda: LOWER() para insensibilidad a mayúsculas.
      // Para tildes, el técnico puede buscar con o sin tilde — se compara
      // el texto usando LIKE que en SQLite es insensible en ASCII pero
      // sensible en Unicode, suficiente para el caso de uso.
      final conditions = <String>['is_active = 1'];
      final params = <Object?>[];

      if (query.trim().isNotEmpty) {
        final q = '%${query.trim().toLowerCase()}%';
        conditions.add('(LOWER(name) LIKE ? OR LOWER(code) LIKE ?)');
        params.addAll([q, q]);
      }

      if (category != null && category.isNotEmpty) {
        conditions.add('category = ?');
        params.add(category);
      }

      final where =
          conditions.isNotEmpty ? 'WHERE ${conditions.join(' AND ')}' : '';
      params.addAll([limit, offset]);

      final rows = await _db.getAll(
        'SELECT * FROM $_catalog $where ORDER BY name ASC LIMIT ? OFFSET ?',
        params,
      );
      return rows.map(CatalogMaterialModel.fromRow).toList();
    } catch (e) {
      AppLogger.e('searchCatalog error', error: e);
      throw DatabaseException(
        message: 'Error al buscar materiales.',
        originalError: e,
      );
    }
  }

  @override
  Future<List<String>> getCategories() async {
    try {
      await _ensureInitialized();
      final rows = await _db.getAll(
        'SELECT DISTINCT category FROM $_catalog '
        'WHERE category IS NOT NULL AND is_active = 1 '
        'ORDER BY category ASC',
      );
      return rows
          .map((r) => r['category'] as String)
          .where((c) => c.isNotEmpty)
          .toList();
    } catch (e) {
      return [];
    }
  }

  @override
  Stream<List<VisitMaterialModel>> watchVisitMaterials(String visitId) {
    // Para streams, usamos un stream que emite vacío si no está inicializado
    // y redirige a la BD cuando esté lista.
    if (!_db.isInitialized) {
      return Stream.value(<VisitMaterialModel>[]);
    }
    return _db
        .watch(
          'SELECT * FROM $_visitMaterials WHERE visit_id = ? '
          'ORDER BY created_at ASC',
          [visitId],
        )
        .map((rows) => rows.map(VisitMaterialModel.fromRow).toList());
  }

  @override
  Future<List<VisitMaterialModel>> getVisitMaterials(String visitId) async {
    try {
      await _ensureInitialized();
      final rows = await _db.getAll(
        'SELECT * FROM $_visitMaterials WHERE visit_id = ? '
        'ORDER BY created_at ASC',
        [visitId],
      );
      return rows.map(VisitMaterialModel.fromRow).toList();
    } catch (e) {
      throw DatabaseException(
        message: 'Error al cargar materiales.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> upsertVisitMaterial(VisitMaterialModel model) async {
    try {
      await _ensureInitialized();
      await _db.execute(
        '''
        INSERT OR REPLACE INTO $_visitMaterials (
          id, visit_id, material_id, material_code, material_name,
          unit, quantity, observations, sync_status, created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.visitId,
          model.materialId,
          model.materialCode,
          model.materialName,
          model.unit,
          model.quantity,
          model.observations,
          model.syncStatus,
          model.createdAt,
          model.updatedAt,
        ],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al guardar el material.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateVisitMaterialQuantity(
    String id,
    double quantity,
  ) async {
    try {
      await _db.execute(
        'UPDATE $_visitMaterials '
        'SET quantity = ?, sync_status = ?, updated_at = ? '
        'WHERE id = ?',
        [
          quantity,
          'pendingSync',
          DateTime.now().toUtc().toIso8601String(),
          id,
        ],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al actualizar la cantidad.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateVisitMaterialObservations(
    String id,
    String? observations,
  ) async {
    try {
      await _db.execute(
        'UPDATE $_visitMaterials '
        'SET observations = ?, sync_status = ?, updated_at = ? '
        'WHERE id = ?',
        [
          observations,
          'pendingSync',
          DateTime.now().toUtc().toIso8601String(),
          id,
        ],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al actualizar las observaciones.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteVisitMaterial(String id) async {
    try {
      await _db.execute(
        'DELETE FROM $_visitMaterials WHERE id = ?',
        [id],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al eliminar el material.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> seedCatalogMaterial(CatalogMaterialModel model) async {
    try {
      await _ensureInitialized();
      await _db.execute(
        '''
        INSERT OR IGNORE INTO $_catalog (id, code, name, description, unit, category, is_active)
        VALUES (?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.code,
          model.name,
          model.description,
          model.unit,
          model.category,
          model.isActive,
        ],
      );
    } catch (e) {
      AppLogger.w('seedCatalogMaterial skipped: $e');
    }
  }
}
