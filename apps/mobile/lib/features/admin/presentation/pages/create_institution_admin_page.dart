import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../admin_controller.dart';

/// Formulario para crear un ADMIN_INSTITUTION para una institucion existente.
class CreateInstitutionAdminPage extends StatefulWidget {
  const CreateInstitutionAdminPage({required this.controller, super.key});

  final AdminController controller;

  @override
  State<CreateInstitutionAdminPage> createState() =>
      _CreateInstitutionAdminPageState();
}

class _CreateInstitutionAdminPageState extends State<CreateInstitutionAdminPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;
  String? _selectedInstitutionId;

  @override
  void initState() {
    super.initState();
    if (widget.controller.institutions.isNotEmpty) {
      _selectedInstitutionId = widget.controller.institutions.first.id;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (_selectedInstitutionId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Primero crea una institucion.')),
      );
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _submitting = true);

    final created = await widget.controller.createInstitutionAdmin(
      email: _emailController.text.trim(),
      fullName: _nameController.text.trim(),
      institutionId: _selectedInstitutionId!,
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
      appBar: AppBar(title: const Text('Crear usuario admin')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: AnimatedBuilder(
                animation: widget.controller,
                builder: (context, _) {
                  if (widget.controller.institutions.isEmpty) {
                    return const _NoInstitutionsHint();
                  }

                  return Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Administrador de institucion',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Crea la cuenta del administrador que gestionara la institucion seleccionada.',
                          style: TextStyle(color: AppColors.slate, height: 1.4),
                        ),
                        const SizedBox(height: 24),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedInstitutionId,
                          decoration: const InputDecoration(
                            labelText: 'Institucion',
                            prefixIcon: Icon(Icons.account_balance_rounded),
                          ),
                          items: [
                            for (final institution
                                in widget.controller.institutions)
                              DropdownMenuItem(
                                value: institution.id,
                                child: Text(
                                  '${institution.name} (${institution.code})',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _selectedInstitutionId = value),
                          validator: (value) => value == null
                              ? 'Selecciona una institucion.'
                              : null,
                        ),
                        const SizedBox(height: 16),
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
                            helperText:
                                'Minimo 8 caracteres. Se la compartes al nuevo administrador.',
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
                              : const Text('Crear usuario admin'),
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

class _NoInstitutionsHint extends StatelessWidget {
  const _NoInstitutionsHint();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.account_balance_outlined,
          size: 56,
          color: AppColors.hint,
        ),
        const SizedBox(height: 16),
        const Text(
          'Primero crea una institucion para poder asignarle un administrador.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.slate, height: 1.4),
        ),
      ],
    );
  }
}