import 'package:flutter/material.dart';

import '../connection/admin_session.dart';
import '../connection/report_download.dart';
import '../users/app_colors.dart';

/// Tres vistas de historial de Brayan: registro, expediente y exportación.
/// Cada una queda limitada por los permisos y contratos reales de Spring.
class HistoryView extends StatefulWidget {
  const HistoryView({
    required this.session,
    this.initialTab = 'registro',
    super.key,
  });

  final AdminSession session;
  final String initialTab;

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  static const _documentTypes = [
    'CC',
    'TI',
    'RC',
    'CE',
    'PA',
    'MS',
    'AS',
    'CN',
  ];

  late DateTimeRange _range;
  late DateTimeRange _reportRange;
  Future<Map<String, dynamic>>? _result;
  Future<Map<String, dynamic>>? _reportSummary;
  Future<List<Map<String, dynamic>>>? _patientAttentions;
  final _documentNumber = TextEditingController();
  int _page = 0;
  int _tab = 0;
  String _search = '';
  String _documentType = 'CC';
  String _reportFormat = 'xlsx';
  List<Map<String, dynamic>> _patients = const [];
  Map<String, dynamic>? _selectedPatient;
  bool _searchingPatient = false;
  bool _downloading = false;
  String? _patientError;

  @override
  void initState() {
    super.initState();
    final today = _today();
    _range = DateTimeRange(
      start: today.subtract(const Duration(days: 30)),
      end: today,
    );
    _reportRange = _range;
    _tab = switch (widget.initialTab) {
      'expediente' => 1,
      'reportes' => 2,
      _ => 0,
    };
    if (widget.session.canReadHistory) {
      _loadHistory();
      if (_tab == 2) _loadReportSummary();
    }
  }

