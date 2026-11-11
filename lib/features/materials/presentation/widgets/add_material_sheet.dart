import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/uuid_generator.dart';
import '../../domain/entities/material.dart';
import '../providers/material_providers.dart';

/// Bottom sheet para buscar/agregar materiales a una visita.
/// Soporta:
///   1. Buscar en el catálogo existente
///   2. Crear un material personalizado (no está en el catálogo)
class AddMaterialSheet extends ConsumerStatefulWidget {
  const AddMaterialSheet({super.key, required this.visitId});

  final String visitId;

  @override
  ConsumerState<AddMaterialSheet> createState() => _AddMaterialSheetState();
}

class _AddMaterialSheetState extends ConsumerState<AddMaterialSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // ── Estado búsqueda catálogo ─────────────────────────────
  final _searchController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _obsController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;
  CatalogMaterial? _selectedMaterial;
  Timer? _debounce;

  // ── Estado material personalizado ───────────────────────
  final _customFormKey = GlobalKey<FormState>();
  final _customNameController = TextEditingController();
  final _customCodeController = TextEditingController();
  final _customUnitController = TextEditingController(text: 'unidad');
  final _customQtyController = TextEditingController(text: '1');
  final _customObsController = TextEditingController();
  final _customCategoryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _debounce?.cancel();
    _searchController.dispose();
    _qtyController.dispose();
    _obsController.dispose();
    _customNameController.dispose();
    _customCodeController.dispose();
    _customUnitController.dispose();
    _customQtyController.dispose();
    _customObsController.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted) setState(() => _searchQuery = value);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
          ),
          child: Column(
            children: [
              // Handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: AppSpacing.sm),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.grey300,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                ),
              ),

              // Encabezado
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
                child: Row(
                  children: [
                    const Text(
                      'Agregar material',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),

              // Tabs: Catálogo | Personalizado
              TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(
                    icon: Icon(Icons.search_rounded, size: 18),
                    text: 'Del catálogo',
                  ),
                  Tab(
                    icon: Icon(Icons.add_box_outlined, size: 18),
                    text: 'Personalizado',
                  ),
                ],
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.textSecondary,
                indicatorColor: AppColors.primary,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
              ),

              // Contenido de tabs
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _CatalogTab(
                      scrollController: scrollController,
                      searchController: _searchController,
                      qtyController: _qtyController,
                      obsController: _obsController,
                      searchQuery: _searchQuery,
                      selectedCategory: _selectedCategory,
                      selectedMaterial: _selectedMaterial,
                      visitId: widget.visitId,
                      onSearchChanged: _onSearchChanged,
                      onCategorySelected: (cat) => setState(
                        () => _selectedCategory =
                            _selectedCategory == cat ? null : cat,
                      ),
                      onMaterialSelected: (mat) =>
                          setState(() => _selectedMaterial = mat),
                      onClearMaterial: () =>
                          setState(() => _selectedMaterial = null),
                    ),
                    _CustomMaterialTab(
                      formKey: _customFormKey,
                      nameController: _customNameController,
                      codeController: _customCodeController,
                      unitController: _customUnitController,
                      qtyController: _customQtyController,
                      obsController: _customObsController,
                      categoryController: _customCategoryController,
                      visitId: widget.visitId,
                      onAdded: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Tab 1: Buscar en catálogo ─────────────────────────────────────────────────

class _CatalogTab extends ConsumerWidget {
  const _CatalogTab({
    required this.scrollController,
    required this.searchController,
    required this.qtyController,
    required this.obsController,
    required this.searchQuery,
    required this.selectedCategory,
    required this.selectedMaterial,
    required this.visitId,
    required this.onSearchChanged,
    required this.onCategorySelected,
    required this.onMaterialSelected,
    required this.onClearMaterial,
  });

  final ScrollController scrollController;
  final TextEditingController searchController;
  final TextEditingController qtyController;
  final TextEditingController obsController;
  final String searchQuery;
  final String? selectedCategory;
  final CatalogMaterial? selectedMaterial;
  final String visitId;
  final void Function(String) onSearchChanged;
  final void Function(String) onCategorySelected;
  final void Function(CatalogMaterial) onMaterialSelected;
  final VoidCallback onClearMaterial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(catalogCategoriesProvider);
    final searchParams = CatalogSearchParams(
      query: searchQuery,
      category: selectedCategory,
    );
    final resultsAsync = ref.watch(catalogSearchProvider(searchParams));

    if (selectedMaterial != null) {
      return _QuantityForm(
        material: selectedMaterial!,
        visitId: visitId,
        qtyController: qtyController,
        obsController: obsController,
        onCancel: onClearMaterial,
        onAdd: () async {
          final qty = double.tryParse(qtyController.text);
          if (qty == null || qty <= 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                  content: Text('Ingresa una cantidad válida.')),
            );
            return;
          }
          await ref.read(materialActionProvider.notifier).add(
                visitId: visitId,
                material: selectedMaterial!,
                quantity: qty,
                observations: obsController.text.trim().isNotEmpty
                    ? obsController.text.trim()
                    : null,
              );
          if (context.mounted) Navigator.of(context).pop();
        },
      );
    }

    return Column(
      children: [
        // Buscador
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: TextField(
            controller: searchController,
            decoration: const InputDecoration(
              hintText: 'Buscar por nombre o código...',
              prefixIcon: Icon(Icons.search_rounded),
            ),
            onChanged: onSearchChanged,
            autofocus: false,
          ),
        ),

        // Filtro categorías
        categoriesAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (categories) => categories.isEmpty
              ? const SizedBox.shrink()
              : SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md),
                    itemCount: categories.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: AppSpacing.xs),
                    itemBuilder: (context, i) {
                      final cat = categories[i];
                      return FilterChip(
                        label: Text(cat,
                            style: const TextStyle(fontSize: 12)),
                        selected: selectedCategory == cat,
                        onSelected: (_) => onCategorySelected(cat),
                        selectedColor: AppColors.primaryLight,
                      );
                    },
                  ),
                ),
        ),

        // Resultados
        Expanded(
          child: resultsAsync.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.error, size: 40),
                    const SizedBox(height: AppSpacing.sm),
                    const Text(
                      'Error al cargar materiales.\nVerifica que la base de datos esté inicializada.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            data: (materials) {
              if (materials.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.inventory_2_outlined,
                            color: AppColors.grey400, size: 48),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          searchQuery.isEmpty
                              ? 'El catálogo está vacío.\nUsa la pestaña "Personalizado" para agregar un material.'
                              : 'No se encontraron materiales con "$searchQuery".',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                );
              }
              return ListView.builder(
                controller: scrollController,
                padding:
                    const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                itemCount: materials.length,
                itemBuilder: (context, index) {
                  final mat = materials[index];
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.inventory_2_outlined,
                          size: 20, color: AppColors.secondary),
                    ),
                    title: Text(mat.name,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500)),
                    subtitle: Text(
                      '${mat.code} · ${mat.unit}${mat.category != null ? ' · ${mat.category}' : ''}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.add_circle_rounded,
                          color: AppColors.primary),
                      onPressed: () => onMaterialSelected(mat),
                      tooltip: 'Seleccionar',
                    ),
                    onTap: () => onMaterialSelected(mat),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ── Tab 2: Material personalizado ─────────────────────────────────────────────

