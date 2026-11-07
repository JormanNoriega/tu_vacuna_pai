import 'package:flutter/material.dart';

import '../../../../../app/theme/app_theme.dart';
import '../../../../../core/utils/field_input.dart';
import '../../../../catalogs/domain/entities/catalog_entities.dart';
import 'form_helpers.dart';
import 'staged_dose_data.dart';

/// Paso 4: Revisar y Confirmar.
/// Muestra un resumen detallado de los datos del paciente, dosis a aplicar,
/// captura el estado de reporte PAIWEB y observaciones finales.
class Step4ReviewStep extends StatelessWidget {
  const Step4ReviewStep({
    required this.attentionDate,
    required this.documentType,
    required this.documentNumber,
    required this.firstName,
    required this.secondName,
    required this.lastName,
    required this.secondLastName,
    required this.birthDate,
    required this.completeScheme,
    required this.sex,
    required this.birthCountryName,
    required this.birthPlace,
    required this.departmentName,
    required this.municipalityName,
    required this.address,
    required this.affiliationRegime,
    required this.selectedInsurer,
    this.vaccinationCardType,
    required this.cellphone,
    required this.email,
    required this.stagedDoses,
    required this.paiwebRegistered,
    required this.onPaiwebRegisteredChanged,
    required this.paiwebReasonController,
    required this.observationsController,
    this.latitude,
    this.longitude,
    super.key,
  });

  final DateTime attentionDate;
  final String documentType;
  final String documentNumber;
  final String firstName;
  final String secondName;
  final String lastName;
  final String secondLastName;
  final DateTime? birthDate;
  final bool completeScheme;

  final String? sex;
  final String? birthCountryName;
  final String? birthPlace;
  final String? departmentName;
  final String? municipalityName;
  final String? address;
  final String? affiliationRegime;
  final HealthInsurer? selectedInsurer;
  final String? vaccinationCardType;
  final String? cellphone;
  final String? email;

  final List<StagedDose> stagedDoses;
  final bool paiwebRegistered;
  final ValueChanged<bool> onPaiwebRegisteredChanged;
  final TextEditingController paiwebReasonController;
  final TextEditingController observationsController;
  final double? latitude;
  final double? longitude;

  String get _fullName => [
    firstName,
    secondName,
    lastName,
    secondLastName,
  ].where((s) => s.trim().isNotEmpty).join(' ').trim();

  String _formatSex(String? val) {
    return switch (val) {
      'FEMALE' => 'Mujer',
      'MALE' => 'Hombre',
      'INDETERMINATE' => 'Indeterminado',
      _ => 'No especificado',
    };
  }

