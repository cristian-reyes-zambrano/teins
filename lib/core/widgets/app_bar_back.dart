import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// AppBar con botón de regreso automático cuando hay páginas anteriores.
///
/// Reemplaza el AppBar estándar en páginas secundarias para que el técnico
/// siempre pueda volver sin necesidad de reiniciar la app.
class AppBarBack extends StatelessWidget implements PreferredSizeWidget {
  const AppBarBack({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.backgroundColor,
    this.foregroundColor,
  });

  final Widget title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Size get preferredSize => Size.fromHeight(
        kToolbarHeight + (bottom?.preferredSize.height ?? 0),
      );

  @override
  Widget build(BuildContext context) {
    final canPop = context.canPop();

    return AppBar(
      backgroundColor: backgroundColor,
      foregroundColor: foregroundColor,
      title: title,
      actions: actions,
      bottom: bottom,
      // Mostrar botón back solo si hay página anterior en el stack
      leading: canPop
          ? IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              tooltip: 'Regresar',
              onPressed: () => context.pop(),
            )
          : null,
      automaticallyImplyLeading: false,
    );
  }
}
