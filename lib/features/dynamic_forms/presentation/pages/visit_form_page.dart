import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../../visits/presentation/providers/visit_providers.dart';
import '../providers/form_providers.dart';
import '../widgets/autosave_indicator.dart';
import '../widgets/form_section_widget.dart';

/// Página principal del formulario técnico dinámico.
///
/// Acepta parámetros opcionales overrideTemplateId y overrideVisitType
/// para soporte multi-formulario (desde FormSelectorPage).
class VisitFormPage extends ConsumerStatefulWidget {
  const VisitFormPage({
    super.key,
    required this.visitId,
    this.overrideTemplateId,
    this.overrideVisitType,
  });

  final String visitId;
  /// templateId específico (cuando viene del selector multi-formulario).
  final String? overrideTemplateId;
  /// visitType específico (cuando viene del selector multi-formulario).
  final String? overrideVisitType;

  @override
  ConsumerState<VisitFormPage> createState() => _VisitFormPageState();
}

class _VisitFormPageState extends ConsumerState<VisitFormPage> {
  // Una GlobalKey por sección para validación independiente
  final Map<int, GlobalKey<FormBuilderState>> _sectionKeys = {};

  GlobalKey<FormBuilderState> _keyForSection(int index) {
    return _sectionKeys.putIfAbsent(
      index,
      () => GlobalKey<FormBuilderState>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitAsync = ref.watch(visitByIdProvider(widget.visitId));

    return visitAsync.when(
      loading: () => Scaffold(
        appBar: AppBarBack(title: const Text('Formulario técnico')),
        body: const AppLoading(message: 'Cargando visita...'),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBarBack(title: const Text('Formulario técnico')),
        body: const AppErrorWidget(message: 'Error al cargar la visita.'),
      ),
      data: (either) => either.fold(
        (failure) => Scaffold(
          appBar: AppBarBack(title: const Text('Formulario técnico')),
          body: AppErrorWidget(message: failure.message),
        ),
        (visit) {
          // Si viene del selector multi-formulario, usa el tipo override.
          // Si no, usa el tipo de la visita (comportamiento original).
          final effectiveVisitType =
              widget.overrideVisitType ?? visit.visitType;
          final providerKey = (widget.visitId, effectiveVisitType);
          final formState = ref.watch(formEditorProvider(providerKey));

          return _FormScaffold(
            visitId: widget.visitId,
            visitType: effectiveVisitType,
            formState: formState,
            sectionKeyBuilder: _keyForSection,
            onFieldChanged: (fieldId, value) => ref
                .read(formEditorProvider(providerKey).notifier)
                .updateField(fieldId, value),
            onSectionChanged: (index) => ref
                .read(formEditorProvider(providerKey).notifier)
                .goToSection(index),
            onSaveNow: () => ref
                .read(formEditorProvider(providerKey).notifier)
                .saveNow(),
            onComplete: () async {
              final ok = await ref
                  .read(formEditorProvider(providerKey).notifier)
                  .markComplete();
              if (ok && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Formulario completado y guardado.'),
                    backgroundColor: AppColors.success,
                  ),
                );
                context.pop();
              }
            },
          );
        },
      ),
    );
  }
}

class _FormScaffold extends StatelessWidget {
  const _FormScaffold({
    required this.visitId,
    required this.visitType,
    required this.formState,
    required this.sectionKeyBuilder,
    required this.onFieldChanged,
    required this.onSectionChanged,
    required this.onSaveNow,
    required this.onComplete,
  });

  final String visitId;
  final String visitType;
  final FormEditorState formState;
  final GlobalKey<FormBuilderState> Function(int) sectionKeyBuilder;
  final void Function(String, dynamic) onFieldChanged;
  final void Function(int) onSectionChanged;
  final Future<void> Function() onSaveNow;
  final Future<void> Function() onComplete;

