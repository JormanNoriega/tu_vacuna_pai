import 'package:flutter/material.dart';

import '../users/app_colors.dart';

/// Catálogo online: no interpreta datos de ejemplo como existencias reales.
class CatalogView extends StatefulWidget {
  const CatalogView({
    required this.catalog,
    this.stock,
    required this.global,
    this.institutionName = 'institución',
    required this.onRefresh,
    super.key,
  });

  final Future<List<Map<String, dynamic>>>? catalog;
  final Future<List<Map<String, dynamic>>>? stock;
  final bool global;
  final String institutionName;
  final VoidCallback onRefresh;

  @override
  State<CatalogView> createState() => _CatalogViewState();
}

class _CatalogViewState extends State<CatalogView> {
  String _search = '';
  String _filter = 'Todas';

  @override
  Widget build(BuildContext context) => Container(
    color: AppColors.background,
    child: FutureBuilder<List<Map<String, dynamic>>>(
      future: widget.catalog,
      builder: (context, snapshot) {
        final all = snapshot.data ?? const <Map<String, dynamic>>[];
        final stateKey = widget.global ? 'active' : 'enabled';
        final filtered = all.where((vaccine) {
          final text = '${vaccine['name'] ?? ''} ${vaccine['code'] ?? ''}'
              .toLowerCase();
          final state = vaccine[stateKey];
          return text.contains(_search.trim().toLowerCase()) &&
              (_filter == 'Todas' ||
                  (_filter == 'Activas' && state == true) ||
                  (_filter == 'Inactivas' && state == false));
        }).toList();
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 16,
                    runSpacing: 12,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Inventario y Catálogo de Biológicos',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.global
                                ? 'Catálogo global · solo lectura'
                                : 'Catálogo institucional · solo lectura',
                            style: const TextStyle(color: AppColors.slate),
                          ),
                        ],
                      ),
                      if (widget.catalog != null)
                        OutlinedButton.icon(
                          onPressed: widget.onRefresh,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Actualizar catálogo'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Catálogo de biológicos y existencias institucionales · solo lectura',
                    style: TextStyle(color: AppColors.slate),
                  ),
                  const SizedBox(height: 20),
                  if (widget.catalog == null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Center(
                          child: Text(
                            'No tienes permiso para consultar este catálogo.',
                          ),
                        ),
                        if (widget.stock != null) ...[
                          const SizedBox(height: 20),
                          _stockSection(context),
                        ],
                      ],
                    )
                  else if (snapshot.connectionState != ConnectionState.done)
                    Column(
                      children: [
                        const Center(child: CircularProgressIndicator()),
                        if (widget.stock != null) ...[
                          const SizedBox(height: 20),
                          _stockSection(context),
                        ],
                      ],
                    )
                  else if (snapshot.hasError)
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'No se pudo consultar el catálogo. Revisa la conexión y tus permisos.',
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: widget.onRefresh,
                            child: const Text('Reintentar'),
                          ),
                          if (widget.stock != null) ...[
                            const SizedBox(height: 20),
                            _stockSection(context),
                          ],
                        ],
                      ),
                    )
                  else ...[
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _summary('Biológicos en catálogo', '${all.length}'),
                        _summary(
                          'Activas',
                          '${all.where((v) => v[stateKey] == true).length}',
                        ),
                        _summary(
                          'Inactivas',
                          '${all.where((v) => v[stateKey] == false).length}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _stockSection(context),
                    const SizedBox(height: 20),
                    TextField(
                      onChanged: (value) => setState(() => _search = value),
                      decoration: const InputDecoration(
                        labelText: 'Buscar por nombre o código',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final filter in ['Todas', 'Activas', 'Inactivas'])
                          ChoiceChip(
                            label: Text(filter),
                            selected: _filter == filter,
                            onSelected: (_) => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppColors.border),
                      ),
                      child: filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: Text('No hay vacunas para mostrar.'),
                            )
                          : _vaccineTable(filtered, stateKey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    ),
  );

  static String _text(Object? value, String fallback) =>
      value is String && value.isNotEmpty ? value : fallback;

  Widget _vaccineTable(List<Map<String, dynamic>> vaccines, String stateKey) {
    if (MediaQuery.sizeOf(context).width < 760) {
      return Column(
        children: [
          for (final vaccine in vaccines)
            ListTile(
              leading: const Icon(
                Icons.vaccines_outlined,
                color: AppColors.primary,
              ),
              title: Text(_text(vaccine['name'], 'Nombre no disponible')),
              subtitle: Text(_text(vaccine['code'], 'Código no disponible')),
              trailing: _vaccineStatus(vaccine[stateKey]),
            ),
        ],
      );
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        headingRowColor: const WidgetStatePropertyAll(AppColors.background),
        columns: const [
          DataColumn(label: Text('Biológico')),
          DataColumn(label: Text('Código')),
          DataColumn(label: Text('Estado')),
        ],
        rows: [
          for (final vaccine in vaccines)
            DataRow(
              cells: [
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.vaccines_outlined,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(_text(vaccine['name'], 'Nombre no disponible')),
                    ],
                  ),
                ),
                DataCell(Text(_text(vaccine['code'], 'Código no disponible'))),
                DataCell(_vaccineStatus(vaccine[stateKey])),
              ],
            ),
        ],
      ),
    );
  }

  Widget _vaccineStatus(Object? enabled) {
    final label = enabled is bool
        ? enabled
              ? 'Activa'
              : 'Inactiva'
        : 'Estado no disponible';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: enabled == true
            ? AppColors.successSoft
            : enabled == false
            ? AppColors.background
            : AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: enabled == true
              ? AppColors.success
              : enabled == false
              ? AppColors.slate
              : AppColors.warning,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _stockSection(BuildContext context) {
    final stock = widget.stock;
    if (stock == null) {
      return _stockPanel(
        context,
        title: 'Existencias por lote · ${widget.institutionName}',
        body: const Text(
          'Tu perfil no tiene permiso INVENTORY_READ. El catálogo de vacunas se mantiene disponible.',
          style: TextStyle(color: AppColors.slate),
        ),
      );
    }
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: stock,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _stockPanel(
            context,
            title: 'Existencias por lote · ${widget.institutionName}',
            body: const LinearProgressIndicator(minHeight: 2),
          );
        }
        if (snapshot.hasError) {
          return _stockPanel(
            context,
            title: 'Existencias por lote · ${widget.institutionName}',
            body: Row(
              children: [
                const Expanded(
                  child: Text(
                    'No se pudo consultar el inventario. Revisa INVENTORY_READ y que la API de inventario esté habilitada.',
                    style: TextStyle(color: AppColors.slate),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.onRefresh,
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              ],
            ),
          );
        }
        final lots = snapshot.data ?? const <Map<String, dynamic>>[];
        final totalVials = lots.fold<int>(0, (total, lot) {
          final value = lot['availableVials'];
          return total + (value is int && value >= 0 ? value : 0);
        });
        return _stockPanel(
          context,
          title: 'Existencias por lote · ${widget.institutionName}',
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${lots.length} lotes registrados',
                    style: const TextStyle(
                      color: AppColors.slate,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$totalVials frascos disponibles',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (lots.isEmpty)
                    const Text(
                      'No hay lotes para mostrar.',
                      style: TextStyle(color: AppColors.slate),
                    ),
                ],
              ),
              if (lots.isNotEmpty) ...[
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: const WidgetStatePropertyAll(
                      AppColors.background,
                    ),
                    columns: const [
                      DataColumn(label: Text('Biológico')),
                      DataColumn(label: Text('Fabricante')),
                      DataColumn(label: Text('Lote')),
                      DataColumn(label: Text('Vencimiento')),
                      DataColumn(label: Text('Frascos disponibles')),
                    ],
                    rows: [
                      for (final lot in lots)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(_text(lot['vaccineName'], 'No disponible')),
                            ),
                            DataCell(
                              Text(_text(lot['manufacturer'], 'No disponible')),
                            ),
                            DataCell(
                              Text(_text(lot['lotNumber'], 'No disponible')),
                            ),
                            DataCell(
                              Text(_text(lot['expiresOn'], 'No disponible')),
                            ),
                            DataCell(
                              Text(
                                lot['availableVials'] is int
                                    ? '${lot['availableVials']}'
                                    : 'No disponible',
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
      },
    );
  }

  Widget _stockPanel(
    BuildContext context, {
    required String title,
    required Widget body,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              color: AppColors.primary,
              size: 20,
            ),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        body,
      ],
    ),
  );

  Widget _summary(String label, String value) => SizedBox(
    width: 220,
    child: Card(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AppColors.slate)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
