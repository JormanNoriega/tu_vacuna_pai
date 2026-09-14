import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';

/// Tipo visual de un aviso de [AppSnackbar].
enum AppSnackbarType {
  /// Operacion completada.
  success,

  /// Informacion neutra del sistema.
  info,

  /// Aviso: falta un dato o la accion no aplica.
  warning,

  /// Fallo de una operacion.
  error,
}

/// Aviso transitorio en la parte superior de la pantalla.
///
/// Reemplaza a `ScaffoldMessenger.showSnackBar` en toda la app: aparece bajo la
/// barra de estado con una transicion de deslizamiento y fundido, se oculta
/// solo a los [duration] y muestra una sola instancia a la vez (un aviso nuevo
/// reemplaza al anterior).
abstract final class AppSnackbar {
  /// Tiempo visible del aviso.
  static const Duration duration = Duration(seconds: 3);

  /// Duracion de la transicion de entrada.
  static const Duration enterDuration = Duration(milliseconds: 220);

  /// Duracion de la transicion de salida.
  static const Duration exitDuration = Duration(milliseconds: 180);

  static OverlayEntry? _entry;

  /// Muestra [message] en la parte superior con el estilo de [type].
  static void show(
    BuildContext context,
    String message, {
    AppSnackbarType type = AppSnackbarType.info,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    // Una sola instancia: la nueva reemplaza a la anterior.
    dismiss();

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _AppSnackbar(
        message: message,
        type: type,
        actionLabel: actionLabel,
        onAction: onAction,
        onClosed: () {
          if (identical(_entry, entry)) _entry = null;
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _entry = entry;
    overlay.insert(entry);
  }

  /// Atajo para un aviso de exito.
  static void success(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.success);

  /// Atajo para un aviso de informacion.
  static void info(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.info);

  /// Atajo para un aviso de advertencia.
  static void warning(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.warning);

  /// Atajo para un aviso de error.
  static void error(BuildContext context, String message) =>
      show(context, message, type: AppSnackbarType.error);

  /// Cierra el aviso visible (si lo hay), sin animacion.
  static void dismiss() {
    final entry = _entry;
    _entry = null;
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _AppSnackbar extends StatefulWidget {
  const _AppSnackbar({
    required this.message,
    required this.type,
    required this.onClosed,
    this.actionLabel,
    this.onAction,
  });

  final String message;
  final AppSnackbarType type;
  final VoidCallback onClosed;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  State<_AppSnackbar> createState() => _AppSnackbarState();
}

class _AppSnackbarState extends State<_AppSnackbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppSnackbar.enterDuration,
    reverseDuration: AppSnackbar.exitDuration,
  );

  late final Animation<Offset> _slide =
      Tween<Offset>(
        begin: const Offset(0, -1.2),
        end: Offset.zero,
      ).animate(
        CurvedAnimation(
          parent: _controller,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        ),
      );

  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOut,
    reverseCurve: Curves.easeIn,
  );

  Timer? _timer;
  bool _closing = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(AppSnackbar.duration, _close);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Sin animaciones (accesibilidad): aparece directo.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    _timer?.cancel();
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) {
      widget.onClosed();
      return;
    }
    _controller.reverse().whenComplete(widget.onClosed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = _configFor(widget.type);
    final topInset = MediaQuery.paddingOf(context).top;

    return Positioned(
      top: topInset + 8,
      left: 16,
      right: 16,
      child: SlideTransition(
        position: _slide,
        child: FadeTransition(
          opacity: _fade,
          child: Semantics(
            liveRegion: true,
            container: true,
            label: '${config.semanticLabel}: ${widget.message}',
            child: _SnackbarSurface(
              config: config,
              message: widget.message,
              actionLabel: widget.actionLabel,
              onAction: widget.onAction == null
                  ? null
                  : () {
                      widget.onAction!.call();
                      _close();
                    },
            ),
          ),
        ),
      ),
    );
  }
}

class _SnackbarSurface extends StatelessWidget {
  const _SnackbarSurface({
    required this.config,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final _SnackbarConfig config;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    // `Material` provee el DefaultTextStyle de la app; sin el, los Text dentro
    // del Overlay heredan el estilo de error de WidgetsApp (subrayado amarillo).
    return Material(
      color: AppColors.surface,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: .18),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Franja de color: comunica el tipo de un vistazo.
            Container(width: 4, color: config.accent),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: config.soft,
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(config.icon, size: 19, color: config.accent),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                    if (actionLabel != null && onAction != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: onAction,
                        style: TextButton.styleFrom(
                          foregroundColor: config.accent,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: const Size(0, 36),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(actionLabel!),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SnackbarConfig {
  const _SnackbarConfig({
    required this.accent,
    required this.soft,
    required this.icon,
    required this.semanticLabel,
  });

  final Color accent;
  final Color soft;
  final IconData icon;
  final String semanticLabel;
}

_SnackbarConfig _configFor(AppSnackbarType type) => switch (type) {
  AppSnackbarType.success => const _SnackbarConfig(
    accent: AppColors.success,
    soft: AppColors.successSoft,
    icon: Icons.check_circle_rounded,
    semanticLabel: 'Listo',
  ),
  AppSnackbarType.info => const _SnackbarConfig(
    accent: AppColors.primary,
    soft: AppColors.primarySoft,
    icon: Icons.info_rounded,
    semanticLabel: 'Informacion',
  ),
  AppSnackbarType.warning => const _SnackbarConfig(
    accent: AppColors.warning,
    soft: AppColors.warningSoft,
    icon: Icons.warning_amber_rounded,
    semanticLabel: 'Aviso',
  ),
  AppSnackbarType.error => const _SnackbarConfig(
    accent: AppColors.danger,
    soft: AppColors.dangerSoft,
    icon: Icons.error_rounded,
    semanticLabel: 'Error',
  ),
};
