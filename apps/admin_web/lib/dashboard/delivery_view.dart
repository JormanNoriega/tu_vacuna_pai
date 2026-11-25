import 'package:flutter/material.dart';

import '../connection/admin_session.dart';
import '../users/app_colors.dart';

class DeliveryView extends StatefulWidget {
  const DeliveryView({
    required this.session,
    required this.section,
    required this.onSelect,
    super.key,
  });

  final AdminSession session;
  final String section;
  final ValueChanged<String> onSelect;

  @override
  State<DeliveryView> createState() => _DeliveryViewState();
}

class _DeliveryViewState extends State<DeliveryView> {
  Future<List<Map<String, dynamic>>>? _data;
  String _search = '';
  String _status = 'Todos';

  String get _resource => switch (widget.section) {
    'jornadas' => 'campaigns',
    'custodia' => 'custody-events',
    _ => 'assignments',
  };

  String get _title => switch (widget.section) {
    'jornadas' => 'Jornadas y Campañas',
    'custodia' => 'Custodia y cierre de jornada',
    _ => 'Entregas a vacunadores',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(DeliveryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.section != widget.section) {
      _status = 'Todos';
      _search = '';
      _load();
    }
  }

  void _load() {
    _data = widget.session.canReadInventory
        ? widget.session.loadInventoryList(_resource)
        : null;
  }

  String _value(Map<String, dynamic> item, String key) =>
      item[key]?.toString().trim() ?? '';

  String _display(Map<String, dynamic> item, String key) {
    final value = _value(item, key);
    return value.isEmpty ? 'No disponible' : value;
  }

