import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../users_controller.dart';

/// Formulario para crear un VACCINATOR en la institucion del admin autenticado.
class CreateVaccinatorPage extends StatefulWidget {
  const CreateVaccinatorPage({
    required this.controller,
    required this.offline,
    super.key,
  });

  final UsersController controller;

  /// Estado de sesion actual para aplicar la politica offline a la escritura.
  final OfflineAccess offline;

  @override
  State<CreateVaccinatorPage> createState() => _CreateVaccinatorPageState();
}

class _CreateVaccinatorPageState extends State<CreateVaccinatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final created = await widget.controller.createVaccinator(
      offline: widget.offline,
      email: _emailController.text.trim(),
      fullName: _nameController.text.trim(),
      temporaryPassword: _passwordController.text,
    );

    if (!mounted) return;
    if (created != null) {
      Navigator.of(context).pop(true);
    } else {
      setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear vacunador')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Vacunador de la institucion',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'El vacunador podra iniciar sesion con su correo y la '
                          'contrasena temporal, y trabajara en tu institucion '
                          'con o sin conexion.',
                          style: TextStyle(color: AppColors.slate, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Nombre completo',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return 'Ingresa el nombre completo.';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                            prefixIcon: Icon(Icons.alternate_email_rounded),
                          ),
                          validator: (value) =>
                              value == null || !value.contains('@')
                              ? 'Ingresa un correo valido.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contrasena temporal',
                            helperText: 'Minimo 8 caracteres. Se la compartes al nuevo vacunador.',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Mostrar contrasena'
                                  : 'Ocultar contrasena',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                          validator: (value) {
                            final v = value ?? '';
                            if (v.length < 8) {
                              return 'La contrasena debe tener al menos 8 caracteres.';
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
                              : const Text('Crear vacunador'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
