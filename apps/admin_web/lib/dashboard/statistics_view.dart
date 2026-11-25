import 'package:flutter/material.dart';

import '../users/app_colors.dart';

/// Vista analítica con la estructura del módulo de Brayan. Solo presenta
/// cifras confirmadas por el endpoint de resumen; las series no se simulan.
class StatisticsView extends StatelessWidget {
  const StatisticsView({
    required this.institutionName,
    required this.metrics,
    required this.onRefresh,
    super.key,
  });

  final String institutionName;
  final Future<Map<String, dynamic>> metrics;
  final VoidCallback onRefresh;

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
                const SizedBox(height: 18),
                _sourceNotice(),
                const SizedBox(height: 20),
                FutureBuilder<Map<String, dynamic>>(
                  future: metrics,
                  builder: (context, snapshot) {
                    final loading =
                        snapshot.connectionState != ConnectionState.done;
                    final failed = snapshot.hasError;
                    final data = snapshot.data;
                    String value(String key) {
                      final number = data?[key];
                      return number is int && number >= 0 ? '$number' : '—';
                    }

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (failed)
                          Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.dangerSoft,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'No se pudieron consultar las métricas. Revisa la conexión y tus permisos.',
                                    style: TextStyle(color: AppColors.ink),
                                  ),
                                ),
                                TextButton(
                                  onPressed: onRefresh,
                                  child: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final columns = constraints.maxWidth >= 1050
                                ? 4
                                : constraints.maxWidth >= 600
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
                                  loading
                                      ? '…'
                                      : failed
                                      ? 'No disponible'
                                      : value('patientsAttended'),
                                  Icons.people_alt_outlined,
                                  verified: true,
                                ),
                                _metric(
                                  width,
                                  'Dosis aplicadas',
                                  loading
                                      ? '…'
                                      : failed
                                      ? 'No disponible'
                                      : value('dosesApplied'),
                                  Icons.vaccines_outlined,
                                  verified: true,
                                ),
                                _metric(
                                  width,
                                  'Cobertura PAI',
                                  'No disponible',
                                  Icons.pie_chart_outline_rounded,
                                ),
                                _metric(
                                  width,
                                  'Actividad por período',
                                  'No disponible',
                                  Icons.trending_up_rounded,
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 22),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final compact = constraints.maxWidth < 900;
                    final trend = _analysisPanel(
                      icon: Icons.show_chart_rounded,
                      title: 'Tendencias de vacunación',
                      description: 'El servicio solo entrega totales acumulados. No hay series por fecha para construir una tendencia real.',
                      detail: 'Fuente necesaria: resumen de dosis agrupado por día, semana o mes.',
                    );
                    final cohorts = _analysisPanel(
                      icon: Icons.donut_large_outlined,
                      title: 'Cobertura y población objetivo',
                      description: 'No se recibieron metas, denominadores ni clasificación de población para calcular coberturas.',
                      detail: 'Fuente necesaria: metas institucionales y población objetivo verificable.',
                    );
                    if (compact) {
                      return Column(
                        children: [trend, const SizedBox(height: 16), cohorts],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 3, child: trend),
                        const SizedBox(width: 16),
                        Expanded(flex: 2, child: cohorts),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                _productivityPanel(),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _header(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 760;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.analytics_rounded,
                      size: 15,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'MÓDULO ANALÍTICO',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: .45,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'PAI Colombia',
                style: TextStyle(fontSize: 12, color: AppColors.slate),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Estadísticas y Análisis Epidemiológico',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Resumen institucional · $institutionName',
            style: const TextStyle(color: AppColors.slate),
          ),
        ],
      );
      final refresh = OutlinedButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Actualizar indicadores'),
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Actualizar indicadores',
                      onPressed: onRefresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                Expanded(child: title),
                refresh,
              ],
            );
    },
  );

  Widget _sourceNotice() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      color: AppColors.primarySoft,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline_rounded, size: 19, color: AppColors.primary),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Los totales disponibles son históricos y acumulados. Los filtros por fechas, '
            'cobertura y productividad se habilitarán cuando el backend exponga esos datos.',
            style: TextStyle(color: AppColors.ink, height: 1.4),
          ),
        ),
      ],
    ),
  );

  Widget _metric(
    double width,
    String title,
    String value,
    IconData icon, {
    bool verified = false,
  }) => SizedBox(
    width: width,
    child: Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 20),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AppColors.slate, fontSize: 12),
                ),
              ),
              if (verified)
                const Tooltip(
                  message: 'Dato entregado por la API',
                  child: Icon(
                    Icons.verified_outlined,
                    size: 16,
                    color: AppColors.success,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: value.length > 12 ? 16 : 25,
              fontWeight: FontWeight.bold,
              color: verified ? AppColors.ink : AppColors.slate,
            ),
          ),
          if (!verified) ...[
            const SizedBox(height: 4),
            const Text(
              'Sin dato conectado',
              style: TextStyle(fontSize: 11, color: AppColors.slate),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _analysisPanel({
    required IconData icon,
    required String title,
    required String description,
    required String detail,
  }) => Container(
    constraints: const BoxConstraints(minHeight: 300),
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
            Icon(icon, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          constraints: const BoxConstraints(minHeight: 150),
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppColors.hint, size: 30),
                const SizedBox(height: 12),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.slate, height: 1.45),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          detail,
          style: const TextStyle(color: AppColors.slate, fontSize: 11),
        ),
      ],
    ),
  );

  Widget _productivityPanel() => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.badge_outlined, color: AppColors.primary, size: 22),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Productividad del personal',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'No se muestran rankings ni comparaciones: el resumen disponible no incluye '
                'actividad por profesional.',
                style: TextStyle(color: AppColors.slate, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        const Tooltip(
          message:
              'Pendiente de conexión con datos desglosados por profesional',
          child: Icon(Icons.info_outline_rounded, color: AppColors.hint),
        ),
      ],
    ),
  );
}
