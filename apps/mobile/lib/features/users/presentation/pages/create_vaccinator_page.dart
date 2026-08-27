import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/document_normalizer.dart';
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

class _ProfessionOption {
  const _ProfessionOption({
    required this.code,
    required this.label,
    required this.requiresRegistration,
  });

  final String code;
  final String label;
  final bool requiresRegistration;
}

class _CreateVaccinatorPageState extends State<CreateVaccinatorPage> {
  static const _documentTypes = ['CC', 'TI', 'CE', 'PASAPORTE'];

  static const _professions = [
    _ProfessionOption(
      code: 'MEDICO',
      label: 'Medico',
      requiresRegistration: true,
    ),
    _ProfessionOption(
      code: 'ENFERMERO',
      label: 'Enfermero(a)',
      requiresRegistration: true,
    ),
    _ProfessionOption(
      code: 'AUXILIAR_ENFERMERIA',
      label: 'Auxiliar de enfermeria',
      requiresRegistration: false,
    ),
    _ProfessionOption(
      code: 'ODONTOLOGO',
      label: 'Odontologo',
      requiresRegistration: true,
    ),
    _ProfessionOption(
      code: 'BACTERIOLOGO',
      label: 'Bacteriologo',
      requiresRegistration: true,
    ),
    _ProfessionOption(
      code: 'PROMOTOR_SALUD',
      label: 'Promotor de salud',
      requiresRegistration: false,
    ),
    _ProfessionOption(
      code: 'OTRO',
      label: 'Otro',
      requiresRegistration: false,
    ),
  ];

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _documentNumberController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _registrationNumberController = TextEditingController();
  final _registrationTypeController = TextEditingController();
  bool _obscurePassword = true;
  bool _submitting = false;

  String? _documentType;
  String? _gender;
  _ProfessionOption? _profession;
  DateTime? _birthDate;

  bool get _showRegistration =>
      _profession != null && _profession!.requiresRegistration;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _documentNumberController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    _registrationNumberController.dispose();
    _registrationTypeController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Fecha de nacimiento',
    );
    if (picked == null) return;
    setState(() {
      _birthDate = picked;
      _birthDateController.text = _formatDate(picked);
    });
  }

  static String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
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
      documentType: _documentType!,
      documentNumber: DocumentNormalizer.normalize(
        _documentNumberController.text,
      )!,
      phone: _phoneController.text.trim(),
      birthDate: _birthDate == null ? null : _formatDate(_birthDate!),
      gender: _gender,
      professionCode: _profession!.code,
      professionalRegistrationNumber: _showRegistration
          ? DocumentNormalizer.normalize(_registrationNumberController.text)
          : null,
      professionalRegistrationType: _showRegistration
          ? _registrationTypeController.text.trim()
          : null,
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
                        DropdownButtonFormField<String>(
                          initialValue: _documentType,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de documento',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: [
                            for (final type in _documentTypes)
                              DropdownMenuItem(
                                value: type,
                                child: Text(_documentTypeLabel(type)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _documentType = value),
                          validator: (value) => value == null
                              ? 'Selecciona el tipo de documento.'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _documentNumberController,
                          keyboardType: TextInputType.text,
                          textCapitalization: TextCapitalization.characters,
                          decoration: const InputDecoration(
                            labelText: 'Numero de documento',
                            helperText:
                                'Sin espacios, puntos ni guiones. Se guarda en '
                                'forma canonica.',
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (value) {
                            final normalized = DocumentNormalizer.normalize(
                              value,
                            );
                            if (normalized == null) {
                              return 'Ingresa el numero de documento.';
                            }
                            if (!DocumentNormalizer.isValidForType(
                              normalized,
                              _documentType,
                            )) {
                              return 'El numero no es valido para el tipo '
                                  'seleccionado.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Telefono (opcional)',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          validator: (value) {
                            final v = value?.trim() ?? '';
                            if (v.isEmpty) return null;
                            if (!RegExp(r'^[0-9+ ()-]{6,20}$').hasMatch(v)) {
                              return 'Ingresa un telefono valido.';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _birthDateController,
                          readOnly: true,
                          onTap: _pickBirthDate,
                          decoration: const InputDecoration(
                            labelText: 'Fecha de nacimiento (opcional)',
                            prefixIcon: Icon(Icons.cake_outlined),
                            suffixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: const InputDecoration(
                            labelText: 'Genero (opcional)',
                            prefixIcon: Icon(Icons.wc_rounded),
                          ),
                          items: [
                            for (final gender in const [
                              'FEMALE',
                              'MALE',
                              'OTHER',
                            ])
                              DropdownMenuItem(
                                value: gender,
                                child: Text(_genderLabel(gender)),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _gender = value),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<_ProfessionOption>(
                          initialValue: _profession,
                          decoration: const InputDecoration(
                            labelText: 'Profesion / cargo',
                            prefixIcon: Icon(Icons.work_outline_rounded),
                          ),
                          items: [
                            for (final profession in _professions)
                              DropdownMenuItem(
                                value: profession,
                                child: Text(profession.label),
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _profession = value),
                          validator: (value) => value == null
                              ? 'Selecciona la profesion.'
                              : null,
                        ),
                        if (_showRegistration) ...[
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _registrationNumberController,
                            textCapitalization: TextCapitalization.characters,
                            decoration: InputDecoration(
                              labelText: 'Registro profesional',
                              helperText:
                                  'Requerido para ${_profession!.label}. '
                                  'Sin espacios, puntos ni guiones.',
                              prefixIcon: const Icon(Icons.verified_outlined),
                            ),
                            validator: (value) {
                              final normalized = DocumentNormalizer.normalize(
                                value,
                              );
                              if (normalized == null) {
                                return 'Ingresa el registro profesional.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _registrationTypeController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Tipo de registro (opcional)',
                              helperText:
                                  'Ej: Registro ministerial, tarjeta profesional.',
                              prefixIcon: Icon(Icons.description_outlined),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Contrasena temporal',
                            helperText:
                                'Minimo 8 caracteres. Se la compartes al nuevo vacunador.',
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

  static String _documentTypeLabel(String type) => switch (type) {
    'CC' => 'Cedula de ciudadania',
    'TI' => 'Tarjeta de identidad',
    'CE' => 'Cedula de extranjeria',
    'PASAPORTE' => 'Pasaporte',
    _ => type,
  };

  static String _genderLabel(String gender) => switch (gender) {
    'FEMALE' => 'Femenino',
    'MALE' => 'Masculino',
    'OTHER' => 'Otro',
    _ => gender,
  };
}