  String _formatCarnet(String? code) {
    if (code == null || code.isEmpty) return 'No especificado';
    return switch (code) {
      'CARNE_VACUNACION_INFANTIL' ||
      'carneVacunacionInfantil' => 'Carné de Vacunación Infantil',
      'CARNE_VACUNACION_ADULTOS' ||
      'carneVacunacionAdultos' => 'Carné/Certificado de Vacunación de Adultos',
      'CARNE_VACUNACION_INTERNACIONAL' || 'carneVacunacionInternacional' =>
        'Carné/Certificado Internacional de Vacunación',
      'TARJETAS_UNIFICADAS_VACUNACION_ADULTOS' ||
      'tarjetasUnificadasVacunacionAdultos' =>
        'Tarjetas Unificadas de Vacunación - TUV Adultos',
      'TARJETAS_UNIFICADAS_VACUNACION_NINOS' ||
      'tarjetasUnificadasVacunacionNinos' =>
        'Tarjetas Unificadas de Vacunación - TUV Niños',
      _ => code,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        // Header
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Revisar y Confirmar',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Verifique la información antes de guardar la atención.',
                style: TextStyle(color: AppColors.slate, fontSize: 13.5),
              ),
            ],
          ),
        ),

        // SECCIÓN 1: DATOS BÁSICOS
        FormCard(
          title: 'Datos Básicos del Paciente',
          icon: Icons.person_outline_rounded,
          child: Column(
            children: [
              _infoRow('Fecha de Atención', formatDisplayDate(attentionDate)),
              _infoRow('Tipo de Documento', documentType),
              _infoRow('Número de Documento', documentNumber),
              _infoRow(
                'Nombre Completo',
                _fullName.isNotEmpty ? _fullName : 'No especificado',
              ),
              _infoRow(
                'Fecha de Nacimiento',
                birthDate != null
                    ? formatDisplayDate(birthDate!)
                    : 'No especificada',
              ),
              if (birthDate != null) ...[
                Builder(
                  builder: (ctx) {
                    final age = calculateDetailedAge(birthDate!);
                    return _infoRow(
                      'Edad Calculada',
                      '${age['years']} años, ${age['months']} meses, ${age['days']} días',
                    );
                  },
                ),
              ],
              _infoRow('¿Esquema Completo?', completeScheme ? 'Sí' : 'No'),
            ],
          ),
        ),

        // SECCIÓN 2: DATOS ADICIONALES
        FormCard(
          title: 'Datos Sociodemográficos y Residencia',
          icon: Icons.badge_outlined,
          child: Column(
            children: [
              _infoRow('Sexo', _formatSex(sex)),
              _infoRow(
                'País de Nacimiento',
                birthCountryName != null && birthCountryName!.isNotEmpty
                    ? birthCountryName!
                    : 'Colombia',
              ),
              if (birthPlace != null && birthPlace!.isNotEmpty)
                _infoRow('Lugar de Nacimiento', birthPlace!),
              _infoRow(
                'Ubicación',
                [
                  departmentName,
                  municipalityName,
                ].where((s) => s != null && s.isNotEmpty).join(' - '),
              ),
              if (address != null && address!.isNotEmpty)
                _infoRow('Dirección', address!),
              if (affiliationRegime != null && affiliationRegime!.isNotEmpty)
                _infoRow('Régimen', affiliationRegime!),
              if (vaccinationCardType != null &&
                  vaccinationCardType!.isNotEmpty)
                _infoRow('Tipo de Carnet', _formatCarnet(vaccinationCardType)),
              if (selectedInsurer != null)
                _infoRow(
                  'Aseguradora / EPS',
                  '${selectedInsurer!.code} - ${selectedInsurer!.name}',
                ),
              if (cellphone != null && cellphone!.isNotEmpty)
                _infoRow('Teléfono Celular', cellphone!),
              if (email != null && email!.isNotEmpty)
                _infoRow('Correo Electrónico', email!),
            ],
          ),
        ),

        // SECCIÓN 3: VACUNAS Y DOSIS A APLICAR
        FormCard(
          title: 'Biológicos y Dosis a Registrar',
          icon: Icons.vaccines_rounded,
          child: stagedDoses.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.warningSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppColors.warning.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.warning,
                        size: 20,
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'No se configuró ninguna dosis en el Paso 3. Puedes volver atrás para agregarla o registrar la atención sin dosis.',
                          style: TextStyle(color: AppColors.ink, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: stagedDoses
                      .map((dose) => _buildDoseSummaryTile(dose))
                      .toList(),
                ),
        ),

        // SECCIÓN 4: CIERRE DEL REGISTRO PAIWEB
        FormCard(
          title: 'Cierre del Registro PAIWEB',
          icon: Icons.done_all_rounded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  '¿El registro fue ingresado al aplicativo PAIWEB?',
                ),
                value: paiwebRegistered,
                onChanged: onPaiwebRegisteredChanged,
              ),
              if (!paiwebRegistered) ...[
                const SizedBox(height: 8),
                TextFormField(
                  controller: paiwebReasonController,
                  maxLines: 2,
                  inputFormatters: maxLengthFormatters(FieldLimits.reason),
                  decoration: const InputDecoration(
                    labelText: 'Motivo de no ingreso al PAIWEB *',
                    helperText: 'Mínimo 5 caracteres.',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 8),
              TextFormField(
                controller: observationsController,
                maxLines: 3,
                inputFormatters: maxLengthFormatters(
                  FieldLimits.attentionObservations,
                ),
                decoration: const InputDecoration(
                  labelText:
                      'Observaciones Generales de la Atención (opcional)',
                  hintText: 'Detalles clínicos o administrativos de la visita',
                ),
              ),
            ],
          ),
        ),

        // Warning Banner
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.orange.withValues(alpha: 0.35)),
          ),
          child: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 22),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verifique que todos los datos sean correctos antes de confirmar el registro.',
                  style: TextStyle(color: AppColors.ink, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDoseSummaryTile(StagedDose dose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.vaccines, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${dose.vaccineName} - ${dose.doseDisplayName}',
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _infoRow(
            'Lote',
            dose.lotNumber.isNotEmpty ? dose.lotNumber : 'Sin lote',
          ),
          _infoRow(
            'Fecha de Aplicación',
            formatDisplayDate(dose.applicationDate),
          ),
          if (dose.laboratoryName != null)
            _infoRow('Laboratorio', dose.laboratoryName!),
          if (dose.syringeName != null) _infoRow('Jeringa', dose.syringeName!),
          if (dose.syringeLot != null && dose.syringeLot!.isNotEmpty)
            _infoRow('Lote Jeringa', dose.syringeLot!),
          if (dose.customObservation != null &&
              dose.customObservation!.isNotEmpty)
            _infoRow('Observación', dose.customObservation!),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 135,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : 'No especificado',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
