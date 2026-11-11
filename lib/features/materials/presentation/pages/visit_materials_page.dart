import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../domain/entities/material.dart';
import '../providers/material_providers.dart';
import '../widgets/material_list_tile.dart';
import '../widgets/add_material_sheet.dart';

/// Página de materiales de una visita.
/// Muestra los materiales ya registrados y permite buscar y agregar nuevos.
class VisitMaterialsPage extends ConsumerWidget {
  const VisitMaterialsPage({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final materialsAsync = ref.watch(visitMaterialsProvider(visitId));
    final actionState = ref.watch(materialActionProvider);

    // Mostrar feedback de acciones
    ref.listen<MaterialActionState>(materialActionProvider, (_, state) {
      if (!context.mounted) return;
      if (state is MaterialActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.message),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );
        ref.read(materialActionProvider.notifier).reset();
      } else if (state is MaterialActionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.failure.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(materialActionProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBarBack(
        title: const Text('Materiales'),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: ConnectivityBanner(),
        ),
        actions: [
          if (actionState is MaterialActionLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
      body: materialsAsync.when(
        loading: () => const AppLoading(message: 'Cargando materiales...'),
        error: (e, _) => const AppErrorWidget(
          message: 'Error al cargar los materiales.',
        ),
        data: (materials) => _MaterialsContent(
          visitId: visitId,
          materials: materials,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Agregar material'),
      ),
    );
  }

  void _showAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddMaterialSheet(visitId: visitId),
    );
  }
}

class _MaterialsContent extends ConsumerWidget {
  const _MaterialsContent({
    required this.visitId,
    required this.materials,
  });

  final String visitId;
  final List<VisitMaterial> materials;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (materials.isEmpty) {
      return const AppEmptyWidget(
        icon: Icons.inventory_2_outlined,
        message: 'No hay materiales registrados.\n'
            'Toca el botón + para agregar.',
      );
    }

    // Totalizar para mostrar resumen
    final total = materials.fold(0.0, (sum, m) => sum + m.quantity);

    return Column(
      children: [
        // Resumen rápido
        _MaterialsSummary(count: materials.length, total: total),

        // Lista de materiales
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: materials.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (context, index) {
              final material = materials[index];
              return MaterialListTile(
                material: material,
                onQuantityChanged: (newQty) => ref
                    .read(materialActionProvider.notifier)
                    .updateQuantity(
                      visitMaterialId: material.id,
                      quantity: newQty,
                    ),
                onDelete: () => _confirmDelete(context, ref, material),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VisitMaterial material,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar material'),
        content: Text(
          '¿Eliminar "${material.materialName}" de la visita?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style:
                TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(materialActionProvider.notifier).remove(material.id);
    }
  }
}

class _MaterialsSummary extends StatelessWidget {
  const _MaterialsSummary({
    required this.count,
    required this.total,
  });

  final int count;
  final double total;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.secondary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_rounded,
            color: AppColors.secondary,
            size: 18,
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            '$count ${count == 1 ? 'material' : 'materiales'} registrados',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppColors.secondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
