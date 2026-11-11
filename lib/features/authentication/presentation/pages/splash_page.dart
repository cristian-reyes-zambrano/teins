import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_colors.dart';
import '../controllers/auth_controller.dart';
import '../../domain/entities/user_profile.dart';
import '../providers/auth_providers.dart';

/// Pantalla de splash: decide en milisegundos si hay sesión activa.
///
/// Lee la sesión local de Supabase (sin red) y navega inmediatamente.
/// PowerSync se inicializa en background sin bloquear la UI.
class SplashPage extends ConsumerStatefulWidget {
  const SplashPage({super.key});

  @override
  ConsumerState<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends ConsumerState<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _decide());
  }

  void _decide() {
    if (!mounted) return;

    try {
      // Leer sesión local — sin llamada de red, instantáneo
      final session = Supabase.instance.client.auth.currentSession;

      if (session != null) {
        // Hay sesión guardada: construir usuario desde metadata local
        final user = session.user;
        final meta = user.userMetadata ?? {};
        final profile = UserProfile(
          id: user.id,
          email: user.email ?? '',
          role: UserRole.fromString(meta['role'] as String? ?? 'technician'),
          fullName: meta['full_name'] as String?,
        );

        // Actualizar el controller con el usuario
        ref.read(authControllerProvider.notifier).setUserFromSession(profile);

        // Inicializar PowerSync en background
        Future(() => ref
            .read(authControllerProvider.notifier)
            .initPowerSyncInBackground());

        context.go(AppRoutes.home);
      } else {
        context.go(AppRoutes.login);
      }
    } catch (e) {
      // Supabase no inicializado o error — ir al login
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Icon(
                Icons.engineering_rounded,
                size: 56,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'TEINS',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Visitas Técnicas',
              style: TextStyle(
                color: Colors.white.withOpacity(0.75),
                fontSize: 14,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 64),
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