class _CustomMaterialTab extends ConsumerWidget {
  const _CustomMaterialTab({
    required this.formKey,
    required this.nameController,
    required this.codeController,
    required this.unitController,
    required this.qtyController,
    required this.obsController,
    required this.categoryController,
    required this.visitId,
    required this.onAdded,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController nameController;
  final TextEditingController codeController;
  final TextEditingController unitController;
  final TextEditingController qtyController;
  final TextEditingController obsController;
  final TextEditingController categoryController;
  final String visitId;
  final VoidCallback onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading =
        ref.watch(materialActionProvider) is MaterialActionLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.infoLight,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.info.withOpacity(0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: AppColors.info, size: 16),
                  SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Crea un material que no está en el catálogo. Solo se guardará en esta visita.',
                      style:
                          TextStyle(fontSize: 12, color: AppColors.info),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Nombre (requerido)
            TextFormField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Nombre del material *',
                hintText: 'Ej: Cable coaxial RG11',
              ),
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'El nombre es requerido' : null,
            ),
            const SizedBox(height: AppSpacing.md),

            // Código / referencia
            TextFormField(
              controller: codeController,
              decoration: const InputDecoration(
                labelText: 'Código / Referencia',
                hintText: 'Ej: CBL-RG11-001 (opcional)',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
            const SizedBox(height: AppSpacing.md),

            // Unidad y categoría en fila
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'Unidad *',
                      hintText: 'metro, unidad, kg...',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Requerido'
                        : null,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: TextFormField(
                    controller: categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Categoría',
                      hintText: 'Cableado, Equipos...',
                    ),
                    textCapitalization: TextCapitalization.words,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Cantidad
            TextFormField(
              controller: qtyController,
              keyboardType: const TextInputType.numberWithOptions(
                  decimal: true),
              decoration: InputDecoration(
                labelText: 'Cantidad *',
                suffix: Text(
                  unitController.text.trim().isNotEmpty
                      ? unitController.text.trim()
                      : 'unidades',
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Requerido';
                final parsed = double.tryParse(v);
                if (parsed == null || parsed <= 0) {
                  return 'Ingresa un número válido mayor a 0';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Observaciones
            TextFormField(
              controller: obsController,
              decoration: const InputDecoration(
                labelText: 'Observaciones',
                hintText: 'Detalles adicionales...',
              ),
              textCapitalization: TextCapitalization.sentences,
              maxLines: 2,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Botón agregar
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: isLoading ? null : () => _addCustomMaterial(context, ref),
                icon: isLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.add_rounded),
                label: const Text('Agregar a la visita'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addCustomMaterial(
      BuildContext context, WidgetRef ref) async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    final name = nameController.text.trim();
    final code = codeController.text.trim().isNotEmpty
        ? codeController.text.trim().toUpperCase()
        : 'CUSTOM-${DateTime.now().millisecondsSinceEpoch}';
    final unit = unitController.text.trim();
    final qty = double.tryParse(qtyController.text) ?? 1.0;
    final obs = obsController.text.trim().isNotEmpty
        ? obsController.text.trim()
        : null;
    final category = categoryController.text.trim().isNotEmpty
        ? categoryController.text.trim()
        : 'Personalizado';

    // Crear un CatalogMaterial temporal con UUID único
    final customMaterial = CatalogMaterial(
      id: UuidGenerator.generate(),
      code: code,
      name: name,
      unit: unit,
      category: category,
      description: obs,
      isActive: true,
    );

    await ref.read(materialActionProvider.notifier).add(
          visitId: visitId,
          material: customMaterial,
          quantity: qty,
          observations: obs,
        );

    if (context.mounted) onAdded();
  }
}

// ── Formulario de cantidad para material del catálogo ─────────────────────────

class _QuantityForm extends ConsumerWidget {
  const _QuantityForm({
    required this.material,
    required this.visitId,
    required this.qtyController,
    required this.obsController,
    required this.onCancel,
    required this.onAdd,
  });

  final CatalogMaterial material;
  final String visitId;
  final TextEditingController qtyController;
  final TextEditingController obsController;
  final VoidCallback onCancel;
  final Future<void> Function() onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoading =
        ref.watch(materialActionProvider) is MaterialActionLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card material seleccionado
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.secondary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(
                  color: AppColors.secondary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.inventory_2_outlined,
                    color: AppColors.secondary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(material.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600)),
                      Text(material.code,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                TextButton(
                    onPressed: onCancel, child: const Text('Cambiar')),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: qtyController,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Cantidad *',
              suffix: Text(material.unit),
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          TextField(
            controller: obsController,
            decoration: const InputDecoration(
              labelText: 'Observaciones (opcional)',
              hintText: 'Ej: instalado en rack 2',
            ),
            textCapitalization: TextCapitalization.sentences,
            maxLines: 2,
          ),
          const SizedBox(height: AppSpacing.xl),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isLoading ? null : onCancel,
                  child: const Text('Cancelar'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: isLoading ? null : onAdd,
                  icon: isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.add_rounded),
                  label: const Text('Agregar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
