import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/di/injection_container.dart';
import '../../../../core/errors/failures.dart';
import '../../../../core/utils/logger.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/authenticate_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/sign_out.dart';
import '../../../synchronization/data/services/powersync_service.dart';
import '../../../materials/domain/repositories/material_repository.dart';

/// Estado del proceso de autenticación.
sealed class AuthState {
  const AuthState();
}

class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserProfile user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.failure);
  final Failure failure;
}

/// Controller de autenticación gestionado por Riverpod.
///
/// Orquesta los casos de uso y expone el estado a la UI.
/// La UI NO conoce Supabase directamente.
class AuthController extends StateNotifier<AuthState> {
  AuthController({
    required AuthenticateUser authenticateUser,
    required GetCurrentUser getCurrentUser,
    required SignOut signOut,
  })  : _authenticateUser = authenticateUser,
        _getCurrentUser = getCurrentUser,
        _signOut = signOut,
        super(const AuthInitial());

  final AuthenticateUser _authenticateUser;
  final GetCurrentUser _getCurrentUser;
  final SignOut _signOut;

  /// Indica si la app está en modo demo (sin Supabase).
  /// El router lo consulta para no redirigir al login.
  static bool isDemoMode = false;

  /// Inicia sesión. Emite [AuthLoading] → [AuthAuthenticated] o [AuthError].
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = const AuthLoading();
    final result = await _authenticateUser(
      AuthenticateUserParams(email: email, password: password),
    );

    if (result.isLeft()) {
      final failure = result.fold((f) => f, (_) => null)!;
      AppLogger.w('signIn failure: ${failure.message}');
      state = AuthError(failure);
      return;
    }

    final user = result.fold((_) => null, (u) => u)!;
    AppLogger.i('Login exitoso: ${user.email}');
    state = AuthAuthenticated(user);

    // Inicializar PowerSync ahora que hay sesión activa
    await _initPowerSync();
  }

  /// Verifica si existe una sesión activa al arrancar la app.
  Future<void> checkSession() async {
    state = const AuthLoading();
    final result = await _getCurrentUser();

    if (result.isLeft()) {
      AppLogger.w('checkSession failure');
      state = const AuthUnauthenticated();
      return;
    }

    final user = result.fold((_) => null, (u) => u);
    if (user != null) {
      AppLogger.i('Sesión recuperada: ${user.email}');
      state = AuthAuthenticated(user);
      await _initPowerSync();
    } else {
      state = const AuthUnauthenticated();
    }
  }

  Future<void> _initPowerSync() async {
    // Lanzar en background sin bloquear la navegación
    Future(() async {
      try {
        final powerSync = sl<PowerSyncService>();
        if (!powerSync.isInitialized) {
          await powerSync.initialize();
          AppLogger.i('PowerSync inicializado.');
        }
        await powerSync.connect();
        AppLogger.i('PowerSync conectado.');
        // Sembrar catálogo de materiales si está vacío
        await _seedMaterialsIfEmpty();
      } catch (e) {
        // Sin conexión o sin credenciales PowerSync — la app funciona en modo local
        AppLogger.w('PowerSync no disponible: $e');
        // Intentar sembrar materiales aunque PowerSync no conecte
        await _seedMaterialsIfEmpty();
      }
    });
  }

  Future<void> _seedMaterialsIfEmpty() async {
    try {
      final materialRepo = sl<MaterialRepository>();
      await materialRepo.seedDemoMaterials();
      AppLogger.i('Catálogo de materiales sembrado.');
    } catch (e) {
      AppLogger.w('No se pudo sembrar el catálogo: $e');
    }
  }

  /// Establece el usuario directamente desde la sesión local (sin red).
  /// Usado por SplashPage para navegación instantánea.
  void setUserFromSession(UserProfile user) {
    state = AuthAuthenticated(user);
  }

  /// Inicia PowerSync en background — llamar sin await.
  Future<void> initPowerSyncInBackground() async {
    await _initPowerSync();
  }

  /// Cierra la sesión y limpia el estado.
  Future<void> signOut() async {
    await _signOut();
    state = const AuthUnauthenticated();
  }

  /// Modo demo — entra a la app sin credenciales reales.
  /// Solo para presentaciones. No llama a Supabase.
  void enterDemoMode() {
    AuthController.isDemoMode = true;
    const demoUser = UserProfile(
      id: 'a9c8bb91-26b0-4169-9495-13bb569929cf',
      email: 'tecnico@teins.com',
      role: UserRole.technician,
      fullName: 'Carlos Técnico Demo',
    );
    AppLogger.i('Modo demo activado');
    state = const AuthAuthenticated(demoUser);
    // Inicializar SQLite local y sembrar catálogo en background
    Future(() async {
      try {
        final powerSync = sl<PowerSyncService>();
        await powerSync.initialize();
        AppLogger.i('PowerSync (modo local) inicializado.');
        await _seedMaterialsIfEmpty();
      } catch (e) {
        AppLogger.w('PowerSync local no disponible en demo: $e');
      }
    });
  }

  UserProfile? get currentUser {
    final s = state;
    return s is AuthAuthenticated ? s.user : null;
  }
}
