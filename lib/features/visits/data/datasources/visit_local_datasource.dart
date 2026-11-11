import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../synchronization/data/services/powersync_service.dart';
import '../../domain/entities/visit.dart';
import '../models/visit_model.dart';

abstract interface class VisitLocalDatasource {
  Stream<List<VisitModel>> watchByTechnician(String technicianId);
  Future<List<VisitModel>> getByTechnician(String technicianId);
  Future<VisitModel?> getById(String visitId);
  Future<void> upsert(VisitModel model);
  Future<void> updateStatus(String visitId, String status, String syncStatus);
}

class VisitLocalDatasourceImpl implements VisitLocalDatasource {
  const VisitLocalDatasourceImpl({required PowerSyncService powerSyncService})
      : _db = powerSyncService;

  final PowerSyncService _db;

  static const _table = 'visits';

  Future<void> _ensureInitialized() async {
    if (!_db.isInitialized) await _db.initialize();
  }

  @override
  Stream<List<VisitModel>> watchByTechnician(String technicianId) {
    if (!_db.isInitialized) return Stream.value(<VisitModel>[]);
    return _db
        .watch(
          'SELECT * FROM $_table WHERE technician_id = ? '
          'ORDER BY created_at DESC',
          [technicianId],
        )
        .map((rows) => rows.map(VisitModel.fromRow).toList());
  }

  @override
  Future<List<VisitModel>> getByTechnician(String technicianId) async {
    try {
      await _ensureInitialized();
      final rows = await _db.getAll(
        'SELECT * FROM $_table WHERE technician_id = ? '
        'ORDER BY created_at DESC',
        [technicianId],
      );
      return rows.map(VisitModel.fromRow).toList();
    } catch (e) {
      AppLogger.e('getByTechnician error', error: e);
      throw DatabaseException(
        message: 'Error al cargar las visitas.',
        originalError: e,
      );
    }
  }

  @override
  Future<VisitModel?> getById(String visitId) async {
    try {
      await _ensureInitialized();
      final row = await _db.getOptional(
        'SELECT * FROM $_table WHERE id = ?',
        [visitId],
      );
      return row != null ? VisitModel.fromRow(row) : null;
    } catch (e) {
      AppLogger.e('getById error: $visitId', error: e);
      throw DatabaseException(
        message: 'Error al cargar la visita.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> upsert(VisitModel model) async {
    try {
      await _ensureInitialized();
      // PowerSync usa vistas sobre sus tablas internas.
      // Las vistas soportan INSERT OR REPLACE pero NO ON CONFLICT DO UPDATE.
      await _db.execute(
        '''
        INSERT OR REPLACE INTO $_table (
          id, technician_id, client_id, client_name, title, description,
          visit_type, address, status, sync_status, form_template_id,
          form_template_version, observations,
          created_at, updated_at, started_at, completed_at,
          latitude, longitude
        ) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.technicianId,
          model.clientId,
          model.clientName,
          model.title,
          model.description,
          model.visitType,
          model.address,
          model.status,
          model.syncStatus,
          model.formTemplateId,
          model.formTemplateVersion,
          model.observations,
          model.createdAt,
          model.updatedAt,
          model.startedAt,
          model.completedAt,
          model.latitude,
          model.longitude,
        ],
      );
    } catch (e) {
      AppLogger.e('upsert visit error: ${model.id}', error: e);
      throw DatabaseException(
        message: 'Error al guardar la visita.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> updateStatus(
    String visitId,
    String status,
    String syncStatus,
  ) async {
    try {
      await _db.execute(
        'UPDATE $_table SET status = ?, sync_status = ?, updated_at = ? '
        'WHERE id = ?',
        [
          status,
          syncStatus,
          DateTime.now().toUtc().toIso8601String(),
          visitId,
        ],
      );
    } catch (e) {
      AppLogger.e('updateStatus error: $visitId', error: e);
      throw DatabaseException(
        message: 'Error al actualizar el estado de la visita.',
        originalError: e,
      );
    }
  }
}
