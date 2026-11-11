import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_bar_back.dart';
import '../../../../core/widgets/app_error_widget.dart';
import '../../../../core/widgets/app_loading.dart';
import '../../../../core/widgets/connectivity_banner.dart';
import '../../domain/entities/photo.dart';
import '../providers/photo_providers.dart';

/// Galería de fotografías de la visita.
/// Permite capturar, visualizar y eliminar fotos, todo offline.
class VisitPhotosPage extends ConsumerWidget {
  const VisitPhotosPage({super.key, required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(visitPhotosProvider(visitId));
    final actionState = ref.watch(photoActionProvider);

    ref.listen<PhotoActionState>(photoActionProvider, (_, state) {
      if (!context.mounted) return;
      if (state is PhotoActionError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(state.failure.message),
            backgroundColor: AppColors.error,
          ),
        );
        ref.read(photoActionProvider.notifier).reset();
      } else if (state is PhotoActionSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotografía guardada en el dispositivo.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(photoActionProvider.notifier).reset();
      } else if (state is PhotoDeleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fotografía eliminada.'),
            duration: Duration(seconds: 2),
          ),
        );
        ref.read(photoActionProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBarBack(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fotografías'),
            photosAsync.when(
              data: (photos) => Text(
                '${photos.length} foto${photos.length == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
              ),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: ConnectivityBanner(),
        ),
        actions: [
          if (actionState is PhotoActionLoading)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
        ],
      ),
      body: photosAsync.when(
        loading: () => const AppLoading(message: 'Cargando fotografías...'),
        error: (_, __) => const AppErrorWidget(
          message: 'Error al cargar las fotografías.',
        ),
        data: (photos) => photos.isEmpty
            ? const AppEmptyWidget(
                icon: Icons.photo_camera_outlined,
                message: 'No hay fotografías.\nToca el botón para capturar.',
              )
            : _PhotoGrid(
                photos: photos,
                visitId: visitId,
                onDelete: (photoId) =>
                    ref.read(photoActionProvider.notifier).delete(photoId),
              ),
      ),
      // FAB con 2 opciones: cámara o galería
      floatingActionButton: _CaptureButton(visitId: visitId),
    );
  }
}

/// Grid de thumbnails de fotos con indicadores de estado de sync.
class _PhotoGrid extends StatelessWidget {
  const _PhotoGrid({
    required this.photos,
    required this.visitId,
    required this.onDelete,
  });

  final List<VisitPhoto> photos;
  final String visitId;
  final void Function(String) onDelete;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.sm),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
      ),
      itemCount: photos.length,
      itemBuilder: (context, index) {
        final photo = photos[index];
        return _PhotoThumbnail(
          photo: photo,
          onTap: () => _openFullscreen(context, photos, index),
          onDelete: () => _confirmDelete(context, photo),
        );
      },
    );
  }

  void _openFullscreen(
    BuildContext context,
    List<VisitPhoto> photos,
    int initial,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _PhotoViewer(photos: photos, initialIndex: initial),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, VisitPhoto photo) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar fotografía'),
        content: const Text(
          '¿Eliminar esta fotografía? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) onDelete(photo.id);
  }
}

/// Thumbnail individual con indicador de estado de sync.
class _PhotoThumbnail extends StatelessWidget {
  const _PhotoThumbnail({
    required this.photo,
    required this.onTap,
    required this.onDelete,
  });

  final VisitPhoto photo;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Imagen
          _buildImage(),

          // Indicador de sync en esquina inferior derecha
          Positioned(
            bottom: 4,
            right: 4,
            child: _SyncDot(status: photo.syncStatus),
          ),
        ],
      ),
    );
  }

  Widget _buildImage() {
    // Si existe localmente, mostrar desde disco
    final file = File(photo.localPath);
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snap) {
          if (snap.data == true) {
            return Image.file(
              file,
              fit: BoxFit.cover,
              cacheWidth: 300, // Limitar memoria para thumbnails
            );
          }
          // Fallback a URL remota si está disponible
          if (photo.storageUrl != null) {
            return Image.network(
              photo.storageUrl!,
              fit: BoxFit.cover,
              cacheWidth: 300,
              errorBuilder: (_, __, ___) => _Placeholder(),
            );
          }
          return _Placeholder();
        },
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.grey200,
      child: const Icon(
        Icons.broken_image_outlined,
        color: AppColors.grey400,
      ),
    );
  }
}

/// Indicador de color según el estado de sincronización de la foto.
class _SyncDot extends StatelessWidget {
  const _SyncDot({required this.status});

  final PhotoSyncStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PhotoSyncStatus.uploaded => AppColors.online,
      PhotoSyncStatus.uploading => AppColors.syncing,
      PhotoSyncStatus.pendingUpload || PhotoSyncStatus.local =>
        AppColors.pendingSync,
      PhotoSyncStatus.uploadError => AppColors.error,
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

/// FAB con opciones de cámara o galería usando un SpeedDial manual.
class _CaptureButton extends ConsumerWidget {
  const _CaptureButton({required this.visitId});

  final String visitId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Galería
        FloatingActionButton.small(
          heroTag: 'gallery_fab',
          onPressed: () => ref
              .read(photoActionProvider.notifier)
              .pickFromGallery(visitId: visitId),
          backgroundColor: AppColors.grey700,
          tooltip: 'Seleccionar de galería',
          child: const Icon(Icons.photo_library_outlined),
        ),
        const SizedBox(height: AppSpacing.sm),
        // Cámara (primario)
        FloatingActionButton(
          heroTag: 'camera_fab',
          onPressed: () => ref
              .read(photoActionProvider.notifier)
              .captureFromCamera(visitId: visitId),
          tooltip: 'Tomar fotografía',
          child: const Icon(Icons.camera_alt_rounded),
        ),
      ],
    );
  }
}

/// Visor a pantalla completa con PageView para navegar entre fotos.
class _PhotoViewer extends StatefulWidget {
  const _PhotoViewer({required this.photos, required this.initialIndex});

  final List<VisitPhoto> photos;
  final int initialIndex;

  @override
  State<_PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends State<_PhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photo = widget.photos[_currentIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.photos.length}',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.photos.length,
        onPageChanged: (i) => setState(() => _currentIndex = i),
        itemBuilder: (context, index) {
          final p = widget.photos[index];
          final file = File(p.localPath);
          return InteractiveViewer(
            child: Center(
              child: FutureBuilder<bool>(
                future: file.exists(),
                builder: (context, snap) {
                  if (snap.data == true) {
                    return Image.file(file, fit: BoxFit.contain);
                  }
                  if (p.storageUrl != null) {
                    return Image.network(p.storageUrl!, fit: BoxFit.contain);
                  }
                  return const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white54,
                    size: 64,
                  );
                },
              ),
            ),
          );
        },
      ),
      // Caption y estado en la parte inferior
      bottomNavigationBar: Container(
        color: Colors.black87,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        child: Row(
          children: [
            _SyncDot(status: photo.syncStatus),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                photo.caption ?? 'Sin descripción',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
