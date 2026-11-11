import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/config/app_config.dart';
import 'core/di/injection_container.dart';
import 'core/network/connectivity_service.dart';
import 'core/utils/logger.dart';
import 'features/synchronization/data/services/powersync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Orientación: permitir portrait y landscape para smartphone/tablet
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Barra de estado: modo light sobre fondo del AppBar
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // 1. Inicializar Supabase (recupera sesión automáticamente desde storage seguro)
  await _initSupabase();

  // 2. Configurar inyección de dependencias
  await configureDependencies();

  // 3. Inicializar conectividad
  await sl<ConnectivityService>().initialize();

  // 4. PowerSync se inicializa después del login — no al arrancar
  // Esto evita loops de credenciales cuando no hay sesión activa.

  AppLogger.i('App TEINS iniciada [${AppConfig.environment.name}]');

  runApp(
    const ProviderScope(
      child: TeinsApp(),
    ),
  );
}

Future<void> _initSupabase() async {
  try {
    await Supabase.initialize(
      url: AppConfig.supabaseUrl,
      anonKey: AppConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
      realtimeClientOptions: const RealtimeClientOptions(
        logLevel: RealtimeLogLevel.info,
      ),
    );
    AppLogger.i('Supabase inicializado.');
  } catch (e) {
    // Sin credenciales reales (demo/dev sin --dart-define) la app
    // funciona en modo local sin sincronización.
    AppLogger.w('Supabase no disponible — modo local activo: $e');
  }
}

Future<void> _initPowerSyncIfAuthenticated() async {
  try {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      AppLogger.i('Sin sesión activa — PowerSync no se conecta al inicio.');
      return;
    }

    final powerSync = sl<PowerSyncService>();
    await powerSync.initialize();
    await powerSync.connect();
    AppLogger.i('PowerSync conectado al inicio (sesión existente).');
  } catch (e) {
    AppLogger.w('PowerSync: no se pudo inicializar: $e');
    try {
      await sl<PowerSyncService>().initialize();
    } catch (_) {}
  }
}
