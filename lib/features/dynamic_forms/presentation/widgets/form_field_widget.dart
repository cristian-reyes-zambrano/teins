import 'package:flutter/material.dart';
import 'package:material_ui/material_ui.dart' as mui
    show InputDecoration, InputBorder, DropdownMenuItem;
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:form_builder_validators/form_builder_validators.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../domain/entities/form_template.dart';

/// Motor de renderizado de campos de formulario dinámico.
///
/// Importa flutter/material.dart para los widgets del árbol (Material, Text, etc.)
/// e importa material_ui solo para los tipos que flutter_form_builder v11 espera
/// en sus parámetros (InputDecoration, DropdownMenuItem).
class FormFieldWidget extends StatelessWidget {
  const FormFieldWidget({
    super.key,
    required this.field,
    required this.initialValue,
    required this.onChanged,
    this.enabled = true,
  });

  final FormFieldDefinition field;
  final dynamic initialValue;
  final void Function(String fieldId, dynamic value) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildField(context),
            if (field.unit != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  'Unidad: ${field.unit}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(BuildContext context) {
    switch (field.type) {
      case FormFieldType.text:
        return _buildTextField();
      case FormFieldType.textarea:
        return _buildTextAreaField();
      case FormFieldType.number:
        return _buildNumberField(isDecimal: false);
      case FormFieldType.decimal:
      case FormFieldType.measure:
        return _buildNumberField(isDecimal: true);
      case FormFieldType.select:
        return _buildSelectField();
      case FormFieldType.multiSelect:
        return _buildMultiSelectField();
      case FormFieldType.boolean:
        return _buildBooleanField();
      case FormFieldType.date:
        return _buildDateField();
      case FormFieldType.time:
        return _buildTimeField();
      case FormFieldType.photo:
        return _buildPhotoPlaceholder();
      case FormFieldType.materials:
        return _buildMaterialsPlaceholder();
    }
  }

  // ── Campos ────────────────────────────────────────────────────────────────

  Widget _buildTextField() {
    return FormBuilderTextField(
      name: field.id,
      initialValue: initialValue?.toString(),
      enabled: enabled,
      decoration: _deco(),
      textCapitalization: TextCapitalization.sentences,
      validator: _strValidator(),
      onChanged: (v) => onChanged(field.id, v),
    );
  }

  Widget _buildTextAreaField() {
    return FormBuilderTextField(
      name: field.id,
      initialValue: initialValue?.toString(),
      enabled: enabled,
      maxLines: 4,
      minLines: 3,
      decoration: _deco(),
      textCapitalization: TextCapitalization.sentences,
      validator: _strValidator(),
      onChanged: (v) => onChanged(field.id, v),
    );
  }

  Widget _buildNumberField({required bool isDecimal}) {
    return FormBuilderTextField(
      name: field.id,
      initialValue: initialValue?.toString(),
      enabled: enabled,
      keyboardType: TextInputType.numberWithOptions(decimal: isDecimal),
      decoration: _deco(suffix: field.unit != null ? Text(field.unit!) : null),
      validator: FormBuilderValidators.compose([
        if (field.required) FormBuilderValidators.required(),
        if (isDecimal)
          FormBuilderValidators.numeric(errorText: 'Número inválido'),
        if (!isDecimal)
          FormBuilderValidators.integer(errorText: 'Número entero requerido'),
        if (field.minValue != null)
          FormBuilderValidators.min(field.minValue!,
              errorText: 'Mínimo: ${field.minValue}'),
        if (field.maxValue != null)
          FormBuilderValidators.max(field.maxValue!,
              errorText: 'Máximo: ${field.maxValue}'),
      ]),
      onChanged: (v) {
        if (v == null || v.isEmpty) { onChanged(field.id, null); return; }
        onChanged(field.id, isDecimal ? double.tryParse(v) ?? v : int.tryParse(v) ?? v);
      },
    );
  }

  Widget _buildSelectField() {
    return FormBuilderDropdown<String>(
      name: field.id,
      initialValue: initialValue?.toString(),
      enabled: enabled,
      decoration: _deco(),
      validator: _strValidator(),
      items: field.options
          .map((opt) => mui.DropdownMenuItem(value: opt, child: Text(opt)))
          .toList(),
      onChanged: (v) => onChanged(field.id, v),
    );
  }

  Widget _buildMultiSelectField() {
    final current = initialValue is List
        ? List<String>.from(initialValue as List)
        : <String>[];
    return FormBuilderFilterChips<String>(
      name: field.id,
      initialValue: current,
      decoration: _deco(),
      options: field.options
          .map((opt) => FormBuilderChipOption(value: opt, child: Text(opt)))
          .toList(),
      onChanged: (v) => onChanged(field.id, v),
    );
  }

  Widget _buildBooleanField() {
    return FormBuilderSwitch(
      name: field.id,
      title: Text(field.label, style: const TextStyle(fontSize: 15)),
      initialValue: initialValue as bool? ?? false,
      enabled: enabled,
      decoration: const mui.InputDecoration(border: mui.InputBorder.none),
      onChanged: (v) => onChanged(field.id, v),
    );
  }

  Widget _buildDateField() {
    DateTime? initial;
    if (initialValue is String) initial = DateTime.tryParse(initialValue as String);
    return FormBuilderDateTimePicker(
      name: field.id,
      initialValue: initial,
      enabled: enabled,
      inputType: InputType.date,
      decoration: _deco(),
      validator: field.required
          ? (DateTime? v) => v == null ? '${field.label} es requerido' : null
          : null,
      onChanged: (v) => onChanged(field.id, v?.toUtc().toIso8601String()),
    );
  }

  Widget _buildTimeField() {
    DateTime? initial;
    if (initialValue is String) initial = DateTime.tryParse(initialValue as String);
    return FormBuilderDateTimePicker(
      name: field.id,
      initialValue: initial,
      enabled: enabled,
      inputType: InputType.time,
      decoration: _deco(),
      onChanged: (v) => onChanged(field.id, v?.toUtc().toIso8601String()),
    );
  }

  Widget _buildPhotoPlaceholder() => _placeholderTile(
        icon: Icons.photo_camera_outlined,
        label: field.label,
        hint: 'Ver sección Fotografías',
      );

  Widget _buildMaterialsPlaceholder() => _placeholderTile(
        icon: Icons.inventory_2_outlined,
        label: field.label,
        hint: 'Ver sección Materiales',
      );

  Widget _placeholderTile({
    required IconData icon,
    required String label,
    required String hint,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const Spacer(),
          Text(
            hint,
            style: const TextStyle(
              color: AppColors.primary,
              fontSize: 12,
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Crea InputDecoration de material_ui (compatible con flutter_form_builder v11).
  mui.InputDecoration _deco({Widget? suffix}) {
    return mui.InputDecoration(
      labelText: field.required ? '${field.label} *' : field.label,
      hintText: field.hint,
      suffix: suffix,
    );
  }

  FormFieldValidator<String>? _strValidator() {
    if (!field.required) return null;
    return FormBuilderValidators.required(
      errorText: '${field.label} es requerido',
    );
  }
}
