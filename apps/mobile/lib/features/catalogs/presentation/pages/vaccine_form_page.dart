import 'package:flutter/material.dart';

import '../../../../core/auth/offline_access.dart';
import '../../domain/entities/catalog_entities.dart';
import '../catalog_controller.dart';

class VaccineFormPage extends StatefulWidget {
  const VaccineFormPage({
    required this.controller,
    required this.offline,
    this.vaccine,
    super.key,
  });
  final CatalogController controller;
  final OfflineAccess offline;
  final Vaccine? vaccine;
  @override
  State<VaccineFormPage> createState() => _VaccineFormPageState();
}

class _VaccineFormPageState extends State<VaccineFormPage> {
  static const paiCategory = 'Programa Ampliado de Inmunización (PAI)';
  static const specialCategory = 'Especial';

  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController doses;
  late final TextEditingController min;
  late final TextEditingController max;
  String category = paiCategory;
  final Map<String, bool> flags = {
    'Tiene laboratorio': false,
    'Tiene lote': true,
    'Tiene jeringa': false,
    'Tiene lote de jeringa': false,
    'Tiene diluyente': false,
    'Tiene gotero': false,
    'Tiene tipo neumococo': false,
    'Tiene conteo de frascos': false,
    'Tiene observaciones': false,
  };
  List<VaccineOption> options = [];
  List<VaccineOption> templates = [];
  bool loadingOptions = false;
  @override
  void initState() {
    super.initState();
    final v = widget.vaccine;
    name = TextEditingController(text: v?.name);
    code = TextEditingController(text: v?.code);
    doses = TextEditingController(text: '${v?.maxDoses ?? 1}');
    min = TextEditingController(text: v?.minAgeMonths?.toString());
    max = TextEditingController(text: v?.maxAgeMonths?.toString());
    category = _normalizeCategory(v?.category);
    if (v != null) {
      flags['Tiene laboratorio'] = v.hasLaboratory;
      flags['Tiene lote'] = v.hasLot;
      flags['Tiene jeringa'] = v.hasSyringe;
      flags['Tiene lote de jeringa'] = v.hasSyringeLot;
      flags['Tiene diluyente'] = v.hasDiluent;
      flags['Tiene gotero'] = v.hasDropper;
      flags['Tiene tipo neumococo'] = v.hasPneumococcalType;
      flags['Tiene conteo de frascos'] = v.hasVialCount;
      flags['Tiene observaciones'] = v.hasObservation;
      _loadOptions(v);
    }
  }

