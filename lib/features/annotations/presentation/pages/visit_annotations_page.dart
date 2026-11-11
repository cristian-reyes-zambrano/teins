import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../providers/annotation_providers.dart';
import '../widgets/annotation_toolbar.dart';
import '../widgets/drawing_canvas.dart';

/// Página del canvas de anotaciones.
///
/// Layout:
/// - AppBar (título + indicador de guardado + botón guardar)
/// - Banner de conectividad
/// - Canvas (área de dibujo — ocupa todo el espacio disponible)
/// - Toolbar en la parte inferior (herramientas, colores, grosores)
class VisitAnnotationsPage extends ConsumerWidget {
  const VisitAnnotationsPage({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(annotationEditorProvider(visitId));

    return Scaffold(
      backgroundColor: Colors.grey[900],
      appBar: AppBarBack(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Anotaciones', style: TextStyle(fontSize: 16)),
            _SaveIndicator(isSaving: state.isSaving, lastSaved: state.lastSavedAt),
          ],
        ),
        actions: [
          // Contador de elementos
          if (state.elements.isNotEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(
                  '${state.elements.length} elemento${state.elements.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.white70,
                  ),
                ),
              ),
            ),
          // Guardar manualmente
          IconButton(
            icon: const Icon(Icons.save_rounded),
            tooltip: 'Guardar ahora',
            onPressed: () => ref
                .read(annotationEditorProvider(visitId).notifier)
                .saveNow(),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: ConnectivityBanner(),
        ),
      ),
      body: state.annotation == null
          ? const AppLoading(message: 'Cargando canvas...')
          : Column(
              children: [
                // Canvas — fondo blanco o cuadrícula
                Expanded(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Fondo con cuadrícula
                      CustomPaint(
                        painter: _GridPainter(),
                        size: Size.infinite,
                      ),
                      // Canvas de dibujo
                      DrawingCanvas(visitId: visitId),
                    ],
                  ),
                ),
                // Toolbar de herramientas
                AnnotationToolbar(visitId: visitId),
              ],
            ),
    );
  }
}

/// Indicador de estado de guardado en el AppBar.
class _SaveIndicator extends StatelessWidget {
  const _SaveIndicator({required this.isSaving, this.lastSaved});

  final bool isSaving;
  final DateTime? lastSaved;

  @override
  Widget build(BuildContext context) {
    if (isSaving) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 10,
            height: 10,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white54),
            ),
          ),
          SizedBox(width: 4),
          Text(
            'Guardando...',
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      );
    }
    if (lastSaved != null) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_rounded, size: 11, color: Colors.green),
          SizedBox(width: 3),
          Text(
            'Guardado',
            style: TextStyle(fontSize: 10, color: Colors.white54),
          ),
        ],
      );
    }
    return const SizedBox.shrink();
  }
}

/// Fondo de cuadrícula para el canvas — facilita la orientación al técnico.
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const gridSize = 32.0;
    final paint = Paint()
      ..color = Colors.grey[700]!.withOpacity(0.4)
      ..strokeWidth = 0.5;

    // Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = Colors.white,
    );

    // Líneas verticales
    for (var x = 0.0; x <= size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    // Líneas horizontales
    for (var y = 0.0; y <= size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_GridPainter old) => false;
}
