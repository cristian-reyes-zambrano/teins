import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../domain/entities/form_template.dart';
import '../../domain/usecases/get_form_template.dart';

/// Página de selección de formularios para una visita.
///
/// Permite al técnico elegir uno o más formularios disponibles
/// antes de abrirlos. Cada formulario se abre individualmente
/// en VisitFormPage con el templateId correspondiente.
class FormSelectorPage extends ConsumerStatefulWidget {
  const FormSelectorPage({
    super.key,
    required this.visitId,
    required this.visitType,
  });

  final String visitId;
  final String visitType;

  @override
  ConsumerState<FormSelectorPage> createState() => _FormSelectorPageState();
}

class _FormSelectorPageState extends ConsumerState<FormSelectorPage> {
  List<FormTemplate>? _templates;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    try {
      final useCase = sl<GetFormTemplate>();
      final result = await _loadAllTemplates(useCase);
      if (mounted) {
        setState(() {
          _templates = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'No se pudieron cargar los formularios.';
          _loading = false;
        });
      }
    }
  }

  Future<List<FormTemplate>> _loadAllTemplates(
      GetFormTemplate useCase) async {
    // Intentar cargar todos los templates. Si el tipo actual tiene uno,
    // lo ponemos primero. Luego listamos todos los demás disponibles.
    final allTypes = [
      widget.visitType, // tipo de la visita primero
      'general',
      'ups',
      'infraestructura',
      'energia',
      'datos',
    ];

    final seen = <String>{};
    final templates = <FormTemplate>[];

    for (final type in allTypes) {
      if (seen.contains(type)) continue;
      seen.add(type);
      final result = await useCase.byVisitType(type);
      result.fold(
        (_) {},
        (template) {
          if (template != null) templates.add(template);
        },
      );
    }

    return templates;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBarBack(title: const Text('Seleccionar formulario')),
        body: const AppLoading(message: 'Cargando formularios...'),
      );
    }

    if (_error != null || _templates == null || _templates!.isEmpty) {
      return Scaffold(
        appBar: AppBarBack(title: const Text('Seleccionar formulario')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.description_outlined,
                    size: 64, color: AppColors.grey400),
                const SizedBox(height: AppSpacing.md),
                Text(
                  _error ??
                      'No hay formularios disponibles para este tipo de visita.',
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.lg),
                // Ir directo al formulario del tipo de la visita
                ElevatedButton(
                  onPressed: () => _openForm(
                    context,
                    widget.visitType,
                    widget.visitType,
                  ),
                  child: const Text('Abrir formulario del tipo de visita'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final templates = _templates!;
    // Marcar como "recomendado" el template que coincide con el tipo de visita
    final recommended = templates.firstWhere(
      (t) => t.visitType == widget.visitType,
      orElse: () => templates.first,
    );

    return Scaffold(
      appBar: AppBarBack(
        title: const Text('Seleccionar formulario'),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Encabezado informativo
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            color: AppColors.primaryLight.withOpacity(0.08),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppColors.primary, size: 18),
                const SizedBox(width: AppSpacing.sm),
                const Expanded(
                  child: Text(
                    'Selecciona el formulario que deseas completar. '
                    'Puedes abrir varios formularios para una misma visita.',
                    style:
                        TextStyle(fontSize: 13, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),

          // Lista de formularios disponibles
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: templates.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final template = templates[index];
                final isRecommended = template.id == recommended.id;

                return _FormCard(
                  template: template,
                  isRecommended: isRecommended,
                  onTap: () => _openForm(
                    context,
                    template.id,
                    template.visitType,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(
      BuildContext context, String templateId, String visitType) {
    // Navega a VisitFormPage pasando el templateId como query param
    context.go(
      '/visits/${widget.visitId}/form?templateId=$templateId&visitType=$visitType',
    );
  }
}

class _FormCard extends StatelessWidget {
  const _FormCard({
    required this.template,
    required this.isRecommended,
    required this.onTap,
  });

  final FormTemplate template;
  final bool isRecommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              // Ícono del tipo
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(
                  _iconForType(template.visitType),
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: AppSpacing.md),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            template.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (isRecommended)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withOpacity(0.12),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.4),
                              ),
                            ),
                            child: const Text(
                              'Recomendado',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.secondary,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${template.sections.length} sección${template.sections.length == 1 ? '' : 'es'} · '
                      '${template.allFields.length} campo${template.allFields.length == 1 ? '' : 's'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return Icons.assignment_rounded;
      case 'ups':
        return Icons.battery_charging_full_rounded;
      case 'energia':
        return Icons.bolt_rounded;
      case 'datos':
        return Icons.cable_rounded;
      default:
        return Icons.construction_rounded;
    }
  }
}
