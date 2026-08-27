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
  final key = GlobalKey<FormState>();
  late final TextEditingController name;
  late final TextEditingController code;
  late final TextEditingController doses;
  late final TextEditingController min;
  late final TextEditingController max;
  String category = 'Programa Ampliado de Inmunización (PAI)';
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
  @override
  void initState() {
    super.initState();
    final v = widget.vaccine;
    name = TextEditingController(text: v?.name);
    code = TextEditingController(text: v?.code);
    doses = TextEditingController(text: '${v?.maxDoses ?? 1}');
    min = TextEditingController(text: v?.minAgeMonths?.toString());
    max = TextEditingController(text: v?.maxAgeMonths?.toString());
    category = v?.category ?? category;
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
                DropdownMenuItem(
                  value: 'Programa Ampliado de Inmunización (PAI)',
                  child: Text('PAI'),
                ),
                DropdownMenuItem(value: 'Especial', child: Text('Especial')),
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