  List<String> _searchable(Map<String, dynamic> item) => [
    for (final value in item.values)
      if (value != null) value.toString(),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1400),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(),
              const SizedBox(height: 18),
              _navigation(),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 13,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.lock_outline,
                      color: AppColors.primary,
                      size: 19,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Vista de solo lectura. Los despachos, recepciones, cierres y '
                        'conciliaciones no están habilitados.',
                        style: TextStyle(color: AppColors.ink, height: 1.35),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              if (_data == null)
                _emptyState(
                  title: 'Permiso requerido',
                  detail:
                      'Tu perfil no tiene permiso para consultar inventario.',
                  icon: Icons.lock_person_outlined,
                )
              else
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _data,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Padding(
                        padding: EdgeInsets.all(56),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    if (snapshot.hasError) {
                      return _emptyState(
                        title: 'No se pudo consultar el inventario',
                        detail:
                            'Revisa la conexión, el permiso INVENTORY_READ y que la API '
                            'de inventario esté habilitada en Spring.',
                        icon: Icons.cloud_off_outlined,
                        retry: true,
                      );
                    }
                    return _results(snapshot.data ?? const []);
                  },
                ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 720;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Entregas y Custodia',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            '$_title · ${widget.session.institutionName ?? 'Institución'}',
            style: const TextStyle(color: AppColors.slate),
          ),
        ],
      );
      final refresh = OutlinedButton.icon(
        onPressed: _data == null ? null : () => setState(_load),
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Actualizar'),
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: title),
                    IconButton(
                      onPressed: _data == null ? null : () => setState(_load),
                      tooltip: 'Actualizar',
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

  Widget _navigation() => Align(
    alignment: Alignment.centerLeft,
    child: Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _tab('Entregas', 'entregas', Icons.outbox_outlined),
        _tab('Jornadas', 'jornadas', Icons.campaign_outlined),
        _tab('Custodia', 'custodia', Icons.inventory_2_outlined),
      ],
    ),
  );

  Widget _tab(String label, String section, IconData icon) => ChoiceChip(
    selected: widget.section == section,
    onSelected: (_) => widget.onSelect(section),
    avatar: Icon(icon, size: 17),
    label: Text(label),
    selectedColor: AppColors.primarySoft,
    backgroundColor: AppColors.surface,
    side: BorderSide(
      color: widget.section == section ? AppColors.primary : AppColors.border,
    ),
  );

  Widget _results(List<Map<String, dynamic>> items) {
    final statuses =
        items
            .map((item) => _value(item, 'status'))
            .where((status) => status.isNotEmpty)
            .toSet()
            .toList()
          ..sort();
    final filtered = items.where((item) {
      final searchMatch =
          _search.isEmpty ||
          _searchable(item)
              .join(' ')
              .toLowerCase()
              .contains(_search.toLowerCase());
      final status = _value(item, 'status');
      return searchMatch && (_status == 'Todos' || status == _status);
    }).toList();
    final statusCounts = <String, int>{};
    for (final item in items) {
      final status = _value(item, 'status');
      if (status.isNotEmpty) {
        statusCounts.update(status, (count) => count + 1, ifAbsent: () => 1);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900 ? 3 : 2;
            final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _summary(
                  width,
                  'Registros consultados',
                  '${items.length}',
                  Icons.list_alt,
                ),
                for (final entry in statusCounts.entries.take(
                  columns == 3 ? 2 : 1,
                ))
                  _summary(
                    width,
                    'Estado ${entry.key}',
                    '${entry.value}',
                    Icons.radio_button_checked_outlined,
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 620;
            final search = TextField(
              onChanged: (value) => setState(() => _search = value.trim()),
              decoration: const InputDecoration(
                labelText: 'Buscar en los registros',
                prefixIcon: Icon(Icons.search_rounded),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            );
            final filters = Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final status in ['Todos', ...statuses])
                  ChoiceChip(
                    label: Text(status),
                    selected: _status == status,
                    onSelected: (_) => setState(() => _status = status),
                    selectedColor: AppColors.primarySoft,
                  ),
              ],
            );
            return narrow
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [search, const SizedBox(height: 12), filters],
                  )
                : Row(
                    children: [
                      Expanded(flex: 2, child: search),
                      const SizedBox(width: 16),
                      Expanded(child: filters),
                    ],
                  );
          },
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _emptyState(
            title: items.isEmpty
                ? 'No hay registros para mostrar'
                : 'Sin coincidencias',
            detail: items.isEmpty
                ? 'Cuando existan registros disponibles para esta institución aparecerán aquí.'
                : 'Cambia el texto de búsqueda o el filtro de estado.',
            icon: Icons.inventory_2_outlined,
          )
        else
          _records(filtered),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            'Mostrando ${filtered.length} de ${items.length} registros',
            style: const TextStyle(color: AppColors.slate, fontSize: 12),
          ),
        ),
      ],
    );
  }

  Widget _summary(double width, String label, String value, IconData icon) =>
      SizedBox(
        width: width,
        child: Container(
          constraints: const BoxConstraints(minHeight: 92),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _records(List<Map<String, dynamic>> items) {
    final narrow = MediaQuery.sizeOf(context).width < 760;
    if (narrow) {
      return Column(children: [for (final item in items) _recordCard(item)]);
    }
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(AppColors.background),
            columns: [
              DataColumn(label: Text(_columnTitle(0))),
              DataColumn(label: Text(_columnTitle(1))),
              DataColumn(label: Text(_columnTitle(2))),
              const DataColumn(label: Text('Estado')),
            ],
            rows: [
              for (final item in items)
                DataRow(
                  cells: [
                    DataCell(Text(_display(item, _columnKey(0)))),
                    DataCell(Text(_display(item, _columnKey(1)))),
                    DataCell(Text(_columnValue(item))),
                    DataCell(_statusBadge(_display(item, 'status'))),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recordCard(Map<String, dynamic> item) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(
        widget.section == 'jornadas'
            ? Icons.campaign_outlined
            : widget.section == 'custodia'
            ? Icons.inventory_2_outlined
            : Icons.local_shipping_outlined,
        color: AppColors.primary,
      ),
      title: Text(_display(item, _columnKey(0))),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${_columnTitle(1)}: ${_display(item, _columnKey(1))}'),
            Text('${_columnTitle(2)}: ${_columnValue(item)}'),
          ],
        ),
      ),
      trailing: _statusBadge(_display(item, 'status')),
    ),
  );

  String _columnTitle(int index) => switch (widget.section) {
    'jornadas' => ['Jornada', 'Ubicación', 'Inicio'][index],
    'custodia' => ['Biológico', 'Lote', 'Frascos'][index],
    _ => ['Biológico', 'Lote', 'Frascos'][index],
  };

  String _columnKey(int index) => switch ((widget.section, index)) {
    ('jornadas', 0) => 'name',
    ('jornadas', 1) => 'location',
    ('jornadas', 2) => 'startsOn',
    (_, 0) => 'vaccineName',
    (_, 1) => 'lotNumber',
    _ => 'vialCount',
  };

  String _columnValue(Map<String, dynamic> item) {
    if (widget.section == 'jornadas') {
      final end = _display(item, 'endsOn');
      return '${_display(item, 'startsOn')} – $end';
    }
    final count = _display(item, 'vialCount');
    final received = _value(item, 'receivedVials');
    if (widget.section == 'entregas' && received.isNotEmpty) {
      return '$count · recibidos: $received';
    }
    return count;
  }

  Widget _statusBadge(String status) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: status == 'No disponible'
          ? AppColors.background
          : AppColors.primarySoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: const TextStyle(
        color: AppColors.ink,
        fontSize: 11,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _emptyState({
    required String title,
    required String detail,
    required IconData icon,
    bool retry = false,
  }) => Container(
    padding: const EdgeInsets.all(28),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, color: AppColors.hint, size: 32),
        const SizedBox(height: 10),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.ink,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          detail,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.slate, height: 1.4),
        ),
        if (retry) ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () => setState(_load),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ],
    ),
  );
}
