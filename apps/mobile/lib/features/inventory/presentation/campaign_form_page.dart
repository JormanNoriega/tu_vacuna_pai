import 'package:flutter/material.dart';

import '../../../core/utils/uuid.dart';
import 'inventory_controller.dart';

class CampaignFormPage extends StatefulWidget {
  const CampaignFormPage({
    super.key,
    required this.controller,
    required this.institutionId,
  });
  final InventoryController controller;
  final String institutionId;
  @override
  State<CampaignFormPage> createState() => _CampaignFormPageState();
}

class _CampaignFormPageState extends State<CampaignFormPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final location = TextEditingController();
  final id = uuidV4();
  DateTimeRange? dates;
  Map<String, dynamic>? request;
  bool busy = false;

  @override
  void dispose() {
    name.dispose();
    location.dispose();
    super.dispose();
  }

  String? requiredText(String? v) =>
      v == null || v.trim().isEmpty ? 'Este dato es obligatorio.' : null;

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (dates == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona las fechas de la jornada.')),
      );
      return;
    }
    request ??= {
      'id': id,
      'name': name.text.trim().isEmpty
          ? 'Jornada · ${location.text.trim()}'.substring(
              0,
              ('Jornada · ${location.text.trim()}').length.clamp(0, 200),
            )
          : name.text.trim(),
      'location': location.text.trim(),
      'startsOn': dates!.start.toIso8601String().substring(0, 10),
      'endsOn': dates!.end.toIso8601String().substring(0, 10),
    };
    setState(() => busy = true);
    final ok = await widget.controller.post(
      widget.institutionId,
      'campaigns',
      request!,
    );
    if (!mounted) return;
    setState(() => busy = false);
    if (ok) Navigator.pop(context, {...request!, 'status': 'ACTIVE'});
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Nueva jornada')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Primero define el lugar y las fechas. Después elige vacunadores y asigna sus vacunas.',
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: location,
              enabled: request == null,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Lugar',
                hintText: 'Ej.: Centro de salud o barrio',
              ),
              validator: requiredText,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: request != null
                  ? null
                  : () async {
                      final selected = await showDatePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                        initialDate: dates?.start ?? DateTime.now(),
                      );
                      if (selected != null && mounted) {
                        setState(
                          () => dates = DateTimeRange(
                            start: selected,
                            end: selected,
                          ),
                        );
                      }
                    },
              icon: const Icon(Icons.date_range),
              label: Text(
                dates == null
                    ? 'Seleccionar fecha'
                    : dates!.start == dates!.end
                    ? '${dates!.start.day}/${dates!.start.month}/${dates!.start.year}'
                    : '${dates!.start.day}/${dates!.start.month}/${dates!.start.year} — ${dates!.end.day}/${dates!.end.month}/${dates!.end.year}',
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: request != null
                    ? null
                    : () async {
                        final selected = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                          initialDateRange: dates,
                        );
                        if (selected != null && mounted) {
                          setState(() => dates = selected);
                        }
                      },
                child: const Text('¿La jornada dura varios días?'),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: name,
              enabled: request == null,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Nombre de la jornada (opcional)',
                helperText: 'Si lo dejas vacío, usaremos el lugar.',
              ),
            ),
            if (widget.controller.error != null && request != null) ...[
              Text(
                widget.controller.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              const Text(
                'Si la respuesta se interrumpió, verifica la lista antes de crear otra jornada.',
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: busy ? null : submit,
              child: Text(
                busy
                    ? 'Guardando…'
                    : request == null
                    ? 'Guardar y elegir vacunadores'
                    : 'Reintentar misma operación',
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
