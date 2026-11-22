import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

/// Tarjeta con espacio interactivo de Georreferenciación y Mapa de Cobertura
/// para la vista de escritorio del Administrador.
class AdminCoverageMapCard extends StatefulWidget {
  const AdminCoverageMapCard({
    super.key,
    required this.institutionName,
    this.latitude = 4.6097,
    this.longitude = -74.0817,
  });

  final String institutionName;
  final double latitude;
  final double longitude;

  @override
  State<AdminCoverageMapCard> createState() => _AdminCoverageMapCardState();
}

class _AdminCoverageMapCardState extends State<AdminCoverageMapCard> {
  double _zoomLevel = 1.0;
  bool _showSatellite = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 1),
      ),
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera del Mapa
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0E7FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: Color(0xFF4F46E5),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Georreferenciación y Cobertura',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.ink,
                        ),
                      ),
                      Text(
                        'Coordenadas: ${widget.latitude.toStringAsFixed(4)}, ${widget.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                // Botones de acción del mapa
                IconButton(
                  tooltip: 'Centrar en sede',
                  icon: const Icon(
                    Icons.my_location_rounded,
                    size: 20,
                    color: AppColors.slate,
                  ),
                  onPressed: () => setState(() => _zoomLevel = 1.0),
                ),
                IconButton(
                  tooltip: _showSatellite
                      ? 'Vista estándar'
                      : 'Vista satelital',
                  icon: Icon(
                    _showSatellite
                        ? Icons.layers_clear_rounded
                        : Icons.layers_rounded,
                    size: 20,
                    color: AppColors.slate,
                  ),
                  onPressed: () =>
                      setState(() => _showSatellite = !_showSatellite),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Contenedor visual del mapa
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                height: 290,
                decoration: BoxDecoration(
                  color: _showSatellite
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFEEF2F6),
                  border: Border.all(color: AppColors.border),
                ),
                child: Stack(
                  children: [
                    // Cuadrícula y fondo cartográfico
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _MapCanvasPainter(
                          isDark: _showSatellite,
                          zoom: _zoomLevel,
                        ),
                      ),
                    ),

                    // Círculo de radio de influencia de la IPS (cobertura 5km)
                    Center(
                      child: Container(
                        width: 180 * _zoomLevel,
                        height: 180 * _zoomLevel,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                    // Marcador central: Sede Principal IPS
                    Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.ink.withValues(alpha: 0.85),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.institutionName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.4,
                                  ),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 18,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Marcador satélite 1: Brigada Móvil 1 (Norte)
                    Positioned(
                      top: 45,
                      left: 70,
                      child: _buildBrigadeMarker(
                        label: 'Brigada 1 (Norte)',
                        color: AppColors.success,
                        icon: Icons.directions_walk_rounded,
                      ),
                    ),

                    // Marcador satélite 2: Jornada Comunitaria (Sur-Oriente)
                    Positioned(
                      bottom: 50,
                      right: 80,
                      child: _buildBrigadeMarker(
                        label: 'Puesto Comunitario',
                        color: AppColors.warning,
                        icon: Icons.campaign_rounded,
                      ),
                    ),

                    // Controles de Zoom en la esquina superior derecha
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.add, size: 18),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (_zoomLevel < 1.6) {
                                  setState(() => _zoomLevel += 0.2);
                                }
                              },
                            ),
                            const Divider(
                              height: 1,
                              color: AppColors.border,
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove, size: 18),
                              constraints: const BoxConstraints(
                                minWidth: 32,
                                minHeight: 32,
                              ),
                              padding: EdgeInsets.zero,
                              onPressed: () {
                                if (_zoomLevel > 0.6) {
                                  setState(() => _zoomLevel -= 0.2);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Leyenda del mapa en la parte inferior
                    Positioned(
                      bottom: 10,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface.withValues(alpha: 0.92),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendItem(
                              color: AppColors.primary,
                              label: 'IPS Principal',
                            ),
                            SizedBox(width: 12),
                            _LegendItem(
                              color: AppColors.success,
                              label: 'Brigada Activa',
                            ),
                            SizedBox(width: 12),
                            _LegendItem(
                              color: AppColors.warning,
                              label: 'Puesto Móvil',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrigadeMarker({
    required String label,
    required Color color,
    required IconData icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
              ),
            ],
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(icon, color: Colors.white, size: 14),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Dibuja cuadrícula cartográfica médica en el canvas
class _MapCanvasPainter extends CustomPainter {
  _MapCanvasPainter({required this.isDark, required this.zoom});

  final bool isDark;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = (isDark ? Colors.white : const Color(0xFFCBD5E1)).withValues(
        alpha: 0.25,
      )
      ..strokeWidth = 1.0;

    final roadPaint = Paint()
      ..color = (isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0))
      ..strokeWidth = 6.0 * zoom;

    // Calles/Vías simuladas
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawLine(
      Offset(0, center.dy),
      Offset(size.width, center.dy),
      roadPaint,
    );
    canvas.drawLine(
      Offset(center.dx, 0),
      Offset(center.dx, size.height),
      roadPaint,
    );
    canvas.drawLine(
      Offset(0, size.height * 0.25),
      Offset(size.width, size.height * 0.75),
      roadPaint..strokeWidth = 3.5 * zoom,
    );

    // Cuadrícula sutil
    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MapCanvasPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.zoom != zoom;
  }
}
