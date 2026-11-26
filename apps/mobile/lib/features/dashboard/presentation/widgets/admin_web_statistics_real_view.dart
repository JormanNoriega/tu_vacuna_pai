import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/statistics_dashboard.dart';
import '../statistics_controller.dart';

class AdminWebStatisticsRealView extends StatefulWidget {
  const AdminWebStatisticsRealView({
    super.key,
    required this.institutionName,
    required this.offline,
    this.controller,
    this.onRefresh,
  });

  final String institutionName;
  final bool offline;
  final StatisticsController? controller;
  final Future<void> Function()? onRefresh;

  @override
  State<AdminWebStatisticsRealView> createState() =>
      _AdminWebStatisticsRealViewState();
}

class _AdminWebStatisticsRealViewState
    extends State<AdminWebStatisticsRealView> {
  String _period = 'Mes actual';
  String _granularity = 'day';
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    widget.controller?.addListener(_changed);
    unawaited(_load());
  }

  @override
  void didUpdateWidget(AdminWebStatisticsRealView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_changed);
      widget.controller?.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  ({DateTime from, DateTime to}) _range() {
    final now = DateTime.now().toUtc();
    switch (_period) {
      case 'Hoy':
        final start = DateTime.utc(now.year, now.month, now.day);
        return (from: start, to: start.add(const Duration(days: 1)));
      case 'Esta semana':
        final start = DateTime.utc(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return (from: start, to: start.add(const Duration(days: 7)));
      case 'Ultimo trimestre':
        return (
          from: DateTime.utc(now.year, now.month - 3, 1),
          to: DateTime.utc(now.year, now.month + 1, 1),
        );
      case 'Este año':
        return (
          from: DateTime.utc(now.year, 1, 1),
          to: DateTime.utc(now.year + 1, 1, 1),
        );
      default:
        return (
          from: DateTime.utc(now.year, now.month, 1),
          to: DateTime.utc(now.year, now.month + 1, 1),
        );
    }
  }

  Future<void> _load() async {
    final controller = widget.controller;
    if (controller == null) return;
    final range = _range();
    await controller.load(
      from: range.from,
      to: range.to,
      granularity: _granularity,
      offline: widget.offline,
    );
  }

  Future<void> _refresh() async {
    await widget.onRefresh?.call();
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final dashboard = controller?.dashboard ?? StatisticsDashboard.empty();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(controller),
                  const SizedBox(height: 20),
                  _status(controller, dashboard),
                  const SizedBox(height: 20),
                  _kpis(dashboard),
                  const SizedBox(height: 24),
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth < 1000) {
                      return Column(children: [
                        _series(dashboard),
                        const SizedBox(height: 24),
                        _vaccines(dashboard),
                        const SizedBox(height: 24),
                        _productivity(dashboard),
                      ]);
                    }
                    return Column(children: [
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(flex: 3, child: _series(dashboard)),
                        const SizedBox(width: 24),
                        Expanded(flex: 2, child: _vaccines(dashboard)),
                      ]),
                      const SizedBox(height: 24),
                      _productivity(dashboard),
                    ]);
                  }),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(StatisticsController? controller) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ESTADISTICAS PAI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.primary)),
        const SizedBox(height: 8),
        const Text('Estadisticas operativas reales', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 4),
        Text('Dosis, pacientes y vacunadores · ${widget.institutionName}', style: const TextStyle(fontSize: 13, color: AppColors.slate)),
      ])),
      const SizedBox(width: 16),
      Wrap(spacing: 10, runSpacing: 8, children: [
        _periodSelector(),
        _granularitySelector(),
        IconButton.filledTonal(
          tooltip: 'Actualizar',
          onPressed: controller == null || controller.isLoading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ]),
    ]);
  }

  Widget _periodSelector() {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: DropdownButtonHideUnderline(child: DropdownButton<String>(
        value: _period,
        items: const ['Hoy', 'Esta semana', 'Mes actual', 'Ultimo trimestre', 'Este año']
            .map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
        onChanged: (value) {
          if (value == null) return;
          setState(() => _period = value);
          unawaited(_load());
        },
      )),
    );
  }

  Widget _granularitySelector() {
    return SegmentedButton<String>(
      segments: const [
        ButtonSegment(value: 'day', label: Text('Dias')),
        ButtonSegment(value: 'week', label: Text('Semanas')),
        ButtonSegment(value: 'month', label: Text('Meses')),
      ],
      selected: {_granularity},
      onSelectionChanged: (values) {
        setState(() => _granularity = values.first);
        unawaited(_load());
      },
    );
  }

  Widget _status(StatisticsController? controller, StatisticsDashboard dashboard) {
    if (controller?.isLoading == true) return const LinearProgressIndicator(minHeight: 3);
    if (controller?.error != null) {
      return _notice(Icons.cloud_off_rounded, 'Error al cargar', controller!.error!, AppColors.danger);
    }
    if (!dashboard.hasData) {
      return _notice(Icons.bar_chart_rounded, 'Sin datos', 'No hay dosis registradas en el periodo seleccionado.', AppColors.slate);
    }
    if (dashboard.source == 'cache') {
      return _notice(Icons.offline_bolt_rounded, 'Datos locales', 'Ultima respuesta cacheada disponible sin conexion.', AppColors.warning);
    }
    final generated = dashboard.generatedAt;
    final detail = generated == null
        ? 'Datos recibidos del servidor.'
        : 'Actualizado ${generated.toLocal().toString().substring(0, 16)}.';
    return _notice(Icons.cloud_done_rounded, 'Datos reales', detail, AppColors.success);
  }

  Widget _notice(IconData icon, String title, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.22))),
      child: Row(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 8),
        Expanded(child: Text(detail, style: const TextStyle(fontSize: 12, color: AppColors.slate))),
      ]),
    );
  }

  Widget _kpis(StatisticsDashboard dashboard) {
    final items = <(String, String, IconData, Color)>[
      ('Dosis aplicadas', dashboard.dosesApplied.toString(), Icons.vaccines_rounded, AppColors.primary),
      ('Pacientes unicos', dashboard.uniquePatients.toString(), Icons.groups_rounded, AppColors.success),
      ('Dosis por paciente', dashboard.dosesPerPatient.toString(), Icons.analytics_rounded, Colors.indigo),
      ('Vacunadores activos', dashboard.activeVaccinators.toString(), Icons.badge_rounded, Colors.teal),
    ];
    return LayoutBuilder(builder: (context, constraints) {
      final columns = constraints.maxWidth >= 1100 ? 4 : constraints.maxWidth >= 620 ? 2 : 1;
      final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
      return Wrap(spacing: 16, runSpacing: 16, children: items.map((item) {
        return SizedBox(width: width, child: Container(
          height: 120,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(item.$3, color: item.$4, size: 20),
              const SizedBox(width: 8),
              Expanded(child: Text(item.$1, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate))),
            ]),
            const Spacer(),
            Text(item.$2, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: AppColors.ink)),
          ]),
        ));
      }).toList());
    });
  }

  Widget _series(StatisticsDashboard dashboard) {
    final points = dashboard.doseSeries;
    final maxValue = points.isEmpty
        ? 1
        : points
            .map((point) => point.doses)
            .reduce((a, b) => a > b ? a : b)
            .clamp(1, 999999999);

    return _card(
      'Evolucion de dosis aplicadas',
      'Dosis registradas por periodo',
      points.isEmpty
          ? const Center(
              child: Text(
                'Sin serie temporal',
                style: TextStyle(color: AppColors.slate),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = points.length > 12
                    ? points.length * 64.0
                    : constraints.maxWidth;

                final chart = SizedBox(
                  width: chartWidth,
                  height: constraints.maxHeight,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: points.map((point) {
                      final proportion = point.doses / maxValue;
                      final label = _seriesLabel(point.label);

                      return Expanded(
                        child: Tooltip(
                          message: '$label: ${point.doses} dosis',
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                SizedBox(
                                  height: 13,
                                  child: Text(
                                    point.doses.toString(),
                                    maxLines: 1,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 9,
                                      height: 1,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: FractionallySizedBox(
                                      heightFactor: proportion.clamp(0.05, 1.0),
                                      widthFactor: 0.48,
                                      child: Container(
                                        constraints:
                                            const BoxConstraints(maxWidth: 44),
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.vertical(
                                            top: Radius.circular(4),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  height: 17,
                                  child: Center(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontSize: 9,
                                        height: 1,
                                        color: AppColors.slate,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );

                if (points.length > 12) {
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: chart,
                  );
                }
                return chart;
              },
            ),
    );
  }

  String _seriesLabel(String label) {
    if (_granularity == 'month') {
      final parts = label.split('-');
      if (parts.length >= 2) {
        const names = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
        final month = int.tryParse(parts[1]);
        if (month != null && month >= 1 && month <= 12) {
          return names[month - 1];
        }
      }
    }
    if (_granularity == 'week') {
      if (label.length >= 10) {
        return label.substring(5).replaceAll('-', '/');
      }
      return label;
    }
    if (label.length >= 10) return label.substring(8);
    return label;
  }

  Widget _vaccines(StatisticsDashboard dashboard) {
    final vaccines = dashboard.vaccineDistribution;
    return _card('Distribucion por biologico', 'Participacion real en el periodo', vaccines.isEmpty
        ? const Center(child: Text('Sin distribucion disponible', style: TextStyle(color: AppColors.slate)))
        : ListView.separated(
            itemCount: vaccines.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, index) {
              final vaccine = vaccines[index];
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(vaccine.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                  Text('${vaccine.doses} · ${vaccine.percentage.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
                ]),
                const SizedBox(height: 6),
                ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: (vaccine.percentage / 100).clamp(0.0, 1.0), minHeight: 7, backgroundColor: AppColors.background, valueColor: const AlwaysStoppedAnimation(AppColors.primary))),
              ]);
            },
          ));
  }

  Widget _card(String title, String subtitle, Widget child) {
    return Container(
      height: 300,
      padding: const EdgeInsets.fromLTRB(22, 18, 22, 18),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 2),
        Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
        const SizedBox(height: 12),
        Expanded(child: child),
      ]),
    );
  }

  Widget _productivity(StatisticsDashboard dashboard) {
    final rows = dashboard.vaccinatorProductivity;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Productividad por vacunador', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink)),
        const SizedBox(height: 4),
        const Text('Dosis aplicadas y pacientes unicos atendidos', style: TextStyle(fontSize: 12, color: AppColors.slate)),
        const SizedBox(height: 16),
        if (rows.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 18), child: Center(child: Text('Sin actividad registrada', style: TextStyle(color: AppColors.slate))))
        else
          for (final row in rows)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
              child: Row(children: [
                CircleAvatar(radius: 18, backgroundColor: AppColors.primarySoft, child: Text(_initials(row.name), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary))),
                const SizedBox(width: 12),
                Expanded(child: Text(row.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.ink))),
                Text('${row.doses} dosis', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(width: 16),
                Text('${row.uniquePatients} pacientes', style: const TextStyle(fontSize: 11, color: AppColors.slate)),
              ]),
            ),
      ]),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty).take(2);
    return parts.map((part) => part[0].toUpperCase()).join();
  }
}
