import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../statistics_controller.dart';

/// Vista de escritorio (Web / Desktop) para el módulo de Estadísticas y Analítica PAI.
///
/// Maqueta de presentación con los indicadores epidemiológicos, gráficos de barras,
/// dona de distribución, barras de metas por cohorte y productividad de vacunadores.
/// No se encuentra conectada a microservicios en esta fase; sirve como base visual
/// y estructural para el desarrollo analítico posterior.
class AdminWebStatisticsView extends StatefulWidget {
  const AdminWebStatisticsView({
    super.key,
    required this.institutionName,
    this.onRefresh,
    this.statisticsController,
  });

  final String institutionName;
  final Future<void> Function()? onRefresh;
  final StatisticsController? statisticsController;

  @override
  State<AdminWebStatisticsView> createState() => _AdminWebStatisticsViewState();
}

class _AdminWebStatisticsViewState extends State<AdminWebStatisticsView> {
  String _selectedPeriod = 'Mes Actual';
  String _activeFilter = 'Todos los biológicos';
  int _selectedGranularity = 1; // 0: Días, 1: Semanas, 2: Meses
  int _chartVisualType = 1; // 0: Barras agrupadas, 1: Gráfico de líneas continuas / horizontal

  final List<String> _periods = [
    'Hoy',
    'Esta Semana',
    'Mes Actual',
    'Último Trimestre',
    'Año 2026',
  ];

