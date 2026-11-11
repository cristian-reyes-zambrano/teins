import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../domain/entities/visit.dart';
import '../providers/visit_providers.dart';

/// Resumen final de la visita con accesos directos a todas las secciones.
class VisitSummaryPage extends ConsumerWidget {
  const VisitSummaryPage({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitAsync = ref.watch(visitByIdProvider(visitId));

    return Scaffold(
      appBar: AppBarBack(title: const Text('Resumen de visita')),
      body: visitAsync.when(
        loading: () => const AppLoading(),
        error: (e, _) => const AppErrorWidget(message: 'Error al cargar.'),
        data: (either) => either.fold(
          (f) => AppErrorWidget(message: f.message),
          (visit) => _SummaryContent(visit: visit),
        ),
      ),
    );
  }
}

class _SummaryContent extends StatelessWidget {
  const _SummaryContent({required this.visit});

  final Visit visit;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _VisitSummaryCard(visit: visit),
          const SizedBox(height: AppSpacing.md),
          _SectionLinks(visitId: visit.id),
        ],
      ),
    );
  }
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({required this.visit});

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
                VisitStatusBadge(status: visit.status),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            if (visit.clientName != null)
              Text(
                visit.clientName!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            if (visit.address != null)
              Text(
                visit.address!,
                style: const TextStyle(
                    fontSize: 13, color: AppColors.textSecondary),
              ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Creada ${AppDateUtils.formatDateTime(visit.createdAt)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
            if (visit.completedAt != null)
              Text(
                'Completada ${AppDateUtils.formatDateTime(visit.completedAt!)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
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
}

class _SectionLinks extends StatelessWidget {
  const _SectionLinks({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context) {
    final links = [
      (Icons.assignment_outlined, 'Formulario técnico',
          AppRoutes.visitFormPath(visitId)),
      (Icons.inventory_2_outlined, 'Materiales',
          AppRoutes.visitMaterialsPath(visitId)),
      (Icons.photo_library_outlined, 'Fotografías',
          AppRoutes.visitPhotosPath(visitId)),
      (Icons.draw_outlined, 'Anotaciones',
          AppRoutes.visitAnnotationsPath(visitId)),
    ];

    return Card(
      child: Column(
        children: links
            .map(
              (link) => ListTile(
                leading: Icon(link.$1, color: AppColors.primary),
                title: Text(link.$2),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.go(link.$3),
              ),
            )
            .toList(),
      ),
    );
  }
}
