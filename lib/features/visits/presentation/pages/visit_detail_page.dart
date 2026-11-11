import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/visit.dart';
import '../providers/visit_providers.dart';

/// Pantalla de detalle de visita.
/// Organiza acceso a todas las secciones de trabajo del técnico.
class VisitDetailPage extends ConsumerWidget {
  const VisitDetailPage({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(visitByIdProvider(visitId));
    final actionState = ref.watch(visitActionControllerProvider);

    ref.listen<VisitActionState>(visitActionControllerProvider, (_, state) {
      if (state is VisitActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Estado actualizado: ${state.visit.status.displayName}',
            ),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(visitActionControllerProvider.notifier).reset();
        ref.invalidate(visitByIdProvider(visitId));
      } else if (state is VisitActionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.failure.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(visitActionControllerProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBarBack(
        title: const Text('Detalle de visita'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: ConnectivityBanner(),
        ),
      ),
      body: visitAsync.when(
        loading: () => const AppLoading(message: 'Cargando visita...'),
        error: (e, _) => AppErrorWidget(
          message: 'No se pudo cargar la visita.',
          onRetry: () => ref.invalidate(visitByIdProvider(visitId)),
        ),
        data: (either) => either.fold(
          (failure) => AppErrorWidget(message: failure.message),
          (visit) => _VisitDetailContent(
            visit: visit,
            isActionLoading: actionState is VisitActionLoading,
            onStart: () => ref
                .read(visitActionControllerProvider.notifier)
                .startVisit(visitId),
            onComplete: () => ref
                .read(visitActionControllerProvider.notifier)
                .completeVisit(visitId),
          ),
        ),
      ),
    );
  }
}

class _VisitDetailContent extends StatelessWidget {
  const _VisitDetailContent({
    required this.visit,
    required this.isActionLoading,
    required this.onStart,
    required this.onComplete,
  });

  final Visit visit;
  final bool isActionLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isTablet = constraints.maxWidth > 700;
        if (isTablet) {
          return _TabletLayout(
            visit: visit,
            isActionLoading: isActionLoading,
            onStart: onStart,
            onComplete: onComplete,
          );
        }
        return _PhoneLayout(
          visit: visit,
          isActionLoading: isActionLoading,
          onStart: onStart,
          onComplete: onComplete,
        );
      },
    );
  }
}

/// Layout de teléfono: lista vertical de secciones.
class _PhoneLayout extends StatelessWidget {
  const _PhoneLayout({
    required this.visit,
    required this.isActionLoading,
    required this.onStart,
    required this.onComplete,
  });

  final Visit visit;
  final bool isActionLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _VisitInfoCard(visit: visit),
          const SizedBox(height: AppSpacing.md),
          _SectionGrid(visitId: visit.id, visitType: visit.visitType),
          const SizedBox(height: AppSpacing.md),
          _ActionBar(
            visit: visit,
            isLoading: isActionLoading,
            onStart: onStart,
            onComplete: onComplete,
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}

/// Layout tablet: info a la izquierda, acciones a la derecha.
class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.visit,
    required this.isActionLoading,
    required this.onStart,
    required this.onComplete,
  });

  final Visit visit;
  final bool isActionLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                _VisitInfoCard(visit: visit),
                const SizedBox(height: AppSpacing.md),
                _ActionBar(
                  visit: visit,
                  isLoading: isActionLoading,
                  onStart: onStart,
                  onComplete: onComplete,
                ),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(0, AppSpacing.md, AppSpacing.md, AppSpacing.md),
            child: _SectionGrid(visitId: visit.id, visitType: visit.visitType),
          ),
        ),
      ],
    );
  }
}

/// Card con la información general de la visita.
class _VisitInfoCard extends StatelessWidget {
  const _VisitInfoCard({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visit.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                VisitStatusBadge(status: visit.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(
              icon: Icons.category_outlined,
              label: _visitTypeLabel(visit.visitType),
            ),
            if (visit.clientName != null)
              _InfoRow(
                icon: Icons.business_rounded,
                label: visit.clientName!,
              ),
            if (visit.address != null)
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: visit.address!,
              ),
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              label: 'Creada ${AppDateUtils.formatDateTime(visit.createdAt)}',
            ),
            if (visit.startedAt != null)
              _InfoRow(
                icon: Icons.play_circle_outline_rounded,
                label: 'Iniciada ${AppDateUtils.formatDateTime(visit.startedAt!)}',
              ),
            if (visit.completedAt != null)
              _InfoRow(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completada ${AppDateUtils.formatDateTime(visit.completedAt!)}',
              ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerRight,
              child: SyncStateBadge(status: visit.syncStatus),
            ),
          ],
        ),
      ),
    );
  }

  String _visitTypeLabel(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return 'Visita Técnica TEINS';
      case 'ups':
        return 'Informe Técnico UPS (CDP)';
      case 'energia':
        return 'Visita de Energía';
      case 'datos':
        return 'Visita de Datos / Red';
      default:
        return 'Visita de Infraestructura';
    }
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.xs),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid de accesos directos a las secciones de trabajo.
class _SectionGrid extends StatelessWidget {
  const _SectionGrid({required this.visitId, required this.visitType});

  final String visitId;
  final String visitType;

  @override
  Widget build(BuildContext context) {
    final sections = [
      (
        Icons.assignment_outlined,
        'Formulario técnico',
        AppColors.primary,
        // Ir al selector de formularios (multi-formulario)
        AppRoutes.visitFormSelectPath(visitId, visitType),
      ),
      (
        Icons.inventory_2_outlined,
        'Materiales',
        AppColors.secondary,
        AppRoutes.visitMaterialsPath(visitId),
      ),
      (
        Icons.photo_camera_outlined,
        'Fotografías',
        AppColors.warning,
        AppRoutes.visitPhotosPath(visitId),
      ),
      (
        Icons.draw_outlined,
        'Anotaciones',
        AppColors.info,
        AppRoutes.visitAnnotationsPath(visitId),
      ),
      (
        Icons.summarize_outlined,
        'Resumen',
        AppColors.grey600,
        AppRoutes.visitSummaryPath(visitId),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
        childAspectRatio: 1.5,
      ),
      itemCount: sections.length,
      itemBuilder: (context, index) {
        final (icon, label, color, route) = sections[index];
        return _SectionTile(
          icon: icon,
          label: label,
          color: color,
          onTap: () => context.go(route),
        );
      },
    );
  }
}

class _SectionTile extends StatelessWidget {
  const _SectionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 32, color: color),
              const SizedBox(height: AppSpacing.sm),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Barra de acción según el estado de la visita.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.visit,
    required this.isLoading,
    required this.onStart,
    required this.onComplete,
  });

  final Visit visit;
  final bool isLoading;
  final VoidCallback onStart;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return switch (visit.status) {
      VisitStatus.assigned => ElevatedButton.icon(
          onPressed: isLoading ? null : onStart,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar visita'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.secondary,
          ),
        ),
      VisitStatus.inProgress => ElevatedButton.icon(
          onPressed: isLoading ? null : onComplete,
          icon: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Finalizar visita'),
        ),
      _ => const SizedBox.shrink(),
    };
  }
}


/// FIN de visit_detail_page.dart
/// VisitSummaryPage se define en visit_summary_page.dart
