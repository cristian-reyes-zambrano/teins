import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/authentication/presentation/controllers/auth_controller.dart';
import '../../features/authentication/presentation/pages/login_page.dart';
import '../../features/authentication/presentation/pages/splash_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/visits/presentation/pages/visits_list_page.dart';
import '../../features/visits/presentation/pages/visit_detail_page.dart';
import '../../features/dynamic_forms/presentation/pages/form_selector_page.dart';
import '../../features/dynamic_forms/presentation/pages/visit_form_page.dart';
import '../../features/materials/presentation/pages/visit_materials_page.dart';
import '../../features/photos/presentation/pages/visit_photos_page.dart';
import '../../features/annotations/presentation/pages/visit_annotations_page.dart';
import '../../features/visits/presentation/pages/visit_summary_page.dart' show VisitSummaryPage;
import 'app_routes.dart';

/// Router centralizado con protección de rutas autenticadas.
///
/// La redirección se maneja en el redirect callback de GoRouter.
/// Las rutas privadas verifican el estado de sesión de Supabase.
class AppRouter {
  AppRouter._();

  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static GoRouter get router => _router;

  static final GoRouter _router = GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: true,
    redirect: _guardRoute,
    routes: [
      // ── Splash / Auth check ────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),

      // ── Login ──────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),

      // ── Home ───────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),

      // ── Visits ────────────────────────────────────────────────────────
      GoRoute(
        path: AppRoutes.visits,
        builder: (context, state) => const VisitsListPage(),
        routes: [
          GoRoute(
            path: ':visitId',
            builder: (context, state) {
              final visitId = state.pathParameters['visitId']!;
              return VisitDetailPage(visitId: visitId);
            },
            routes: [
              GoRoute(
                path: 'form',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  // Soporte para multi-formulario: templateId y visitType
                  // se pasan como query params desde FormSelectorPage.
                  final templateId = state.uri.queryParameters['templateId'];
                  final visitType = state.uri.queryParameters['visitType'];
                  return VisitFormPage(
                    visitId: visitId,
                    overrideTemplateId: templateId,
                    overrideVisitType: visitType,
                  );
                },
              ),
              GoRoute(
                path: 'form-select',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  final visitType =
                      state.uri.queryParameters['visitType'] ?? 'general';
                  return FormSelectorPage(
                    visitId: visitId,
                    visitType: visitType,
                  );
                },
              ),
              GoRoute(
                path: 'materials',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  return VisitMaterialsPage(visitId: visitId);
                },
              ),
              GoRoute(
                path: 'photos',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  return VisitPhotosPage(visitId: visitId);
                },
              ),
              GoRoute(
                path: 'annotations',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  return VisitAnnotationsPage(visitId: visitId);
                },
              ),
              GoRoute(
                path: 'summary',
                builder: (context, state) {
                  final visitId = state.pathParameters['visitId']!;
                  return VisitSummaryPage(visitId: visitId);
                },
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => _ErrorPage(error: state.error),
  );

  /// Protege las rutas que requieren autenticación.
  static String? _guardRoute(BuildContext context, GoRouterState state) {
    // Modo demo: acceso libre a toda la app sin Supabase
    if (AuthController.isDemoMode) return null;

    // Intento leer la sesión de Supabase de forma segura
    bool isAuthenticated = false;
    try {
      final session = Supabase.instance.client.auth.currentSession;
      isAuthenticated = session != null;
    } catch (_) {
      // Supabase no inicializado (sin credenciales reales) → no autenticado
      isAuthenticated = false;
    }

    final isOnAuthRoute = state.matchedLocation == AppRoutes.login ||
        state.matchedLocation == AppRoutes.splash;

    if (!isAuthenticated && !isOnAuthRoute) {
      return AppRoutes.login;
    }

    return null;
  }
}

class _ErrorPage extends StatelessWidget {
  const _ErrorPage({this.error});

  final Exception? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Página no encontrada',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.home),
              child: const Text('Ir al inicio'),
            ),
          ],
        ),
      ),
    );
  }
}