  final List<String> _filters = [
    'Todos los biológicos',
    'Esquema Regular PAI',
    'Campañas Especiales',
    'Población Prioritaria',
    'Jornadas Extramurales',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: widget.onRefresh ?? () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Cabecera principal
                  _buildHeader(context),
                  const SizedBox(height: 20),

                  // 2. Banner de prototipado / Roadmap
                  _buildRoadmapBanner(),
                  const SizedBox(height: 24),

                  // 3. Fila de 4 KPIs consolidados
                  _buildKpiRow(),
                  const SizedBox(height: 24),

                  // 4. Barra de filtros interactivos
                  _buildFilterBar(),
                  const SizedBox(height: 24),

                  // 5. Bloque Gráfico Panorámico (2 Columnas)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isStacked = constraints.maxWidth < 1000;
                      if (isStacked) {
                        return Column(
                          children: [
                            _buildBarChartCard(),
                            const SizedBox(height: 24),
                            _buildDonutChartCard(),
                            const SizedBox(height: 24),
                            _buildCohortsCard(),
                            const SizedBox(height: 24),
                            _buildVaccinatorsProductivityCard(),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 3, child: _buildBarChartCard()),
                              const SizedBox(width: 24),
                              Expanded(flex: 2, child: _buildDonutChartCard()),
                            ],
                          ),
                          const SizedBox(height: 24),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(flex: 1, child: _buildCohortsCard()),
                              const SizedBox(width: 24),
                              Expanded(
                                flex: 1,
                                child: _buildVaccinatorsProductivityCard(),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 24),

                  // 6. Tarjetas de Observaciones y Alertas Analíticas
                  _buildEpidemiologicalInsightsCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Cabecera
  // ---------------------------------------------------------------------------
  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.analytics_rounded,
                          size: 14,
                          color: AppColors.primary,
                        ),
                        SizedBox(width: 5),
                        Text(
                          'MÓDULO ANALÍTICO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'PAI Colombia',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Estadísticas y Análisis Epidemiológico',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Monitoreo consolidado de cobertura, rendimiento de biológicos y ritmo de vacunación institucional · ${widget.institutionName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.slate,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Acciones a la derecha
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Selector de período
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedPeriod,
                  icon: const Icon(
                    Icons.calendar_today_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.ink,
                  ),
                  items: _periods.map((period) {
                    return DropdownMenuItem<String>(
                      value: period,
                      child: Text(period),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedPeriod = val);
                  },
                ),
              ),
            ),
            // Botón de exportación
            OutlinedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Exportación de reporte estadístico en preparación.',
                    ),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
              icon: const Icon(Icons.file_download_outlined, size: 18),
              label: const Text('Exportar Reporte'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                backgroundColor: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 2. Banner de prototipado / Roadmap
  // ---------------------------------------------------------------------------
  Widget _buildRoadmapBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primarySoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.auto_graph_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Módulo en fase de estructuración visual (Previsualización PAI)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Este panel presenta la maqueta base con los indicadores y gráficos que integrará la institución. La vinculación analítica en tiempo real se completará en la siguiente fase de desarrollo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.slate,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 3. Fila de KPIs
  // ---------------------------------------------------------------------------
  Widget _buildKpiRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 1000;

        if (isMobile) {
          return Column(
            children: [
              _buildKpiCard(
                title: 'Cobertura PAI Global',
                value: '89.4%',
                badge: '+2.3% vs anterior',
                badgeColor: AppColors.success,
                icon: Icons.pie_chart_rounded,
                iconColor: AppColors.primary,
                description: 'Meta nacional: ≥ 95.0%',
                progress: 0.894,
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Dosis Aplicadas en Período',
                value: '1,842',
                badge: '48.5 prom/día',
                badgeColor: Colors.indigo,
                icon: Icons.vaccines_rounded,
                iconColor: Colors.indigo,
                description: 'Registradas en la institución',
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Población Meta Cubierta',
                value: '1,420',
                badge: '84% cohorte infantil',
                badgeColor: AppColors.success,
                icon: Icons.groups_rounded,
                iconColor: AppColors.success,
                description: 'Menores de 5 años y gestantes',
              ),
              const SizedBox(height: 12),
              _buildKpiCard(
                title: 'Tasa de Pérdida / Merma',
                value: '1.4%',
                badge: 'Controlado',
                badgeColor: Colors.teal,
                icon: Icons.verified_user_outlined,
                iconColor: Colors.teal,
                description: 'Límite aceptable OMS: ≤ 5.0%',
                progress: 0.014 / 0.05,
              ),
            ],
          );
        }

        if (isTablet) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Cobertura PAI Global',
                      value: '89.4%',
                      badge: '+2.3% vs anterior',
                      badgeColor: AppColors.success,
                      icon: Icons.pie_chart_rounded,
                      iconColor: AppColors.primary,
                      description: 'Meta nacional: ≥ 95.0%',
                      progress: 0.894,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Dosis Aplicadas en Período',
                      value: '1,842',
                      badge: '48.5 prom/día',
                      badgeColor: Colors.indigo,
                      icon: Icons.vaccines_rounded,
                      iconColor: Colors.indigo,
                      description: 'Registradas en la institución',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Población Meta Cubierta',
                      value: '1,420',
                      badge: '84% cohorte infantil',
                      badgeColor: AppColors.success,
                      icon: Icons.groups_rounded,
                      iconColor: AppColors.success,
                      description: 'Menores de 5 años y gestantes',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: _buildKpiCard(
                      title: 'Tasa de Pérdida / Merma',
                      value: '1.4%',
                      badge: 'Controlado',
                      badgeColor: Colors.teal,
                      icon: Icons.verified_user_outlined,
                      iconColor: Colors.teal,
                      description: 'Límite aceptable OMS: ≤ 5.0%',
                      progress: 0.014 / 0.05,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _buildKpiCard(
                title: 'Cobertura PAI Global',
                value: '89.4%',
                badge: '+2.3% vs ant.',
                badgeColor: AppColors.success,
                icon: Icons.pie_chart_rounded,
                iconColor: AppColors.primary,
                description: 'Meta nacional: ≥ 95.0%',
                progress: 0.894,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Dosis Aplicadas (Período)',
                value: '1,842',
                badge: '48.5 prom/día',
                badgeColor: Colors.indigo,
                icon: Icons.vaccines_rounded,
                iconColor: Colors.indigo,
                description: 'Total acumulado en IPS',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Población Meta Atendida',
                value: '1,420',
                badge: '84% infantil',
                badgeColor: AppColors.success,
                icon: Icons.groups_rounded,
                iconColor: AppColors.success,
                description: 'Pacientes con carné al día',
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildKpiCard(
                title: 'Tasa de Pérdida / Merma',
                value: '1.4%',
                badge: 'Óptimo',
                badgeColor: Colors.teal,
                icon: Icons.verified_user_outlined,
                iconColor: Colors.teal,
                description: 'Límite aceptable OMS: ≤ 5%',
                progress: 0.014 / 0.05,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String badge,
    required Color badgeColor,
    required IconData icon,
    required Color iconColor,
    required String description,
    double? progress,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.slate,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: AppColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(iconColor),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 4. Barra de filtros interactivos
  // ---------------------------------------------------------------------------
  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.filter_alt_outlined,
            size: 18,
            color: AppColors.slate,
          ),
          const SizedBox(width: 8),
          const Text(
            'Filtrar análisis:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.slate,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _filters.map((filter) {
                  final isSelected = _activeFilter == filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(
                        filter,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              isSelected ? FontWeight.bold : FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.ink,
                        ),
                      ),
                      selected: isSelected,
                      selectedColor: AppColors.primary,
                      backgroundColor: AppColors.background,
                      side: BorderSide(
                        color:
                            isSelected ? AppColors.primary : AppColors.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _activeFilter = filter);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Card A: Gráfico de Evolución y Tendencia (Barras y Líneas)
  // ---------------------------------------------------------------------------
  Widget _buildBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 10,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chartVisualType == 1
                        ? 'Tendencia y Curva de Dosis Aplicadas'
                        : 'Ritmo y Evolución de Dosis Aplicadas',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _chartVisualType == 1
                        ? 'Comportamiento continuo y progresión temporal de vacunación'
                        : 'Distribución comparativa de aplicación según temporalidad',
                    style: const TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Selector visual: Línea vs Barras
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildChartTypeButton(
                          icon: Icons.show_chart_rounded,
                          tooltip: 'Ver gráfico de líneas continuas',
                          index: 1,
                        ),
                        _buildChartTypeButton(
                          icon: Icons.bar_chart_rounded,
                          tooltip: 'Ver gráfico de barras',
                          index: 0,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Selector de granularidad temporal
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildGranularityButton('Días', 0),
                        _buildGranularityButton('Semanas', 1),
                        _buildGranularityButton('Meses', 2),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Gráfico visual dinámico (Líneas o Barras)
          SizedBox(
            height: 220,
            child: _chartVisualType == 1
                ? _buildLineChartGraphic()
                : _buildBarChartGraphic(),
          ),
          const SizedBox(height: 16),

          // Leyenda contextual
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 20,
            runSpacing: 8,
            children: [
              _buildLegendItem(
                color: AppColors.primary,
                label: 'Esquema Regular PAI',
                isLine: _chartVisualType == 1,
              ),
              _buildLegendItem(
                color: const Color(0xFF00B4D8),
                label: 'Campañas y Refuerzos',
                isLine: _chartVisualType == 1,
              ),
              if (_chartVisualType == 1)
                _buildLegendItem(
                  color: const Color(0xFFF59E0B),
                  label: 'Línea Guía Promedio',
                  isDashed: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChartTypeButton({
    required IconData icon,
    required String tooltip,
    required int index,
  }) {
    final isSelected = _chartVisualType == index;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: () => setState(() => _chartVisualType = index),
        borderRadius: BorderRadius.circular(7),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            icon,
            size: 16,
            color: isSelected ? AppColors.primary : AppColors.slate,
          ),
        ),
      ),
    );
  }

  Widget _buildGranularityButton(String label, int index) {
    final isSelected = _selectedGranularity == index;
    return InkWell(
      onTap: () => setState(() => _selectedGranularity = index),
      borderRadius: BorderRadius.circular(7),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? AppColors.primary : AppColors.slate,
          ),
        ),
      ),
    );
  }

  Widget _buildLineChartGraphic() {
    // Datos de muestra según granularidad
    final labels = _selectedGranularity == 0
        ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
        : (_selectedGranularity == 1
            ? ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4', 'Sem 5', 'Sem 6', 'Sem 7', 'Sem 8']
            : ['Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov']);

    final values1 = _selectedGranularity == 0
        ? [42, 58, 65, 48, 72, 38, 12]
        : (_selectedGranularity == 1
            ? [190, 240, 215, 275, 230, 290, 260, 242]
            : [850, 920, 1050, 980, 1140, 1260]);

    final values2 = _selectedGranularity == 0
        ? [15, 22, 28, 18, 30, 14, 4]
        : (_selectedGranularity == 1
            ? [50, 75, 60, 85, 70, 95, 80, 70]
            : [240, 280, 310, 290, 350, 380]);

    final maxValue = (_selectedGranularity == 0
            ? 100
            : (_selectedGranularity == 1 ? 400 : 1800))
        .toDouble();

    final avg1 = values1.reduce((a, b) => a + b) / values1.length;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Eje Y con líneas de referencia
        SizedBox(
          height: 195,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                maxValue.toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.hint),
              ),
              Text(
                (maxValue * 0.66).toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.hint),
              ),
              Text(
                (maxValue * 0.33).toInt().toString(),
                style: const TextStyle(fontSize: 10, color: AppColors.hint),
              ),
              const Text(
                '0',
                style: TextStyle(fontSize: 10, color: AppColors.hint),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Lienzo interactivo de líneas continuas
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const leftInset = 20.0;
              const rightInset = 20.0;
              const topInset = 12.0;
              const bottomInset = 28.0;
              final chartWidth = constraints.maxWidth;
              final chartHeight = constraints.maxHeight;
              final plotHeight = chartHeight - bottomInset - topInset;
              final plotWidth = chartWidth - leftInset - rightInset;

              final points1 = <Offset>[];
              final points2 = <Offset>[];
              final n = labels.length;

              for (int i = 0; i < n; i++) {
                final x = leftInset +
                    (n > 1 ? (plotWidth * i / (n - 1)) : (plotWidth / 2));
                final y1 = topInset +
                    (1.0 - (values1[i] / maxValue).clamp(0.0, 1.0)) * plotHeight;
                final y2 = topInset +
                    (1.0 - (values2[i] / maxValue).clamp(0.0, 1.0)) * plotHeight;
                points1.add(Offset(x, y1));
                points2.add(Offset(x, y2));
              }

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  CustomPaint(
                    size: Size(chartWidth, chartHeight),
                    painter: _LineChartPainter(
                      labels: labels,
                      values1: values1,
                      values2: values2,
                      maxValue: maxValue,
                      averageValue: avg1,
                      leftInset: leftInset,
                      rightInset: rightInset,
                      topInset: topInset,
                      bottomInset: bottomInset,
                      color1: AppColors.primary,
                      color2: const Color(0xFF00B4D8),
                    ),
                  ),

                  // Nodos interactivos con Tooltips para Regular
                  for (int i = 0; i < n; i++)
                    Positioned(
                      left: points1[i].dx - 14,
                      top: points1[i].dy - 14,
                      child: Tooltip(
                        message: '${labels[i]}: ${values1[i]} dosis (Regular PAI)',
                        child: Container(
                          width: 28,
                          height: 28,
                          color: Colors.transparent,
                        ),
                      ),
                    ),

                  // Nodos interactivos con Tooltips para Campañas
                  for (int i = 0; i < n; i++)
                    Positioned(
                      left: points2[i].dx - 14,
                      top: points2[i].dy - 14,
                      child: Tooltip(
                        message: '${labels[i]}: ${values2[i]} dosis (Campañas)',
                        child: Container(
                          width: 28,
                          height: 28,
                          color: Colors.transparent,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBarChartGraphic() {
    // Datos de muestra según granularidad
    final labels = _selectedGranularity == 0
        ? ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom']
        : (_selectedGranularity == 1
            ? ['Sem 1', 'Sem 2', 'Sem 3', 'Sem 4', 'Sem 5', 'Sem 6', 'Sem 7', 'Sem 8']
            : ['Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov']);

    final values1 = _selectedGranularity == 0
        ? [42, 58, 65, 48, 72, 38, 12]
        : (_selectedGranularity == 1
            ? [190, 240, 215, 275, 230, 290, 260, 242]
            : [850, 920, 1050, 980, 1140, 1260]);

    final values2 = _selectedGranularity == 0
        ? [15, 22, 28, 18, 30, 14, 4]
        : (_selectedGranularity == 1
            ? [50, 75, 60, 85, 70, 95, 80, 70]
            : [240, 280, 310, 290, 350, 380]);

    final maxValue = (_selectedGranularity == 0 ? 100 : (_selectedGranularity == 1 ? 400 : 1800)).toDouble();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Eje Y con líneas de referencia
        Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              maxValue.toInt().toString(),
              style: const TextStyle(fontSize: 10, color: AppColors.hint),
            ),
            Text(
              (maxValue * 0.66).toInt().toString(),
              style: const TextStyle(fontSize: 10, color: AppColors.hint),
            ),
            Text(
              (maxValue * 0.33).toInt().toString(),
              style: const TextStyle(fontSize: 10, color: AppColors.hint),
            ),
            const Text(
              '0',
              style: TextStyle(fontSize: 10, color: AppColors.hint),
            ),
          ],
        ),
        const SizedBox(width: 8),

        // Barras agrupadas
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(labels.length, (i) {
              final val1 = values1[i];
              final val2 = values2[i];
              final height1 = (val1 / maxValue) * 190;
              final height2 = (val2 / maxValue) * 190;

              return Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Tooltip(
                        message: 'Regular: $val1 dosis',
                        child: Container(
                          width: 14,
                          height: height1.clamp(4.0, 190.0),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 3),
                      Tooltip(
                        message: 'Campañas: $val2 dosis',
                        child: Container(
                          width: 14,
                          height: height2.clamp(4.0, 190.0),
                          decoration: const BoxDecoration(
                            color: Color(0xFF00B4D8),
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    labels[i],
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.slate,
                    ),
                  ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem({
    required Color color,
    required String label,
    bool isLine = false,
    bool isDashed = false,
  }) {
    Widget indicator;
    if (isDashed) {
      indicator = SizedBox(
        width: 16,
        height: 10,
        child: Center(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      );
    } else if (isLine) {
      indicator = SizedBox(
        width: 16,
        height: 10,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              height: 2.5,
              color: color,
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
            ),
          ],
        ),
      );
    } else {
      indicator = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        indicator,
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: AppColors.slate,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Card B: Gráfico de Dona / Distribución por Biológico
  // ---------------------------------------------------------------------------
  Widget _buildDonutChartCard() {
    final sections = [
      _ChartSection(label: 'Pentavalente', percentage: 0.28, color: AppColors.primary, count: '516 dosis'),
      _ChartSection(label: 'Influenza Estacional', percentage: 0.22, color: const Color(0xFF00B4D8), count: '405 dosis'),
      _ChartSection(label: 'Polio (VIP / VOP)', percentage: 0.18, color: const Color(0xFF48CAE4), count: '331 dosis'),
      _ChartSection(label: 'Triple Viral (SRP)', percentage: 0.17, color: const Color(0xFF90E0EF), count: '313 dosis'),
      _ChartSection(label: 'Otras Vacunas PAI', percentage: 0.15, color: const Color(0xFFADE8F4), count: '277 dosis'),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Distribución por Biológico',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Proporción de aplicación según antígeno administrado',
            style: TextStyle(fontSize: 12, color: AppColors.slate),
          ),
          const SizedBox(height: 20),

          // Dona + Leyenda
          Row(
            children: [
              // Visual de la Dona
              SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(140, 140),
                      painter: _DonutChartPainter(sections: sections),
                    ),
                    const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '1,842',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          'Total Dosis',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Lista de biológicos
              Expanded(
                child: Column(
                  children: sections.map((s) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: s.color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.label,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: AppColors.ink,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(s.percentage * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Biológico con mayor demanda:',
                style: TextStyle(fontSize: 11, color: AppColors.slate),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Pentavalente (28%)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Card C: Metas por Cohorte de Edad
  // ---------------------------------------------------------------------------
  Widget _buildCohortsCard() {
    final cohorts = [
      _CohortMetric(label: 'Recién Nacidos (< 28 días)', subtitle: 'BCG, Hepatitis B Pediátrica', coverage: 0.96, target: 0.95, color: AppColors.success),
      _CohortMetric(label: 'Menores de 1 año (2, 4, 6 y 7 meses)', subtitle: 'Polio, Pentavalente, Rotavirus, Neumococo', coverage: 0.91, target: 0.95, color: AppColors.primary),
      _CohortMetric(label: 'Niños de 1 año (12 meses)', subtitle: 'Triple Viral (SRP), Fiebre Amarilla, Varicela', coverage: 0.88, target: 0.95, color: AppColors.primary),
      _CohortMetric(label: 'Refuerzos 18 meses', subtitle: 'DPT 1er Refuerzo, Polio Oral, Fiebre Amarilla', coverage: 0.84, target: 0.90, color: const Color(0xFFF59E0B)),
      _CohortMetric(label: 'Refuerzos 5 años', subtitle: 'DPT 2do Refuerzo, Polio Oral, SRP Refuerzo', coverage: 0.79, target: 0.90, color: const Color(0xFFF59E0B)),
      _CohortMetric(label: 'Gestantes y Adulto Mayor', subtitle: 'Tdap, Influenza Estacional, Neumococo', coverage: 0.93, target: 0.90, color: AppColors.success),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cobertura por Grupos Etarios (Metas PAI)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Cumplimiento frente a la meta nacional de cobertura',
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Text(
                  'Meta Nacional: ≥ 95%',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.slate,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          for (final c in cohorts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          c.label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.ink,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${(c.coverage * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: c.color,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        c.subtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.slate,
                        ),
                      ),
                      Text(
                        'Meta: ${(c.target * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.hint,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: c.coverage,
                      minHeight: 7,
                      backgroundColor: AppColors.background,
                      valueColor: AlwaysStoppedAnimation<Color>(c.color),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 5. Card D: Productividad de Vacunadores
  // ---------------------------------------------------------------------------
  Widget _buildVaccinatorsProductivityCard() {
    final vaccinators = [
      _VaccinatorPerf(name: 'Enf. Carlos Méndez', role: 'Enfermero Jefe', doses: 512, avgTime: '7.8 min', syncRate: '99.4%', avatarColor: Colors.blue),
      _VaccinatorPerf(name: 'Aux. Laura Restrepo', role: 'Auxiliar de Vacunación', doses: 478, avgTime: '8.2 min', syncRate: '98.9%', avatarColor: Colors.purple),
      _VaccinatorPerf(name: 'Enf. Andrea Gómez', role: 'Enfermera Asistencial', doses: 436, avgTime: '7.5 min', syncRate: '99.1%', avatarColor: Colors.teal),
      _VaccinatorPerf(name: 'Aux. Mateo Beltrán', role: 'Auxiliar de Enfermería', doses: 416, avgTime: '8.9 min', syncRate: '97.8%', avatarColor: Colors.amber),
    ];

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Productividad del Equipo de Vacunación',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Rendimiento operativo, registro y tiempos promedio',
                    style: TextStyle(fontSize: 12, color: AppColors.slate),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  '4 Activos',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.success,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          for (final v in vaccinators) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: v.avatarColor.withValues(alpha: 0.15),
                    child: Text(
                      v.name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: v.avatarColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                        Text(
                          v.role,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.slate,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${v.doses} dosis',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${v.avgTime} · Sinc: ${v.syncRate}',
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 6. Alertas y Proyecciones Epidemiológicas
  // ---------------------------------------------------------------------------
  Widget _buildEpidemiologicalInsightsCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFF59E0B), size: 20),
              SizedBox(width: 8),
              Text(
                'Observaciones y Alertas Epidemiológicas Generadas',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final isStacked = constraints.maxWidth < 900;
              if (isStacked) {
                return Column(
                  children: [
                    _buildInsightPill(
                      title: 'Oportunidad de Vacunación',
                      description: 'El 92% de los esquemas se completaron dentro del mes correspondiente a la cita programada.',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                    const SizedBox(height: 10),
                    _buildInsightPill(
                      title: 'Alerta de Cobertura en Refuerzo de 5 Años',
                      description: 'Presenta un rezago de 11% frente a la meta esperada. Se sugiere contactar a los padres vía recordatorio PAI.',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(height: 10),
                    _buildInsightPill(
                      title: 'Proyección de Consumo Pentavalente',
                      description: 'Al ritmo actual (28% del total aplicado), se proyecta agotar el lote de contingencia en 16 días hábiles.',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.primary,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _buildInsightPill(
                      title: 'Oportunidad de Vacunación',
                      description: 'El 92% de los esquemas se completaron dentro del mes de la cita.',
                      icon: Icons.check_circle_outline_rounded,
                      color: AppColors.success,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInsightPill(
                      title: 'Alerta Cobertura Refuerzo 5 Años',
                      description: 'Rezago del 11% frente a la meta. Se sugiere programar jornadas de refuerzo.',
                      icon: Icons.warning_amber_rounded,
                      color: const Color(0xFFF59E0B),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _buildInsightPill(
                      title: 'Proyección Pentavalente',
                      description: 'Al ritmo actual, se proyecta reposición de inventario en 16 días hábiles.',
                      icon: Icons.trending_up_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildInsightPill({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.slate,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Clases auxiliares y Custom Painter para la Dona
// -----------------------------------------------------------------------------

class _ChartSection {
  const _ChartSection({
    required this.label,
    required this.percentage,
    required this.color,
    required this.count,
  });

  final String label;
  final double percentage;
  final Color color;
  final String count;
}

class _CohortMetric {
  const _CohortMetric({
    required this.label,
    required this.subtitle,
    required this.coverage,
    required this.target,
    required this.color,
  });

  final String label;
  final String subtitle;
  final double coverage;
  final double target;
  final Color color;
}

class _VaccinatorPerf {
  const _VaccinatorPerf({
    required this.name,
    required this.role,
    required this.doses,
    required this.avgTime,
    required this.syncRate,
    required this.avatarColor,
  });

  final String name;
  final String role;
  final int doses;
  final String avgTime;
  final String syncRate;
  final Color avatarColor;
}

class _DonutChartPainter extends CustomPainter {
  _DonutChartPainter({required this.sections});
  final List<_ChartSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final strokeWidth = radius * 0.34;
    final rect = Rect.fromCircle(
      center: center,
      radius: radius - (strokeWidth / 2),
    );

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;

    double startAngle = -math.pi / 2;
    for (final section in sections) {
      final sweepAngle = 2 * math.pi * section.percentage;
      paint.color = section.color;
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) => true;
}

/// CustomPainter para graficar curvas de tendencia temporal (Spline / Bezier)
/// con áreas sombreadas en gradiente, línea guía promedio horizontal,
/// cuadrícula de fondo y nodos marcadores de datos.
class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.labels,
    required this.values1,
    required this.values2,
    required this.maxValue,
    required this.averageValue,
    required this.leftInset,
    required this.rightInset,
    required this.topInset,
    required this.bottomInset,
    required this.color1,
    required this.color2,
  });

  final List<String> labels;
  final List<int> values1;
  final List<int> values2;
  final double maxValue;
  final double averageValue;
  final double leftInset;
  final double rightInset;
  final double topInset;
  final double bottomInset;
  final Color color1;
  final Color color2;

  @override
  void paint(Canvas canvas, Size size) {
    final plotWidth = size.width - leftInset - rightInset;
    final plotHeight = size.height - topInset - bottomInset;
    final baselineY = topInset + plotHeight;
    final n = labels.length;

    // 1. Líneas de cuadrícula horizontales
    final gridPaint = Paint()
      ..color = AppColors.border.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;

    for (int step = 0; step <= 3; step++) {
      final y = topInset + (plotHeight * step / 3);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // 2. Línea horizontal de referencia para el Promedio
    if (averageValue > 0 && averageValue <= maxValue) {
      final avgY = topInset + (1.0 - (averageValue / maxValue)) * plotHeight;
      final avgPaint = Paint()
        ..color = const Color(0xFFF59E0B).withValues(alpha: 0.7)
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;

      // Línea punteada
      const dashWidth = 5.0;
      const dashSpace = 4.0;
      double startX = 0;
      while (startX < size.width) {
        canvas.drawLine(
          Offset(startX, avgY),
          Offset(math.min(startX + dashWidth, size.width), avgY),
          avgPaint,
        );
        startX += dashWidth + dashSpace;
      }

      // Etiqueta de promedio
      final textSpan = TextSpan(
        text: 'Promedio: ${averageValue.toInt()}',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: Color(0xFFD97706),
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 4, avgY - 14),
      );
    }

    // Calcular coordenadas de puntos
    final pts1 = <Offset>[];
    final pts2 = <Offset>[];
    for (int i = 0; i < n; i++) {
      final x = leftInset +
          (n > 1 ? (plotWidth * i / (n - 1)) : (plotWidth / 2));
      final y1 = topInset +
          (1.0 - (values1[i] / maxValue).clamp(0.0, 1.0)) * plotHeight;
      final y2 = topInset +
          (1.0 - (values2[i] / maxValue).clamp(0.0, 1.0)) * plotHeight;
      pts1.add(Offset(x, y1));
      pts2.add(Offset(x, y2));
    }

    // 3. Dibujar Serie 2 (Campañas y Refuerzos)
    _drawSplineSeries(
      canvas: canvas,
      pts: pts2,
      baselineY: baselineY,
      color: color2,
      size: size,
      drawGradient: true,
    );

    // 4. Dibujar Serie 1 (Esquema Regular PAI)
    _drawSplineSeries(
      canvas: canvas,
      pts: pts1,
      baselineY: baselineY,
      color: color1,
      size: size,
      drawGradient: true,
    );

    // 5. Dibujar etiquetas del Eje X
    for (int i = 0; i < n; i++) {
      final textSpan = TextSpan(
        text: labels[i],
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: AppColors.slate,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();

      final x = pts1[i].dx - (textPainter.width / 2);
      final y = baselineY + 8;
      textPainter.paint(canvas, Offset(x, y));
    }
  }

  void _drawSplineSeries({
    required Canvas canvas,
    required List<Offset> pts,
    required double baselineY,
    required Color color,
    required Size size,
    required bool drawGradient,
  }) {
    if (pts.isEmpty) return;

    final path = Path();
    path.moveTo(pts[0].dx, pts[0].dy);

    for (int i = 0; i < pts.length - 1; i++) {
      final p0 = pts[i];
      final p1 = pts[i + 1];
      final midX = (p0.dx + p1.dx) / 2;
      path.cubicTo(midX, p0.dy, midX, p1.dy, p1.dx, p1.dy);
    }

    // Área bajo la curva con gradiente
    if (drawGradient) {
      final fillPath = Path.from(path)
        ..lineTo(pts.last.dx, baselineY)
        ..lineTo(pts.first.dx, baselineY)
        ..close();

      final gradientPaint = Paint()
        ..style = PaintingStyle.fill
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.22),
            color.withValues(alpha: 0.01),
          ],
        ).createShader(
          Rect.fromLTWH(0, topInset, size.width, baselineY - topInset),
        );

      canvas.drawPath(fillPath, gradientPaint);
    }

    // Línea de trazo suave
    final strokePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, strokePaint);

    // Puntos / Nodos marcadores
    final pointBgPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final pointBorderPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final innerDotPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (final pt in pts) {
      canvas.drawCircle(pt, 4.5, pointBgPaint);
      canvas.drawCircle(pt, 4.5, pointBorderPaint);
      canvas.drawCircle(pt, 2.0, innerDotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
