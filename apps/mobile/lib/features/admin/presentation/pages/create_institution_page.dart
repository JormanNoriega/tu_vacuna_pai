import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../admin_controller.dart';

/// Formulario para crear una institucion (SUPER_ADMIN).
class CreateInstitutionPage extends StatefulWidget {
  const CreateInstitutionPage({
    required this.controller,
    required this.offline,
    super.key,
  });

  final AdminController controller;

  /// Estado de sesion actual para aplicar la politica offline a la escritura.
  final OfflineAccess offline;

  @override
  State<CreateInstitutionPage> createState() => _CreateInstitutionPageState();
}

class _CreateInstitutionPageState extends State<CreateInstitutionPage> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final _nameController = TextEditingController();
  final _offlineController = TextEditingController(text: '72');
  bool _submitting = false;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    _offlineController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final offline = int.tryParse(_offlineController.text.trim());
    setState(() => _submitting = true);

    final created = await widget.controller.createInstitution(
      offline: widget.offline,
      code: _codeController.text.trim(),
      name: _nameController.text.trim(),
      offlineWindowHours: offline,
    );

    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(created);
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear institucion')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) => Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Nueva institucion',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'La institucion se crea activa y lista para asignarle un administrador.',
                        style: TextStyle(color: AppColors.slate, height: 1.4),
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _codeController,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Codigo',
                          hintText: 'HOSP-A',
                          prefixIcon: Icon(Icons.tag_rounded),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Ingresa un codigo.';
                          if (v.length > 32) {
                            return 'El codigo no puede superar 32 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nameController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          hintText: 'Hospital de la Comunidad',
                          prefixIcon: Icon(Icons.account_balance_rounded),
                        ),
                        validator: (value) {
                          final v = value?.trim() ?? '';
                          if (v.isEmpty) return 'Ingresa el nombre.';
                          if (v.length > 200) {
                            return 'El nombre no puede superar 200 caracteres.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _offlineController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Ventana offline (horas)',
                          helperText: 'Entre 1 y 168 horas. Valor inicial: 72.',
                          prefixIcon: Icon(Icons.cloud_off_outlined),
                        ),
                        validator: (value) {
                          final v = int.tryParse(value?.trim() ?? '');
                          if (v == null || v < 1 || v > 168) {
                            return 'Usa un valor entre 1 y 168 horas.';
                          }
                          return null;
                        },
                      ),
                      if (widget.controller.error != null) ...[
                        const SizedBox(height: 16),
                        Text(
                          widget.controller.error!,
                          style: const TextStyle(
                            color: Color(0xFFB42318),
                            fontSize: 13,
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _submitting ? null : _submit,
                        child: _submitting
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Crear institucion'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