  @override
  void didUpdateWidget(HistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      setState(() {
        _tab = switch (widget.initialTab) {
          'expediente' => 1,
          'reportes' => 2,
          _ => 0,
        };
      });
      if (_tab == 2 && widget.session.canReadHistory) _loadReportSummary();
    }
  }

  DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _endOfDay(DateTime value) =>
      DateTime(value.year, value.month, value.day, 23, 59, 59, 999);

  void _loadHistory() {
    final to = DateTime(_range.end.year, _range.end.month, _range.end.day + 1);
    _result = widget.session.loadHistory(
      from: _range.start,
      to: to,
      page: _page,
    );
  }

  void _loadReportSummary() {
    _reportSummary = widget.session.loadReportSummary(
      from: _reportRange.start,
      to: _endOfDay(_reportRange.end),
    );
  }

  void _refresh([int? page]) => setState(() {
    if (page != null) _page = page;
    _loadHistory();
  });

  Future<void> _chooseRange({required bool report}) async {
    final current = report ? _reportRange : _range;
    final now = _today();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 1),
      initialDateRange: current,
      helpText: report
          ? 'Seleccionar período del reporte'
          : 'Seleccionar período de atenciones',
    );
    if (!mounted || picked == null) return;
    if (picked.end.difference(picked.start).inDays > 365) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona un rango máximo de 366 días.'),
        ),
      );
      return;
    }
    setState(() {
      if (report) {
        _reportRange = picked;
        _loadReportSummary();
      } else {
        _range = picked;
        _page = 0;
        _loadHistory();
      }
    });
  }

  Future<void> _searchForPatient() async {
    final number = _documentNumber.text.trim();
    if (number.isEmpty) {
      setState(
        () => _patientError = 'Escribe el número de documento para buscar.',
      );
      return;
    }
    setState(() {
      _searchingPatient = true;
      _patientError = null;
      _selectedPatient = null;
      _patientAttentions = null;
      _patients = const [];
    });
    try {
      final found = await widget.session.searchPatients(
        documentType: _documentType,
        documentNumber: number,
      );
      if (!mounted) return;
      setState(() {
        _patients = found;
        if (found.isEmpty)
          _patientError = 'No se encontró un paciente con ese documento.';
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _patientError = 'No se pudo buscar el expediente. Revisa PATIENT_READ y la conexión.';
        });
      }
    } finally {
      if (mounted) setState(() => _searchingPatient = false);
    }
  }

  void _selectPatient(Map<String, dynamic> patient) {
    final id = patient['id'];
    if (id is! String || id.isEmpty) {
      setState(
        () => _patientError = 'El registro no incluye un identificador válido.',
      );
      return;
    }
    setState(() {
      _selectedPatient = patient;
      _patientError = null;
      _patientAttentions = widget.session.loadPatientAttentions(id);
    });
  }

  String _date(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _text(Object? value, [String fallback = 'No disponible']) =>
      value is String && value.trim().isNotEmpty ? value : fallback;

  String _patientName(Map<String, dynamic> patient) => [
    patient['firstName'],
    patient['secondName'],
    patient['lastName'],
    patient['secondLastName'],
  ].whereType<String>().where((part) => part.trim().isNotEmpty).join(' ');

  Future<void> _downloadReport() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    try {
      final report = await widget.session.downloadReport(
        from: _reportRange.start,
        to: _endOfDay(_reportRange.end),
        format: _reportFormat,
      );
      await saveAdminReport(
        bytes: report.bytes,
        filename: report.filename,
        contentType: report.contentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Reporte descargado: ${report.filename}')),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'No se pudo descargar el reporte. Revisa la conexión y vuelve a intentarlo.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  void dispose() {
    _documentNumber.dispose();
    super.dispose();
  }

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
              const SizedBox(height: 20),
              _tabs(),
              const SizedBox(height: 20),
              if (_tab == 0)
                _generalHistory()
              else if (_tab == 1)
                _patientRecord()
              else
                _reports(),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _header() => LayoutBuilder(
    builder: (context, constraints) {
      final compact = constraints.maxWidth < 650;
      final title = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Historial Clínico',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Atenciones, expedientes y reportes · ${widget.session.institutionName ?? 'Institución'}',
            style: const TextStyle(color: AppColors.slate),
          ),
        ],
      );
      final refresh = IconButton.filledTonal(
        tooltip: _tab == 2
            ? 'Actualizar resumen del reporte'
            : 'Actualizar historial',
        onPressed: _tab == 2
            ? (widget.session.canReadHistory
                  ? () => setState(_loadReportSummary)
                  : null)
            : (widget.session.canReadHistory ? () => _refresh() : null),
        icon: const Icon(Icons.refresh_rounded),
      );
      return compact
          ? Row(
              children: [
                Expanded(child: title),
                const SizedBox(width: 8),
                refresh,
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

  Widget _tabs() => Container(
    padding: const EdgeInsets.all(5),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final labels = const [
          ('Registro general', Icons.view_list_outlined),
          ('Expediente clínico', Icons.folder_shared_outlined),
          ('Reportes PAI', Icons.file_download_outlined),
        ];
        if (constraints.maxWidth < 600) {
          return DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: _tab,
              isExpanded: true,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              items: [
                for (var index = 0; index < labels.length; index++)
                  DropdownMenuItem(
                    value: index,
                    child: Row(
                      children: [
                        Icon(labels[index].$2, size: 18),
                        const SizedBox(width: 10),
                        Text(labels[index].$1),
                      ],
                    ),
                  ),
              ],
              onChanged: (value) {
                if (value != null) _setTab(value);
              },
            ),
          );
        }
        return Row(
          children: [
            for (var index = 0; index < labels.length; index++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _tabButton(index, labels[index].$1, labels[index].$2),
                ),
              ),
          ],
        );
      },
    ),
  );

  Widget _tabButton(int index, String label, IconData icon) => TextButton.icon(
    onPressed: () => _setTab(index),
    icon: Icon(icon, size: 18),
    label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
    style: TextButton.styleFrom(
      minimumSize: const Size(0, 44),
      foregroundColor: _tab == index ? AppColors.primary : AppColors.slate,
      backgroundColor: _tab == index
          ? AppColors.primarySoft
          : Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      textStyle: TextStyle(
        fontWeight: _tab == index ? FontWeight.w700 : FontWeight.w500,
      ),
    ),
  );

  void _setTab(int index) {
    setState(() => _tab = index);
    if (index == 2 && widget.session.canReadHistory) _loadReportSummary();
  }

  Widget _generalHistory() {
    if (!widget.session.canReadHistory) {
      return _messagePanel(
        'Permiso requerido',
        'Tu perfil no tiene permiso ATTENTION_READ para consultar el historial.',
        Icons.lock_outline,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final search = TextField(
              onChanged: (value) =>
                  setState(() => _search = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                labelText: 'Buscar en esta página',
                hintText: 'Paciente, documento o profesional',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
                border: OutlineInputBorder(),
              ),
            );
            final filters = Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _chooseRange(report: false),
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text('${_date(_range.start)} – ${_date(_range.end)}'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Actualizar'),
                ),
              ],
            );
            return constraints.maxWidth < 900
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [filters, const SizedBox(height: 12), search],
                  )
                : Row(
                    children: [
                      Expanded(flex: 2, child: search),
                      const SizedBox(width: 14),
                      filters,
                    ],
                  );
          },
        ),
        const SizedBox(height: 18),
        FutureBuilder<Map<String, dynamic>>(
          future: _result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(48),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _messagePanel(
                'No se pudo consultar el historial',
                'Revisa la conexión, el período y los permisos del perfil. Puedes reintentar la consulta.',
                Icons.cloud_off_outlined,
                action: OutlinedButton.icon(
                  onPressed: () => _refresh(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Reintentar'),
                ),
              );
            }
            final items = (snapshot.data!['items'] as List)
                .whereType<Map<String, dynamic>>()
                .where((item) {
                  if (_search.isEmpty) return true;
                  return [
                        item['patientName'],
                        item['document'],
                        item['professionalName'],
                      ]
                      .whereType<Object>()
                      .join(' ')
                      .toLowerCase()
                      .contains(_search);
                })
                .toList();
            final doseCount = items.fold<int>(0, (count, item) {
              final doses = item['doses'];
              return count + (doses is List ? doses.length : 0);
            });
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 900 ? 3 : 2;
                    final width =
                        (constraints.maxWidth - (columns - 1) * 12) / columns;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _summary(
                          width,
                          'Atenciones en esta página',
                          '${items.length}',
                          Icons.assignment_outlined,
                        ),
                        _summary(
                          width,
                          'Dosis del resultado',
                          '$doseCount',
                          Icons.vaccines_outlined,
                        ),
                        _summary(
                          width,
                          'Período consultado',
                          '${_date(_range.start)} – ${_date(_range.end)}',
                          Icons.calendar_month_outlined,
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 14),
                if (items.isEmpty)
                  _messagePanel(
                    'No hay atenciones para mostrar',
                    _search.isEmpty
                        ? 'No se encontraron registros en este período.'
                        : 'No hay coincidencias en esta página. Cambia la búsqueda o avanza a otra página.',
                    Icons.event_note_outlined,
                  )
                else
                  _historyRows(items),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _page > 0 ? () => _refresh(_page - 1) : null,
                      child: const Text('Anterior'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Página ${_page + 1}'),
                    ),
                    TextButton(
                      onPressed: snapshot.data!['hasNext'] == true
                          ? () => _refresh(_page + 1)
                          : null,
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _historyRows(List<Map<String, dynamic>> items) => Column(
    children: [
      for (final item in items)
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ExpansionTile(
            leading: const Icon(
              Icons.medical_information_outlined,
              color: AppColors.primary,
            ),
            title: Text(_text(item['patientName'], 'Paciente no disponible')),
            subtitle: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(_text(item['document'])),
                Text(_text(item['date'])),
                if (item['consecutive'] != null)
                  Text('Consecutivo ${item['consecutive']}'),
              ],
            ),
            childrenPadding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 20,
                runSpacing: 8,
                children: [
                  _detail('Profesional', _text(item['professionalName'])),
                  _detail('Estado', _text(item['status'])),
                ],
              ),
              const Divider(height: 24),
              const Text(
                'Dosis registradas',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 8),
              for (final dose
                  in (item['doses'] is List ? item['doses'] as List : const []))
                if (dose is Map)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.vaccines_outlined,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '${_text(dose['vaccine'], 'Vacuna no disponible')} · '
                            '${_text(dose['label'], 'Dosis no disponible')} · '
                            'Lote: ${_text(dose['lot'])}',
                            style: const TextStyle(color: AppColors.slate),
                          ),
                        ),
                      ],
                    ),
                  ),
              if ((item['observations'] as String?)?.trim().isNotEmpty ==
                  true) ...[
                const SizedBox(height: 8),
                _detail('Observaciones', item['observations'] as String),
              ],
            ],
          ),
        ),
    ],
  );

  Widget _patientRecord() {
    final hasPermission = widget.session.canReadPatients;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          'Búsqueda y expediente clínico',
          'Consulta por documento y revisa las atenciones asociadas al paciente.',
          Icons.folder_shared_outlined,
        ),
        const SizedBox(height: 16),
        if (!hasPermission)
          _messagePanel(
            'Permiso requerido',
            'Tu perfil no tiene PATIENT_READ. El acceso al expediente se mantiene protegido por Spring.',
            Icons.lock_outline,
          )
        else ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final searchButton = FilledButton.icon(
                  onPressed: _searchingPatient ? null : _searchForPatient,
                  icon: _searchingPatient
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search_rounded),
                  label: Text(
                    _searchingPatient ? 'Buscando…' : 'Buscar paciente',
                  ),
                );
                final fields = [
                  SizedBox(
                    width: 180,
                    child: DropdownButtonFormField<String>(
                      value: _documentType,
                      decoration: const InputDecoration(
                        labelText: 'Tipo de documento',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        for (final type in _documentTypes)
                          DropdownMenuItem(value: type, child: Text(type)),
                      ],
                      onChanged: (value) {
                        if (value != null)
                          setState(() => _documentType = value);
                      },
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _documentNumber,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _searchForPatient(),
                      decoration: const InputDecoration(
                        labelText: 'Número de documento',
                        prefixIcon: Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  searchButton,
                ];
                if (constraints.maxWidth < 820) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      fields[0],
                      const SizedBox(height: 12),
                      fields[1],
                      const SizedBox(height: 12),
                      searchButton,
                    ],
                  );
                }
                return Row(
                  children: [
                    fields[0],
                    const SizedBox(width: 12),
                    fields[1],
                    const SizedBox(width: 12),
                    searchButton,
                  ],
                );
              },
            ),
          ),
          if (_patientError != null) ...[
            const SizedBox(height: 12),
            _messagePanel(
              _patientError!.startsWith('No se encontró')
                  ? 'Paciente no encontrado'
                  : 'No se completó la búsqueda',
              _patientError!,
              _patientError!.startsWith('No se encontró')
                  ? Icons.person_search_outlined
                  : Icons.warning_amber_rounded,
            ),
          ],
          if (_patients.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionHeading(
              'Resultados',
              '${_patients.length} coincidencia${_patients.length == 1 ? '' : 's'} para el documento',
              Icons.people_alt_outlined,
            ),
            const SizedBox(height: 10),
            for (final patient in _patients) _patientTile(patient),
          ],
          if (_selectedPatient != null) ...[
            const SizedBox(height: 20),
            _patientDetail(),
          ],
        ],
      ],
    );
  }

  Widget _patientTile(Map<String, dynamic> patient) {
    final name = _patientName(patient);
    final id = patient['id']?.toString();
    final selected = id != null && id == _selectedPatient?['id'];
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: selected ? AppColors.primary : AppColors.border,
        ),
      ),
      child: ListTile(
        onTap: () => _selectPatient(patient),
        leading: CircleAvatar(
          backgroundColor: AppColors.primarySoft,
          foregroundColor: AppColors.primary,
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name.isEmpty ? 'Nombre no disponible' : name),
        subtitle: Text(
          '${_text(patient['documentType'])} ${_text(patient['documentNumber'])}'
          ' · Nacimiento: ${_text(patient['birthDate'])}',
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
      ),
    );
  }

  Widget _patientDetail() {
    final patient = _selectedPatient!;
    final result = _patientAttentions;
    return Container(
      padding: const EdgeInsets.all(20),
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
              const Icon(
                Icons.assignment_ind_outlined,
                color: AppColors.primary,
                size: 23,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _patientName(patient),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              Text(_text(patient['status'])),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 20,
            runSpacing: 8,
            children: [
              _detail(
                'Documento',
                '${_text(patient['documentType'])} ${_text(patient['documentNumber'])}',
              ),
              _detail('Fecha de nacimiento', _text(patient['birthDate'])),
              _detail('Sexo', _text(patient['sex'])),
              _detail('Carnet PAI', _text(patient['vaccinationCardType'])),
            ],
          ),
          const Divider(height: 28),
          const Text(
            'Atenciones y dosis',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (!widget.session.canReadHistory)
            const Text(
              'Tu perfil puede buscar al paciente, pero no tiene ATTENTION_READ para ver sus atenciones.',
              style: TextStyle(color: AppColors.slate),
            )
          else if (result == null)
            const Center(child: CircularProgressIndicator())
          else
            FutureBuilder<List<Map<String, dynamic>>>(
              future: result,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return const Text(
                    'No se pudieron consultar las atenciones. Revisa ATTENTION_READ y vuelve a seleccionar el paciente.',
                    style: TextStyle(color: AppColors.danger),
                  );
                }
                final attentions = snapshot.data ?? const [];
                if (attentions.isEmpty) {
                  return const Text(
                    'No hay atenciones asociadas a este paciente.',
                    style: TextStyle(color: AppColors.slate),
                  );
                }
                return Column(
                  children: [
                    for (final attention in attentions)
                      _attentionTile(attention),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _attentionTile(Map<String, dynamic> attention) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: ExpansionTile(
      title: Text(
        'Atención ${_text(attention['consecutive']?.toString(), _text(attention['id']))}',
      ),
      subtitle: Text(
        '${_text(attention['attentionDate'])} · ${_text(attention['status'])}',
      ),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      children: [
        for (final dose
            in (attention['doses'] is List
                ? attention['doses'] as List
                : const []))
          if (dose is Map)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.vaccines_outlined,
                color: AppColors.primary,
                size: 19,
              ),
              title: Text(_text(dose['vaccineNameSnapshot'])),
              subtitle: Text(
                '${_text(dose['doseLabelSnapshot'])} · '
                'Lote ${_text(dose['lotNumber'])} · '
                '${_text(dose['status'])}',
              ),
            ),
      ],
    ),
  );

  Widget _reports() {
    if (!widget.session.canReadHistory) {
      return _messagePanel(
        'Permiso requerido',
        'ATTENTION_READ es necesario para consultar el resumen y generar el reporte.',
        Icons.lock_outline,
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionHeading(
          'Centro de reportes PAI',
          'Registro diario institucional · Excel o CSV',
          Icons.file_download_outlined,
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final controls = [
                OutlinedButton.icon(
                  onPressed: () => _chooseRange(report: true),
                  icon: const Icon(Icons.date_range_rounded),
                  label: Text(
                    '${_date(_reportRange.start)} – ${_date(_reportRange.end)}',
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: DropdownButtonFormField<String>(
                    value: _reportFormat,
                    decoration: const InputDecoration(
                      labelText: 'Formato',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'xlsx',
                        child: Text('Excel (.xlsx)'),
                      ),
                      DropdownMenuItem(value: 'csv', child: Text('CSV (.csv)')),
                    ],
                    onChanged: _downloading
                        ? null
                        : (value) {
                            if (value != null)
                              setState(() => _reportFormat = value);
                          },
                  ),
                ),
                FilledButton.icon(
                  onPressed: _downloading ? null : _downloadReport,
                  icon: _downloading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.download_rounded),
                  label: Text(
                    _downloading ? 'Generando…' : 'Generar y descargar',
                  ),
                ),
              ];
              if (constraints.maxWidth < 760) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    controls[0],
                    const SizedBox(height: 12),
                    controls[1],
                    const SizedBox(height: 12),
                    controls[2],
                  ],
                );
              }
              return Wrap(spacing: 12, runSpacing: 10, children: controls);
            },
          ),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Map<String, dynamic>>(
          future: _reportSummary,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return _messagePanel(
                'Resumen del período',
                'Cargando los totales disponibles para este rango.',
                Icons.hourglass_empty_rounded,
                loading: true,
              );
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return _messagePanel(
                'No se pudo consultar el resumen',
                'El reporte puede reintentarse cuando la conexión esté disponible.',
                Icons.cloud_off_outlined,
                action: OutlinedButton(
                  onPressed: () => setState(_loadReportSummary),
                  child: const Text('Reintentar'),
                ),
              );
            }
            final summary = snapshot.data!;
            return LayoutBuilder(
              builder: (context, constraints) {
                final columns = constraints.maxWidth >= 900 ? 3 : 2;
                final width =
                    (constraints.maxWidth - (columns - 1) * 12) / columns;
                return Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _summary(
                      width,
                      'Pacientes con dosis',
                      '${summary['patientsCount']}',
                      Icons.people_alt_outlined,
                    ),
                    _summary(
                      width,
                      'Dosis registradas',
                      '${summary['dosesCount']}',
                      Icons.vaccines_outlined,
                    ),
                    _summary(
                      width,
                      'Tipos de biológico',
                      '${summary['vaccineTypesCount']}',
                      Icons.category_outlined,
                    ),
                  ],
                );
              },
            );
          },
        ),
        const SizedBox(height: 14),
        const Text(
          'El archivo puede contener información clínica identificable. Descárgalo solo en un equipo autorizado.',
          style: TextStyle(color: AppColors.slate, fontSize: 12),
        ),
      ],
    );
  }

  Widget _sectionHeading(String title, String subtitle, IconData icon) => Row(
    children: [
      Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
                fontSize: 16,
              ),
            ),
            Text(
              subtitle,
              style: const TextStyle(color: AppColors.slate, fontSize: 12),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _summary(double width, String title, String value, IconData icon) =>
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
                      title,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: 19,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _detail(String label, String value) => RichText(
    text: TextSpan(
      style: const TextStyle(color: AppColors.slate, fontSize: 12),
      children: [
        TextSpan(
          text: '$label: ',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        TextSpan(text: value),
      ],
    ),
  );

  Widget _messagePanel(
    String title,
    String detail,
    IconData icon, {
    Widget? action,
    bool loading = false,
  }) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        if (loading)
          const SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Icon(icon, color: AppColors.primary, size: 30),
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
        if (action != null) ...[const SizedBox(height: 12), action],
      ],
    ),
  );
}
