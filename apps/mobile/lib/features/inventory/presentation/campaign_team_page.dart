import 'package:flutter/material.dart';

import 'inventory_controller.dart';
import 'delivery_ui.dart';

class CampaignTeamPage extends StatefulWidget {
  const CampaignTeamPage({
    super.key,
    required this.controller,
    required this.institutionId,
    required this.campaignId,
    required this.participantIds,
  });
  final InventoryController controller;
  final String institutionId;
  final String campaignId;
  final Set<String> participantIds;

  @override
  State<CampaignTeamPage> createState() => _CampaignTeamPageState();
}

class _CampaignTeamPageState extends State<CampaignTeamPage> {
  final _selected = <String>{};
  late final Set<String> _existing = {...widget.participantIds};
  List<Map<String, dynamic>> _people = [];
  String? _error;
  bool _loading = true;
  bool _busy = false;
  bool _attempted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await widget.controller.loadVaccinators(widget.institutionId);
    if (!mounted) return;
    setState(() {
      _people = List.of(widget.controller.vaccinators);
      _error = widget.controller.error;
      _loading = false;
    });
  }

  Future<void> _save() async {
    if (_busy || _selected.isEmpty) return;
    setState(() {
      _busy = true;
      _attempted = true;
      _error = null;
    });
    for (final id in _selected.toList()) {
      final ok = await widget.controller.post(
        widget.institutionId,
        'campaigns/${widget.campaignId}/participants',
        {'vaccinatorId': id},
      );
      if (!mounted) return;
      if (!ok) {
        setState(() {
          _busy = false;
          _error =
              widget.controller.error ?? 'No se pudo agregar al vacunador.';
        });
        return;
      }
      setState(() {
        _existing.add(id);
        _selected.remove(id);
      });
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: const Text('Elegir vacunadores')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        Text(
                          '¿Quiénes participan?',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Selecciona el equipo. Después podrás asignar vacunas y frascos a cada persona.',
                        ),
                        const SizedBox(height: 16),
                        if (_error != null) ...[
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                          if (!_attempted)
                            TextButton(
                              onPressed: _load,
                              child: const Text('Reintentar'),
                            ),
                          if (_attempted)
                            const Text(
                              'Los vacunadores agregados ya están guardados. Reintenta para completar los pendientes.',
                            ),
                        ],
                        if (_people.isEmpty && _error == null)
                          const DeliveryEmptyState(
                            title: 'No hay vacunadores activos',
                            message: 'Revisa los usuarios de la institución antes de organizar el equipo.',
                          ),
                        for (final person in _people)
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text('${person['fullName']}'),
                            subtitle: _existing.contains(person['id'])
                                ? const Text('Ya participa en esta jornada')
                                : null,
                            value:
                                _existing.contains(person['id']) ||
                                _selected.contains(person['id']),
                            onChanged:
                                _busy ||
                                    _existing.contains(person['id']) ||
                                    (_error != null && !_attempted)
                                ? null
                                : (value) => setState(() {
                                    if (value == true) {
                                      _selected.add(person['id'] as String);
                                    } else {
                                      _selected.remove(person['id']);
                                    }
                                  }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _busy ||
                                _selected.isEmpty ||
                                (_error != null && !_attempted)
                            ? null
                            : _save,
                        child: Text(
                          _busy
                              ? 'Guardando equipo…'
                              : _attempted
                              ? 'Reintentar pendientes'
                              : 'Agregar ${_selected.length} ${_selected.length == 1 ? 'vacunador' : 'vacunadores'}',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    ),
  );
}