  @override
  Widget build(BuildContext context) {
    final template = formState.template;

    if (template == null && formState.failure == null) {
      return Scaffold(
        appBar: AppBarBack(title: const Text('Formulario técnico')),
        body: const AppLoading(message: 'Cargando formulario...'),
      );
    }

    if (formState.failure != null && template == null) {
      return Scaffold(
        appBar: AppBarBack(title: const Text('Formulario técnico')),
        body: AppErrorWidget(message: formState.failure!.message),
      );
    }

    final sections = template!.sections;
    final currentIndex = formState.currentSectionIndex;
    final responses = formState.response?.responses ?? {};
    final isComplete = formState.response?.isComplete ?? false;

    return Scaffold(
      appBar: _buildAppBar(context, formState),
      body: Column(
        children: [
          const ConnectivityBanner(),

          // ── Selector de secciones ──────────────────────────────────────
          if (sections.length > 1)
            _SectionTabBar(
              sections: sections.map((s) => s.title).toList(),
              currentIndex: currentIndex,
              onTap: onSectionChanged,
            ),

          // ── Contenido de la sección activa ────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: [
                  // Banner si ya está completo
                  if (isComplete) _CompletedBanner(),

                  FormSectionWidget(
                    key: ValueKey('section_$currentIndex'),
                    section: sections[currentIndex],
                    responses: responses,
                    formKey: sectionKeyBuilder(currentIndex),
                    onFieldChanged: onFieldChanged,
                    enabled: !isComplete,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  // ── Navegación entre secciones ────────────────────────
                  _SectionNavigation(
                    currentIndex: currentIndex,
                    totalSections: sections.length,
                    isComplete: isComplete,
                    onPrevious: currentIndex > 0
                        ? () => onSectionChanged(currentIndex - 1)
                        : null,
                    onNext: currentIndex < sections.length - 1
                        ? () => onSectionChanged(currentIndex + 1)
                        : null,
                    onComplete: !isComplete ? onComplete : null,
                  ),

                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  AppBarBack _buildAppBar(BuildContext context, FormEditorState? state) {
    return AppBarBack(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formState.template?.name ?? 'Formulario técnico',
            style: const TextStyle(fontSize: 16),
          ),
          if (state != null)
            AutosaveIndicator(
              isSaving: state.isSaving,
              lastSavedAt: state.lastSavedAt,
              hasError: state.failure != null,
            ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.save_rounded),
          tooltip: 'Guardar ahora',
          onPressed: onSaveNow,
        ),
      ],
    );
  }
}

/// Barra de selección de secciones con indicadores de progreso.
class _SectionTabBar extends StatelessWidget {
  const _SectionTabBar({
    required this.sections,
    required this.currentIndex,
    required this.onTap,
  });

  final List<String> sections;
  final int currentIndex;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.surface,
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
        itemCount: sections.length,
        itemBuilder: (context, index) {
          final isActive = index == currentIndex;
          return GestureDetector(
            onTap: () => onTap(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(
                horizontal: 4,
                vertical: 6,
              ),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: isActive ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(AppRadius.full),
                border: Border.all(
                  color: isActive ? AppColors.primary : AppColors.border,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}. ${sections[index]}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isActive
                      ? Colors.white
                      : AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Navegación entre secciones y botón de completar.
class _SectionNavigation extends StatelessWidget {
  const _SectionNavigation({
    required this.currentIndex,
    required this.totalSections,
    required this.isComplete,
    this.onPrevious,
    this.onNext,
    this.onComplete,
  });

  final int currentIndex;
  final int totalSections;
  final bool isComplete;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final Future<void> Function()? onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onPrevious != null)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Anterior'),
            ),
          ),
        if (onPrevious != null && (onNext != null || onComplete != null))
          const SizedBox(width: AppSpacing.sm),
        if (onNext != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Siguiente'),
            ),
          ),
        if (onComplete != null)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onComplete,
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('Completar formulario'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.sm + 4),
      decoration: BoxDecoration(
        color: AppColors.successLight,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.success.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded,
              color: AppColors.success, size: 18),
          SizedBox(width: AppSpacing.sm),
          Text(
            'Formulario completado. Solo lectura.',
            style: TextStyle(
              color: AppColors.success,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
