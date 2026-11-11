import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/usecases/create_visit.dart';
import '../providers/visit_providers.dart';

/// Diálogo para crear una nueva visita técnica.
/// Campos mínimos necesarios — sin sobrecargar al técnico.
class CreateVisitDialog extends ConsumerStatefulWidget {
  const CreateVisitDialog({super.key, required this.technicianId});

  final String technicianId;

  @override
  ConsumerState<CreateVisitDialog> createState() => _CreateVisitDialogState();
}

class _CreateVisitDialogState extends ConsumerState<CreateVisitDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _clientController = TextEditingController();
  final _addressController = TextEditingController();
  String _selectedType = 'general';

  static const _visitTypes = [
    ('general', 'Visita Técnica TEINS', Icons.assignment_rounded),
    ('ups', 'Informe UPS (CDP)', Icons.battery_charging_full_rounded),
    ('infraestructura', 'Infraestructura', Icons.construction_rounded),
    ('energia', 'Energía', Icons.bolt_rounded),
    ('datos', 'Datos / Red', Icons.cable_rounded),
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _clientController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final actionState = ref.watch(visitActionControllerProvider);
    final isLoading = actionState is VisitActionLoading;

    // Cerrar diálogo en éxito
    ref.listen<VisitActionState>(visitActionControllerProvider, (_, state) {
      if (state is VisitActionSuccess && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });

    return AlertDialog(
      title: const Text('Nueva visita'),
      contentPadding: const EdgeInsets.fromLTRB(
        AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0,
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tipo de visita
                const Text(
                  'Tipo de visita',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  children: _visitTypes.map((type) {
                    final (value, label, icon) = type;
                    final isSelected = _selectedType == value;
                    return ChoiceChip(
                      label: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon, size: 16),
                          const SizedBox(width: 4),
                          Text(label),
                        ],
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primaryLight,
                      onSelected: (_) =>
                          setState(() => _selectedType = value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppSpacing.md),

                // Título
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Título de la visita *',
                    hintText: 'Ej: Revisión tablero eléctrico planta 2',
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v?.trim().isEmpty ?? true)
                      ? 'El título es requerido'
                      : null,
                ),
                const SizedBox(height: AppSpacing.md),

                // Cliente
                TextFormField(
                  controller: _clientController,
                  decoration: const InputDecoration(
                    labelText: 'Cliente',
                    hintText: 'Nombre del cliente o empresa',
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: AppSpacing.md),

                // Dirección
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Dirección / Ubicación',
                    hintText: 'Dirección del sitio',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: 2,
                ),
                const SizedBox(height: AppSpacing.md),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: isLoading ? null : _submit,
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text('Crear visita'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    await ref.read(visitActionControllerProvider.notifier).createVisit(
          CreateVisitParams(
            technicianId: widget.technicianId,
            title: _titleController.text.trim(),
            visitType: _selectedType,
            clientName: _clientController.text.trim().isNotEmpty
                ? _clientController.text.trim()
                : null,
            address: _addressController.text.trim().isNotEmpty
                ? _addressController.text.trim()
                : null,
          ),
        );
  }
}