  @override
  void dispose() {
    name.dispose();
    code.dispose();
    doses.dispose();
    min.dispose();
    max.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.vaccine == null ? 'Nueva vacuna' : 'Editar vacuna'),
      actions: [
        TextButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: const Text('GUARDAR'),
        ),
      ],
    ),
    body: Form(
      key: key,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          _section('Informacion basica', 'Datos generales de la vacuna', [
            TextFormField(
              controller: name,
              decoration: const InputDecoration(
                labelText: 'Nombre de la vacuna',
              ),
              validator: _required,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: code,
              enabled: widget.vaccine == null,
              decoration: const InputDecoration(labelText: 'Codigo unico'),
              validator: _required,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: category,
              decoration: const InputDecoration(labelText: 'Categoria'),
              items: const [
                DropdownMenuItem(value: paiCategory, child: Text('PAI')),
                DropdownMenuItem(
                  value: specialCategory,
                  child: Text('Especial'),
                ),
              ],
              onChanged: (v) => setState(() => category = v!),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: doses,
              decoration: const InputDecoration(
                labelText: 'Numero maximo de dosis',
              ),
              keyboardType: TextInputType.number,
              validator: _required,
            ),
          ]),
          const SizedBox(height: 16),
          _section('Rango de edad (opcional)', 'Edad recomendada en meses', [
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: min,
                    decoration: const InputDecoration(labelText: 'Edad minima'),
                    keyboardType: TextInputType.number,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: max,
                    decoration: const InputDecoration(labelText: 'Edad maxima'),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
          ]),
          const SizedBox(height: 16),
          _section(
            'Caracteristicas de la vacuna',
            'Selecciona los campos que esta vacuna necesita para el registro.',
            [
              for (final entry in flags.entries)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(entry.key),
                  subtitle: Text(_flagDescription(entry.key)),
                  value: entry.value,
                  onChanged: (value) =>
                      setState(() => flags[entry.key] = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _section(
            'Configuracion clinica y operativa',
            'Las opciones de dosis, neumococo, laboratorio y otros campos se administran despues de crear la vacuna.',
            [
              const ListTile(
                leading: Icon(Icons.info_outline),
                title: Text('Catalogo versionado'),
                subtitle: Text(
                  'Los cambios se validan online y respetan conflictos de version.',
                ),
              ),
            ],
          ),
          if (widget.vaccine != null) ...[
            const SizedBox(height: 16),
            _optionsSection(widget.vaccine!),
          ],
        ],
      ),
    ),
  );
  Widget _section(String title, String subtitle, List<Widget> children) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    ),
  );
  String? _required(String? v) =>
      v == null || v.trim().isEmpty ? 'Campo requerido' : null;

  String _normalizeCategory(String? value) {
    final normalized = value?.trim().toLowerCase();
    return switch (normalized) {
      'especial' => specialCategory,
      'programa ampliado de inmunización (pai)' => paiCategory,
      _ => paiCategory,
    };
  }

  String _flagDescription(String label) => switch (label) {
    'Tiene laboratorio' => 'Fabricante o marca del biologico',
    'Tiene lote' => 'Numero de lote del biologico',
    'Tiene jeringa' => 'Tipo de jeringa utilizada',
    'Tiene lote de jeringa' => 'Numero de lote de la jeringa',
    'Tiene diluyente' => 'Requiere diluyente para preparacion',
    'Tiene gotero' => 'Se aplica con gotero oral',
    'Tiene tipo neumococo' => 'Especificar tipo de vacuna neumococica',
    'Tiene conteo de frascos' => 'Registrar cantidad de frascos usados',
    _ => 'Campo adicional para el registro clinico',
  };

  Widget _optionsSection(Vaccine vaccine) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Opciones del catalogo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 4),
          const Text(
            'Dosis y tipos clinicos configurados para esta vacuna.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 12),
          if (loadingOptions)
            const Center(child: CircularProgressIndicator())
          else if (options.isEmpty && templates.isEmpty)
            const Text('No hay opciones configuradas.')
          else ...[
            for (final option in options) _optionTile(vaccine, option),
            for (final template in templates) _optionTile(vaccine, template),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addOption(vaccine),
                icon: const Icon(Icons.add),
                label: const Text('Agregar opcion'),
              ),
              OutlinedButton.icon(
                onPressed: () => _addTemplate(vaccine),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('Agregar plantilla'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _optionTile(Vaccine vaccine, VaccineOption option) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(
      option.fieldType == 'dose'
          ? Icons.format_list_numbered
          : Icons.auto_awesome,
    ),
    title: Text(option.displayName),
    subtitle: Text(
      '${option.fieldType}${option.isDefault ? '  |  Por defecto' : ''}',
    ),
    trailing: IconButton(
      tooltip: 'Editar opcion',
      icon: const Icon(Icons.edit_outlined),
      onPressed: () => _editOption(vaccine, option),
    ),
  );

  Future<void> _loadOptions(Vaccine vaccine) async {
    setState(() => loadingOptions = true);
    final token = await widget.controller.sessionManager.loadSession();
    if (!mounted || token == null) return;
    try {
      final result = await Future.wait<List<VaccineOption>>([
        widget.controller.repository.listOptions(
          token.accessToken,
          vaccine,
          institutionScoped: false,
          institutionId: '',
        ),
        widget.controller.repository.listTemplates(token.accessToken, vaccine),
      ]);
      if (!mounted) return;
      setState(() {
        options = result[0];
        templates = result[1];
        loadingOptions = false;
      });
    } catch (_) {
      if (mounted) setState(() => loadingOptions = false);
    }
  }

  Future<void> _addOption(Vaccine vaccine) async {
    final value = TextEditingController();
    final fieldType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar opcion'),
        content: TextField(
          controller: value,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre o valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'dose'),
            child: const Text('Dosis'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'pneumococcalType'),
            child: const Text('Tipo neumococo'),
          ),
        ],
      ),
    );
    if (!mounted || fieldType == null || value.text.trim().isEmpty) {
      value.dispose();
      return;
    }
    await widget.controller.addOption(
      vaccine,
      optionPayload(
        fieldType: fieldType,
        value: value.text.trim(),
        isDefault: false,
      ),
      institutionId: '',
      institutionScoped: false,
      offline: widget.offline,
    );
    value.dispose();
    if (mounted) _loadOptions(vaccine);
  }

  Future<void> _editOption(Vaccine vaccine, VaccineOption option) async {
    final value = TextEditingController(text: option.value);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editar opcion'),
        content: TextField(
          controller: value,
          decoration: const InputDecoration(labelText: 'Nombre o valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == true && value.text.trim().isNotEmpty && mounted) {
      await widget.controller.updateOption(
        vaccine,
        option,
        optionPayload(
          fieldType: option.fieldType,
          value: value.text.trim(),
          isDefault: option.isDefault,
          sortOrder: option.sortOrder,
          version: option.version,
        ),
        institutionId: '',
        institutionScoped: false,
        offline: widget.offline,
      );
      _loadOptions(vaccine);
    }
    value.dispose();
  }

  Future<void> _addTemplate(Vaccine vaccine) async {
    final value = TextEditingController();
    final fieldType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Agregar plantilla'),
        content: TextField(
          controller: value,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Nombre o valor'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          for (final type in const [
            'laboratory',
            'syringe',
            'dropper',
            'observation',
          ])
            TextButton(
              onPressed: () => Navigator.pop(context, type),
              child: Text(type),
            ),
        ],
      ),
    );
    if (!mounted || fieldType == null || value.text.trim().isEmpty) {
      value.dispose();
      return;
    }
    await widget.controller.addTemplate(
      vaccine,
      optionPayload(
        fieldType: fieldType,
        value: value.text.trim(),
        isDefault: false,
      ),
      offline: widget.offline,
    );
    value.dispose();
    if (mounted) _loadOptions(vaccine);
  }

  Future<void> _save() async {
    if (!key.currentState!.validate()) return;
    final ok = await widget.controller.save(
      {
        'name': name.text.trim(),
        'code': code.text.trim().toLowerCase(),
        'category': category,
        'maxDoses': int.parse(doses.text),
        'minAgeMonths': int.tryParse(min.text),
        'maxAgeMonths': int.tryParse(max.text),
        'hasLaboratory': flags['Tiene laboratorio'],
        'hasLot': flags['Tiene lote'],
        'hasSyringe': flags['Tiene jeringa'],
        'hasSyringeLot': flags['Tiene lote de jeringa'],
        'hasDiluent': flags['Tiene diluyente'],
        'hasDropper': flags['Tiene gotero'],
        'hasPneumococcalType': flags['Tiene tipo neumococo'],
        'hasVialCount': flags['Tiene conteo de frascos'],
        'hasObservation': flags['Tiene observaciones'],
      },
      existing: widget.vaccine,
      offline: widget.offline,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.controller.error ?? 'No se pudo guardar.'),
        ),
      );
    }
  }
}
