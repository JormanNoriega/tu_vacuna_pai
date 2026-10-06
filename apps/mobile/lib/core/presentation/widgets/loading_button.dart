import 'package:flutter/material.dart';

/// Estilo visual de [LoadingButton].
enum LoadingButtonStyle {
  /// Boton relleno (`ElevatedButton`): texto blanco.
  filled,

  /// Boton de contorno (`OutlinedButton`): texto en tinta.
  outlined,
}

/// Boton con estado de carga: mientras [loading] es true deshabilita el boton y
/// muestra un spinner en lugar de su icono, evitando el "gris mudo" de un boton
/// solo deshabilitado.
class LoadingButton extends StatelessWidget {
  const LoadingButton({
    required this.onPressed,
    required this.loading,
    required this.label,
    this.loadingLabel,
    this.icon,
    this.style = LoadingButtonStyle.filled,
    super.key,
  });

  /// Accion del boton. Ignorada mientras [loading] es true.
  final VoidCallback? onPressed;

  /// Estado de carga: deshabilita el boton y muestra el spinner.
  final bool loading;

  /// Texto del boton en reposo.
  final String label;

  /// Texto alternativo mientras [loading] es true. Si es null se mantiene
  /// [label], conservando el comportamiento base del boton.
  final String? loadingLabel;

  /// Icono a la izquierda (se reemplaza por el spinner al cargar).
  final IconData? icon;

  /// Estilo relleno u contorno.
  final LoadingButtonStyle style;

  Widget _leading(BuildContext context) {
    if (loading) {
      return SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: style == LoadingButtonStyle.filled
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.primary,
        ),
      );
    }
    return icon == null ? const SizedBox.shrink() : Icon(icon, size: 20);
  }

  @override
  Widget build(BuildContext context) {
    final child = Text(loading ? (loadingLabel ?? label) : label);
    final leading = _leading(context);
    return switch (style) {
      LoadingButtonStyle.filled => ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: leading,
        label: child,
      ),
      LoadingButtonStyle.outlined => OutlinedButton.icon(
        onPressed: loading ? null : onPressed,
        icon: leading,
        label: child,
      ),
    };
  }
}
