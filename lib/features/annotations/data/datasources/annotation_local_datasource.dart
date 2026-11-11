import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../synchronization/data/services/powersync_service.dart';
import '../models/annotation_model.dart';

abstract interface class AnnotationLocalDatasource {
  Stream<AnnotationModel?> watchByVisit(String visitId);
  Future<AnnotationModel?> getByVisit(String visitId);
  Future<void> upsert(AnnotationModel model);
  Future<void> deleteByVisit(String visitId);
}

class AnnotationLocalDatasourceImpl implements AnnotationLocalDatasource {
  const AnnotationLocalDatasourceImpl({
    required PowerSyncService powerSyncService,
  }) : _db = powerSyncService;

  final PowerSyncService _db;
  static const _table = 'annotations';

  @override
  Stream<AnnotationModel?> watchByVisit(String visitId) {
    return _db
        .watch(
          'SELECT * FROM $_table WHERE visit_id = ? LIMIT 1',
          [visitId],
        )
        .map((rows) =>
            rows.isNotEmpty ? AnnotationModel.fromRow(rows.first) : null);
  }

  @override
  Future<AnnotationModel?> getByVisit(String visitId) async {
    try {
      final row = await _db.getOptional(
        'SELECT * FROM $_table WHERE visit_id = ? LIMIT 1',
        [visitId],
      );
      return row != null ? AnnotationModel.fromRow(row) : null;
    } catch (e) {
      AppLogger.e('AnnotationDatasource.getByVisit error', error: e);
      throw DatabaseException(
        message: 'Error al cargar las anotaciones.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> upsert(AnnotationModel model) async {
    try {
      await _db.execute(
        '''
        INSERT OR REPLACE INTO $_table (
          id, visit_id, title, elements_json, base_image_path,
          canvas_width, canvas_height, sync_status, created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.visitId,
          model.title,
          model.elementsJson,
          model.baseImagePath,
          model.canvasWidth,
          model.canvasHeight,
          model.syncStatus,
          model.createdAt,
          model.updatedAt,
        ],
      );
    } catch (e) {
      AppLogger.e('AnnotationDatasource.upsert error', error: e);
      throw DatabaseException(
        message: 'Error al guardar la anotación.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> deleteByVisit(String visitId) async {
    try {
      await _db.execute(
        'DELETE FROM $_table WHERE visit_id = ?',
        [visitId],
      );
    } catch (e) {
      throw DatabaseException(
        message: 'Error al eliminar la anotación.',
        originalError: e,
      );
    }
  }
}
