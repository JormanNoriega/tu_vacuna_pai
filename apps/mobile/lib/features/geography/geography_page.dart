import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'geography_controller.dart';

/// Visor experimental: el mapa y sus controles nunca consultan por encuadre.
class GeographyPage extends StatefulWidget {
  const GeographyPage({
    super.key,
    required this.controller,
    required this.online,
  });
  final GeographyController controller;
  final bool online;

  @override
  State<GeographyPage> createState() => _GeographyPageState();
}

class _GeographyPageState extends State<GeographyPage> {
  int days = 30;
  bool heat = true;
  double opacity = .8;
  double intensity = 1;
  double radius = 30;

  @override
  void initState() {
    super.initState();
    if (widget.online) unawaited(widget.controller.load(days));
  }

  @override
  void didUpdateWidget(covariant GeographyPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.online && widget.online) {
      unawaited(widget.controller.load(days));
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) => LayoutBuilder(
        builder: (context, constraints) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (controller.synthetic)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Row(
                  children: [
                    Icon(
                      Icons.science_outlined,
                      size: 20,
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Demostración · Datos sintéticos. No representan atenciones reales.',
                        style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: constraints.maxHeight * .55,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            'Georreferenciación y cobertura',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          DropdownButton<int>(
                            value: days,
                            items: [7, 30, 90]
                                .map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text('$d días'),
                                  ),
                                )
                                .toList(),
                            onChanged: !widget.online
                                ? null
                                : (value) {
                                    if (value == null) return;
                                    setState(() => days = value);
                                    unawaited(controller.load(value));
                                  },
                          ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(value: true, label: Text('Calor')),
                              ButtonSegment(
                                value: false,
                                label: Text('Agrupaciones'),
                              ),
                            ],
                            selected: {heat},
                            onSelectionChanged: (value) =>
                                setState(() => heat = value.first),
                          ),
                          IconButton(
                            tooltip: 'Actualizar datos',
                            onPressed: !widget.online || controller.loading
                                ? null
                                : () => controller.load(days, refresh: true),
                            icon: const Icon(Icons.refresh),
                          ),
                        ],
                      ),
                    ),
                    if (!controller.synthetic)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Celdas aproximadas; las áreas vacías no indican ausencia de atenciones. '
                          'La actualización puede reflejar datos de hasta 30 minutos.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 16,
                        children: [
                          _slider(
                            'Opacidad',
                            opacity,
                            0,
                            1,
                            (v) => setState(() => opacity = v),
                          ),
                          if (heat)
                            _slider(
                              'Intensidad',
                              intensity,
                              .2,
                              3,
                              (v) => setState(() => intensity = v),
                            ),
                          if (heat)
                            _slider(
                              'Radio',
                              radius,
                              10,
                              70,
                              (v) => setState(() => radius = v),
                            ),
                        ],
                      ),
                    ),
                    if (controller.data != null && widget.online)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'Datos calculados: ${DateFormat('dd/MM/yyyy HH:mm').format(controller.data!.generatedAt.toLocal())} (hora del dispositivo). '
                          '${heat ? 'Mayor intensidad de color indica mayor concentración; el radio y la intensidad cambian la apariencia.' : 'Cada círculo muestra el total de su celda.'}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: !widget.online
                      ? const Center(
                          child: Text(
                            'El visor requiere una sesión y conexión en línea.',
                          ),
                        )
                      : controller.loading
                      ? const Center(child: CircularProgressIndicator())
                      : controller.error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  controller.error!,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  onPressed: () =>
                                      controller.load(days, refresh: true),
                                  icon: const Icon(Icons.refresh),
                                  label: const Text('Reintentar'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : controller.data == null
                      ? const Center(child: Text('No hay datos disponibles.'))
                      : Stack(
                          children: [
                            Positioned.fill(
                              child: _GeographyMap(
                                data: controller.data!,
                                heat: heat,
                                opacity: opacity,
                                intensity: intensity,
                                radius: radius,
                              ),
                            ),
                            if (controller.data!.cells.isEmpty)
                              const Align(
                                alignment: Alignment.topCenter,
                                child: Card(
                                  child: Padding(
                                    padding: EdgeInsets.all(12),
                                    child: Text(
                                      'No hay celdas publicables para este período.',
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) => SizedBox(
    width: 190,
    child: Row(
      children: [
        Text(label),
        Expanded(
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    ),
  );
}

class _GeographyMap extends StatefulWidget {
  const _GeographyMap({
    required this.data,
    required this.heat,
    required this.opacity,
    required this.intensity,
    required this.radius,
  });
  final GeographyData data;
  final bool heat;
  final double opacity, intensity, radius;
  @override
  State<_GeographyMap> createState() => _GeographyMapState();
}

class _GeographyMapState extends State<_GeographyMap> {
  MapLibreMapController? map;
  bool ready = false;
  String? error;
  Future<void> pending = Future.value();
  static const style = String.fromEnvironment(
    'GEOGRAPHY_MAP_STYLE_URL',
    defaultValue: 'https://tiles.openfreemap.org/styles/positron',
  );

  Map<String, dynamic> get geojson => {
    'type': 'FeatureCollection',
    'features': widget.data.cells
        .map(
          (c) => {
            'type': 'Feature',
            'properties': {'count': c.count},
            'geometry': {
              'type': 'Point',
              'coordinates': [c.longitude, c.latitude],
            },
          },
        )
        .toList(),
  };

  @override
  void didUpdateWidget(covariant _GeographyMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (ready) _queueUpdate();
  }

  void _queueUpdate() {
    pending = pending.then((_) async {
      if (!mounted || !ready || map == null) return;
      try {
        await map!.setGeoJsonSource('attentions', geojson);
        await map!.setLayerProperties(
          'heat',
          HeatmapLayerProperties(
            heatmapWeight: ['get', 'count'],
            heatmapRadius: widget.radius,
            heatmapIntensity: widget.intensity,
            heatmapOpacity: widget.opacity,
            visibility: widget.heat ? 'visible' : 'none',
          ),
        );
        await map!.setLayerProperties(
          'circles',
          CircleLayerProperties(
            circleRadius: 18,
            circleColor: '#135BEC',
            circleOpacity: widget.opacity,
            circleStrokeColor: '#FFFFFF',
            circleStrokeWidth: 1,
            visibility: widget.heat ? 'none' : 'visible',
          ),
        );
        await map!.setLayerProperties(
          'counts',
          SymbolLayerProperties(
            textField: [
              'to-string',
              ['get', 'count'],
            ],
            textSize: 12,
            textColor: '#FFFFFF',
            textAllowOverlap: true,
            visibility: widget.heat ? 'none' : 'visible',
          ),
        );
      } catch (_) {
        if (mounted) {
          setState(() => error = 'No se pudieron dibujar los datos del mapa.');
        }
      }
    });
  }

  Future<void> _onStyle() async {
    try {
      final controller = map;
      if (controller == null) return;
      await controller.addGeoJsonSource('attentions', geojson);
      await controller.addHeatmapLayer(
        'attentions',
        'heat',
        const HeatmapLayerProperties(),
      );
      await controller.addCircleLayer(
        'attentions',
        'circles',
        const CircleLayerProperties(),
      );
      await controller.addSymbolLayer(
        'attentions',
        'counts',
        const SymbolLayerProperties(),
      );
      ready = true;
      _queueUpdate();
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo preparar el mapa.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cells = widget.data.cells;
    final center = cells.isEmpty
        ? const LatLng(4.6, -74.1)
        : LatLng(cells.first.latitude, cells.first.longitude);
    return Stack(
      children: [
        MapLibreMap(
          styleString: style,
          initialCameraPosition: CameraPosition(
            target: center,
            zoom: cells.isEmpty ? 4 : 8,
          ),
          minMaxZoomPreference: const MinMaxZoomPreference(2, 14),
          onMapCreated: (value) => map = value,
          onStyleLoadedCallback: _onStyle,
        ),
        if (error != null)
          Align(
            alignment: Alignment.topCenter,
            child: Material(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(error!),
              ),
            ),
          ),
      ],
    );
  }
}
