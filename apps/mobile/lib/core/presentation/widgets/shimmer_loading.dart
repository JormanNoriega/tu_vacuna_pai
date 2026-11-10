import 'package:flutter/material.dart';

/// Ámbito heredado para sincronizar la animación de brillo a través de la jerarquía.
class _ShimmerScope extends InheritedWidget {
  const _ShimmerScope({
    required this.controller,
    required super.child,
  });

  final AnimationController controller;

  static AnimationController? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_ShimmerScope>()?.controller;
  }

  @override
  bool updateShouldNotify(_ShimmerScope oldWidget) => controller != oldWidget.controller;
}

/// Componente animado ligero para efectos Skeleton / Shimmer nativos a 60/120 FPS.
///
/// Desplaza un gradiente de luz de izquierda a derecha de forma continua
/// usando aceleración por hardware con [ShaderMask].
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({required this.child, super.key});

  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _ShimmerScope(
      controller: _controller,
      child: widget.child,
    );
  }
}

/// Aplica la máscara de brillo animada sincronizada con el [ShimmerLoading] ancestro,
/// o crea su propia animación autónoma si no tiene un ancestro.
class ShimmerEffect extends StatelessWidget {
  const ShimmerEffect({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = _ShimmerScope.maybeOf(context);

    if (controller == null) {
      return _StandaloneShimmer(child: child);
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, c) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE2E8F0), // Gris base suave
                Color(0xFFF8FAFC), // Brillo de paso
                Color(0xFFE2E8F0),
              ],
              stops: [
                controller.value - 0.3,
                controller.value,
                controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: c,
        );
      },
      child: child,
    );
  }
}

class _StandaloneShimmer extends StatefulWidget {
  const _StandaloneShimmer({required this.child});
  final Widget child;

  @override
  State<_StandaloneShimmer> createState() => _StandaloneShimmerState();
}

class _StandaloneShimmerState extends State<_StandaloneShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: const [
                Color(0xFFE2E8F0),
                Color(0xFFF8FAFC),
                Color(0xFFE2E8F0),
              ],
              stops: [
                _controller.value - 0.3,
                _controller.value,
                _controller.value + 0.3,
              ],
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
