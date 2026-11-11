import 'dart:convert';
import 'package:flutter/services.dart';
import '../../../../core/errors/exceptions.dart';
import '../../../../core/utils/logger.dart';
import '../../../synchronization/data/services/powersync_service.dart';
import '../models/form_models.dart';

abstract interface class FormLocalDatasource {
  Future<FormTemplateModel?> getTemplateByVisitType(String visitType);
  Future<FormTemplateModel?> getTemplateById(String id, int version);
  Future<FormResponseModel?> getResponse(String visitId);
  Future<void> upsertResponse(FormResponseModel model);
  Stream<FormResponseModel?> watchResponse(String visitId);
  Future<List<FormTemplateModel>> loadFromAssets();
  Future<void> seedTemplate(FormTemplateModel model);
}

class FormLocalDatasourceImpl implements FormLocalDatasource {
  const FormLocalDatasourceImpl({required PowerSyncService powerSyncService})
      : _db = powerSyncService;

  final PowerSyncService _db;

  static const _templatesTable = 'form_templates';
  static const _responsesTable = 'form_responses';

  Future<void> _ensureInitialized() async {
    if (!_db.isInitialized) await _db.initialize();
  }

  @override
  Future<FormTemplateModel?> getTemplateByVisitType(String visitType) async {
    try {
      await _ensureInitialized();
      final row = await _db.getOptional(
        'SELECT * FROM $_templatesTable '
        'WHERE visit_type = ? AND is_active = 1 '
        'ORDER BY version DESC LIMIT 1',
        [visitType],
      );
      return row != null ? FormTemplateModel.fromRow(row) : null;
    } catch (e) {
      AppLogger.e('getTemplateByVisitType error', error: e);
      throw DatabaseException(
        message: 'Error al cargar la plantilla del formulario.',
        originalError: e,
      );
    }
  }

  @override
  Future<FormTemplateModel?> getTemplateById(
    String id,
    int version,
  ) async {
    try {
      await _ensureInitialized();
      final row = await _db.getOptional(
        'SELECT * FROM $_templatesTable WHERE id = ? AND version = ?',
        [id, version],
      );
      return row != null ? FormTemplateModel.fromRow(row) : null;
    } catch (e) {
      AppLogger.e('getTemplateById error', error: e);
      throw DatabaseException(
        message: 'Error al cargar la plantilla del formulario.',
        originalError: e,
      );
    }
  }

  @override
  Future<FormResponseModel?> getResponse(String visitId) async {
    try {
      await _ensureInitialized();
      final row = await _db.getOptional(
        'SELECT * FROM $_responsesTable WHERE visit_id = ? LIMIT 1',
        [visitId],
      );
      return row != null ? FormResponseModel.fromRow(row) : null;
    } catch (e) {
      AppLogger.e('getResponse error', error: e);
      throw DatabaseException(
        message: 'Error al cargar las respuestas del formulario.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> upsertResponse(FormResponseModel model) async {
    try {
      await _ensureInitialized();
      await _db.execute(
        '''
        INSERT OR REPLACE INTO $_responsesTable (
          id, visit_id, template_id, template_version,
          responses_json, sync_status, is_complete,
          created_at, updated_at, completed_at
        ) VALUES (?,?,?,?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.visitId,
          model.templateId,
          model.templateVersion,
          model.responsesJson,
          model.syncStatus,
          model.isComplete,
          model.createdAt,
          model.updatedAt,
          model.completedAt,
        ],
      );
    } catch (e) {
      AppLogger.e('upsertResponse error', error: e);
      throw DatabaseException(
        message: 'Error al guardar las respuestas del formulario.',
        originalError: e,
      );
    }
  }

  @override
  Stream<FormResponseModel?> watchResponse(String visitId) {
    return _db
        .watch(
          'SELECT * FROM $_responsesTable WHERE visit_id = ? LIMIT 1',
          [visitId],
        )
        .map((rows) =>
            rows.isNotEmpty ? FormResponseModel.fromRow(rows.first) : null);
  }

  @override
  Future<List<FormTemplateModel>> loadFromAssets() async {
    try {
      final jsonStr = await rootBundle
          .loadString('assets/templates/form_templates.json');
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((json) =>
              FormTemplateModel.fromJson(Map<String, dynamic>.from(json as Map)))
          .toList();
    } catch (e) {
      AppLogger.e('loadFromAssets error', error: e);
      throw DatabaseException(
        message: 'Error al cargar las plantillas de formularios.',
        originalError: e,
      );
    }
  }

  @override
  Future<void> seedTemplate(FormTemplateModel model) async {
    try {
      await _ensureInitialized();
      await _db.execute(
        '''
        INSERT OR IGNORE INTO $_templatesTable (
          id, name, visit_type, version, sections_json, is_active,
          created_at, updated_at
        ) VALUES (?,?,?,?,?,?,?,?)
        ''',
        [
          model.id,
          model.name,
          model.visitType,
          model.version,
          model.sectionsJson,
          model.isActive,
          model.createdAt ??
              DateTime.now().toUtc().toIso8601String(),
          model.updatedAt,
        ],
      );
    } catch (e) {
      AppLogger.w('seedTemplate skipped (may already exist): $e');
    }
  }
}
