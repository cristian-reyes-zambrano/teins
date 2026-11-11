import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../../authentication/presentation/providers/auth_providers.dart';
import '../../domain/entities/visit.dart';
import '../providers/visit_providers.dart';
import '../widgets/visit_card.dart';
import '../widgets/create_visit_dialog.dart';

/// Listado de visitas del técnico con búsqueda y filtros por estado.
class VisitsListPage extends ConsumerStatefulWidget {
  const VisitsListPage({super.key});

  @override
  ConsumerState<VisitsListPage> createState() => _VisitsListPageState();
}

class _VisitsListPageState extends ConsumerState<VisitsListPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Tabs: Todas, En progreso, Asignadas, Completadas
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);

    ref.listen<VisitActionState>(visitActionControllerProvider, (_, state) {
      if (state is VisitActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Visita creada correctamente.'),
            backgroundColor: AppColors.success,
          ),
        );
        ref.read(visitActionControllerProvider.notifier).reset();
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
      appBar: AppBar(
        title: const Text('Mis visitas'),
        leading: IconButton(
          icon: const Icon(Icons.home_rounded),
          tooltip: 'Inicio',
          onPressed: () => context.go(AppRoutes.home),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(
            28 + // Banner conectividad
                48 + // Buscador
                48, // Tabs
          ),
          child: Column(
            children: [
              const ConnectivityBanner(),
              _buildSearchBar(),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const [
                  Tab(text: 'Todas'),
                  Tab(text: 'En progreso'),
                  Tab(text: 'Asignadas'),
                  Tab(text: 'Completadas'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VisitsList(filter: null, searchQuery: _searchQuery),
          _VisitsList(
            filter: VisitStatus.inProgress,
            searchQuery: _searchQuery,
          ),
          _VisitsList(
            filter: VisitStatus.assigned,
            searchQuery: _searchQuery,
          ),
          _VisitsList(
            filter: VisitStatus.completed,
            searchQuery: _searchQuery,
          ),
        ],
      ),
      floatingActionButton: user != null
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateDialog(context, user.id),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva visita'),
            )
          : null,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xs,
      ),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Buscar visita...',
          prefixIcon: const Icon(Icons.search_rounded, size: 20),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            vertical: AppSpacing.sm,
          ),
        ),
        onChanged: (value) => setState(() => _searchQuery = value),
      ),
    );
  }

  void _showCreateDialog(BuildContext context, String technicianId) {
    showDialog<void>(
      context: context,
      builder: (_) => CreateVisitDialog(technicianId: technicianId),
    );
  }
}

class _VisitsList extends ConsumerWidget {
  const _VisitsList({required this.filter, required this.searchQuery});

  final VisitStatus? filter;
  final String searchQuery;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final visitsAsync = ref.watch(assignedVisitsProvider);

    return visitsAsync.when(
      loading: () => const AppLoading(message: 'Cargando visitas...'),
      error: (e, _) => AppErrorWidget(
        message: 'Error al cargar las visitas.',
        onRetry: () => ref.invalidate(assignedVisitsProvider),
      ),
      data: (either) => either.fold(
        (failure) => AppErrorWidget(
          message: failure.message,
          onRetry: () => ref.invalidate(assignedVisitsProvider),
        ),
        (visits) {
          var filtered = filter != null
              ? visits.where((v) => v.status == filter).toList()
              : visits;

          if (searchQuery.isNotEmpty) {
            final q = searchQuery.toLowerCase();
            filtered = filtered
                .where((v) =>
                    v.title.toLowerCase().contains(q) ||
                    (v.clientName?.toLowerCase().contains(q) ?? false) ||
                    (v.address?.toLowerCase().contains(q) ?? false) ||
                    v.visitType.toLowerCase().contains(q))
                .toList();
          }

          if (filtered.isEmpty) {
            return _EmptyVisits(filter: filter, hasSearch: searchQuery.isNotEmpty);
          }

          return RefreshIndicator(
            onRefresh: () async =>
                ref.invalidate(assignedVisitsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: filtered.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (context, index) {
                final visit = filtered[index];
                return VisitCard(
                  visit: visit,
                  onTap: () =>
                      context.go(AppRoutes.visitDetailPath(visit.id)),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits({this.filter, required this.hasSearch});

  final VisitStatus? filter;
  final bool hasSearch;

  @override
  Widget build(BuildContext context) {
    final message = hasSearch
        ? 'No se encontraron visitas con ese criterio de búsqueda.'
        : filter == null
            ? 'No tienes visitas asignadas.'
            : 'No tienes visitas ${filter!.displayName.toLowerCase()}.';

    return AppEmptyWidget(
      icon: Icons.assignment_outlined,
      message: message,
    );
  }
}
