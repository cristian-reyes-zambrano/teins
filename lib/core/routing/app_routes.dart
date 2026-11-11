/// Definición central de todas las rutas de la aplicación.
///
/// Usar estas constantes en lugar de strings dispersos en el código.
class AppRoutes {
  const AppRoutes._();

  static const String splash = '/';
  static const String login = '/login';
  static const String home = '/home';

  // Visitas
  static const String visits = '/visits';
  static const String visitDetail = '/visits/:visitId';
  static const String visitForm = '/visits/:visitId/form';
  static const String visitMaterials = '/visits/:visitId/materials';
  static const String visitPhotos = '/visits/:visitId/photos';
  static const String visitAnnotations = '/visits/:visitId/annotations';
  static const String visitSummary = '/visits/:visitId/summary';

  // Helpers para construir rutas con parámetros
  static String visitDetailPath(String visitId) => '/visits/$visitId';
  static String visitFormPath(String visitId) => '/visits/$visitId/form';
  static String visitFormSelectPath(String visitId, String visitType) =>
      '/visits/$visitId/form-select?visitType=$visitType';
  static String visitFormWithTemplatePath(
          String visitId, String templateId, String visitType) =>
      '/visits/$visitId/form?templateId=$templateId&visitType=$visitType';
  static String visitMaterialsPath(String visitId) =>
      '/visits/$visitId/materials';
  static String visitPhotosPath(String visitId) => '/visits/$visitId/photos';
  static String visitAnnotationsPath(String visitId) =>
      '/visits/$visitId/annotations';
  static String visitSummaryPath(String visitId) =>
      '/visits/$visitId/summary';
}
