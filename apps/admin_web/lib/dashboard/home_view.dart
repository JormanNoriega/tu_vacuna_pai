import 'package:flutter/material.dart';

import '../users/app_colors.dart';

/// Inicio administrativo: conserva la composición de Brayan sin presentar
/// metas, actividad diaria, mapas ni personal ficticios como información real.
class HomeView extends StatelessWidget {
  const HomeView({
    required this.name,
    required this.institutionName,
    required this.metrics,
    required this.onRefresh,
    required this.onNavigate,
    super.key,
  });

  final String name;
  final String institutionName;
  final Future<Map<String, dynamic>> metrics;
  final VoidCallback onRefresh;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async => onRefresh(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(context),
                const SizedBox(height: 24),
                FutureBuilder<Map<String, dynamic>>(
                  future: metrics,
                  builder: (context, snapshot) {
                    final data = snapshot.data;
                    final loading =
                        snapshot.connectionState != ConnectionState.done;
                    final error = snapshot.hasError;
                    String count(String key) {
                      final value = data?[key];
                      return value is int && value >= 0 ? '$value' : '—';
                    }

                    return LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 1050
                            ? 4
                            : constraints.maxWidth >= 700
                            ? 2
                            : 1;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 16) /
                            columns;
                        return Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: [
                            _metric(
                              width,
                              'Pacientes atendidos',
                              count('patientsAttended'),
                              Icons.people_alt_outlined,
                              loading: loading,
                              error: error,
                            ),
                            _metric(
                              width,
                              'Dosis aplicadas',
                              count('dosesApplied'),
                              Icons.vaccines_outlined,
                              loading: loading,
                              error: error,
                            ),
                            _contextMetric(
                              width,
                              'Institución',
                              institutionName,
                              Icons.domain_outlined,
                            ),
                            _contextMetric(
                              width,
                              'Panel',
                              'Gestión institucional PAI',
                              Icons.health_and_safety_outlined,
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 920;
                    final parameters = _parameters(context);
                    final geography = _geography(context);
                    if (compact) {
                      return Column(
                        children: [
                          parameters,
                          const SizedBox(height: 20),
                          geography,
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 5, child: parameters),
                        const SizedBox(width: 20),
                        Expanded(flex: 6, child: geography),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                _quickAccess(context),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 650;
        final greeting = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Bienvenido, $name',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'ADMINISTRADOR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: .5,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Panel de Control Clínico y Gestión Territorial · $institutionName',
              style: const TextStyle(color: AppColors.slate),
            ),
          ],
        );
        final refresh = Tooltip(
          message: 'Actualizar resumen',
          child: IconButton.filledTonal(
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primarySoft,
              foregroundColor: AppColors.primary,
            ),
          ),
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: greeting),
                      const SizedBox(width: 8),
                      refresh,
                    ],
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(child: greeting),
                  refresh,
                ],
              );
      },
    ),
  );

  Widget _metric(
    double width,
    String title,
    String value,
    IconData icon, {
    required bool loading,
    required bool error,
  }) {
    final shown = loading
        ? '…'
        : error
        ? 'No disponible'
        : value;
    return SizedBox(
      width: width,
      child: Container(
        constraints: const BoxConstraints(minHeight: 112),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _iconTile(icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contextMetric(
    double width,
    String title,
    String value,
    IconData icon,
  ) => SizedBox(
    width: width,
    child: Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _iconTile(icon),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
                const SizedBox(height: 5),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );

  Widget _iconTile(IconData icon) => Container(
    width: 44,
    height: 44,
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, color: AppColors.primary, size: 22),
  );

  Widget _parameters(BuildContext context) => _panel(
    title: 'Parámetros y métricas operativas',
    subtitle: institutionName,
    icon: Icons.tune_rounded,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _infoRow(
          Icons.insights_outlined,
          'Totales históricos',
          'Pacientes atendidos y dosis aplicadas',
          action: 'estadisticas',
          actionLabel: 'Ver estadísticas',
        ),
        const Divider(height: 28),
        _infoRow(
          Icons.today_outlined,
          'Actividad del día',
          'El resumen diario aún no está disponible en la API.',
        ),
        const Divider(height: 28),
        _infoRow(
          Icons.badge_outlined,
          'Personal en turno',
          'La disponibilidad del personal en tiempo real no está conectada.',
        ),
      ],
    ),
  );

  Widget _geography(BuildContext context) => _panel(
    title: 'Georreferenciación y cobertura',
    subtitle: 'Vista institucional',
    icon: Icons.map_outlined,
    child: Container(
      constraints: const BoxConstraints(minHeight: 220),
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: const BoxDecoration(
                  color: AppColors.primarySoft,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.location_on_outlined,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Mapa institucional no disponible',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'No hay coordenadas de sede ni puntos geográficos conectados. '
                'No se muestran ubicaciones de ejemplo.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.slate, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _panel({
    required String title,
    required String subtitle,
    required IconData icon,
    required Widget child,
  }) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _iconTile(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        child,
      ],
    ),
  );

  Widget _infoRow(
    IconData icon,
    String title,
    String detail, {
    String? action,
    String? actionLabel,
  }) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 20, color: AppColors.primary),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              detail,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
            if (action != null) ...[
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => onNavigate(action),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 36),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ],
  );

  Widget _quickAccess(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final actions = Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            _quickButton('Personal', Icons.people_outline, 'administracion'),
            _quickButton('Catálogo', Icons.vaccines_outlined, 'inventario'),
            _quickButton('Historial', Icons.history, 'historial'),
            _quickButton('Entregas', Icons.local_shipping_outlined, 'entregas'),
          ],
        );
        return compact
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Accesos directos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 10),
                  actions,
                ],
              )
            : Row(
                children: [
                  const Text(
                    'Accesos directos',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(child: actions),
                ],
              );
      },
    ),
  );

  Widget _quickButton(String label, IconData icon, String section) =>
      OutlinedButton.icon(
        onPressed: () => onNavigate(section),
        icon: Icon(icon, size: 18),
        label: Text(label),
      );
}
