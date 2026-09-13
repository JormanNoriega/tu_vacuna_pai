import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/clinical_components.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/utils/field_input.dart';
import '../../../attentions/domain/entities/attention.dart';
import '../../../catalogs/domain/entities/catalog_entities.dart';
import '../../../catalogs/domain/entities/geo.dart';
import '../../domain/entities/new_patient.dart';
import '../../domain/entities/patient.dart';
import '../../domain/entities/patient_profile.dart';
import '../patient_detail_controller.dart';

/// Ficha del paciente: ve el perfil completo y permite editar demografia,
/// contacto/direccion y antecedentes.
class PatientDetailPage extends StatefulWidget {
  const PatientDetailPage({
    required this.controller,
    required this.offline,
    required this.patientId,
    super.key,
  });

  final PatientDetailController controller;
  final OfflineAccess offline;
  final String patientId;

  static String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    return '$d/$m/${date.year}';
  }

  static String? _date(DateTime? date) =>
      date == null ? null : _formatDate(date);

  static String _formatIso(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  State<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends State<PatientDetailPage> {
  @override
  void initState() {
    super.initState();
    widget.controller.load(widget.patientId).then((_) {
      if (!mounted) return;
      final profile = widget.controller.profile;
      final departmentId = (profile != null && profile.addresses.isNotEmpty)
          ? profile.addresses.first.departmentId
          : null;
      widget.controller.loadCountries();
      widget.controller.loadDepartments();
      if (departmentId != null) {
        widget.controller.loadMunicipalities(departmentId);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.clearSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ficha del paciente')),
      body: AnimatedBuilder(
        animation: widget.controller,
        builder: (context, _) {
          final controller = widget.controller;
          final profile = controller.profile;
          if (controller.isLoading && profile == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (profile == null) {
            return _errorView(
              controller.error ?? 'No se pudo cargar el paciente.',
            );
          }
          return _content(profile);
        },
      ),
    );
  }

  Widget _errorView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: AppColors.warning, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => widget.controller.load(widget.patientId),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    ),
  );

  BoxDecoration get _cardDecoration => BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: AppColors.border),
  );

  Widget _content(PatientProfile profile) {
    final patient = profile.patient;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        _headerCard(profile),
        if (_hasAlert(profile)) ...[
          const SizedBox(height: 12),
          _alertBanner(profile),
        ],
        const SizedBox(height: 16),
        _identificationSection(profile),
        _complementarySection(profile),
        _affiliationSection(profile),
        _residenceSection(profile),
        _contactSection(profile),
        if (profile.specialConditions != null)
          _specialConditionsSection(profile),
        if (profile.userCondition != null) _userConditionSection(profile),
        _guardianSection(profile),
        _historySection(profile),
        _vaccinationSection(patient),
      ],
    );
  }

  // ---------- header + alertas ----------

  Widget _headerCard(PatientProfile profile) {
    final patient = profile.patient;
    return Container(
      decoration: _cardDecoration,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _avatar(patient.fullName),
              const SizedBox(width: 12),
              Expanded(
                child: IdentityStrip(
                  documentType: patient.documentType,
                  documentNumber: patient.documentNumber,
                  name: patient.fullName,
                ),
              ),
              const SizedBox(width: 8),
              StatusPill(
                label: patient.status == 'ACTIVE' ? 'Activo' : 'Inactivo',
                tone: patient.status == 'ACTIVE'
                    ? StatusTone.applied
                    : StatusTone.neutral,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('Sexo', _sexLabel(patient.sex)),
              _chip(
                'Edad',
                patient.ageYears == null
                    ? 'Sin dato'
                    : '${patient.ageYears} anos',
              ),
              _chip(
                'Nacimiento',
                PatientDetailPage._date(patient.birthDate) ?? 'Sin dato',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final initials = name
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .take(2)
        .map((part) => part[0].toUpperCase())
        .join();
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: AppColors.primarySoft,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials.isEmpty ? '?' : initials,
        style: const TextStyle(
          color: AppColors.primary,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _chip(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label  ',
            style: const TextStyle(
              color: AppColors.hint,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          TextSpan(
            text: value,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );

  bool _hasAlert(PatientProfile profile) => profile.medicalHistories.any(
    (history) => history.hasContraindication || history.hasPreviousReaction,
  );

  Widget _alertBanner(PatientProfile profile) {
    final alerts = <String>[
      for (final history in profile.medicalHistories)
        if (history.hasContraindication)
          'Contraindica la vacunacion'
              '${(history.contraindicationDetails ?? '').isNotEmpty ? ': ${history.contraindicationDetails}' : ''}',
      for (final history in profile.medicalHistories)
        if (history.hasPreviousReaction)
          'Reaccion moderada/severa previa'
              '${(history.reactionDetails ?? '').isNotEmpty ? ': ${history.reactionDetails}' : ''}',
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withValues(alpha: .35)),
      ),
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Alertas de vacunacion',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                for (final alert in alerts)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      alert,
                      style: const TextStyle(
                        color: AppColors.slate,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- secciones ----------

  Widget _section({
    required String index,
    required String title,
    String? subtitle,
    VoidCallback? onEdit,
    required Widget child,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: _cardDecoration,
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SectionHeading(
                index: index,
                title: title,
                subtitle: subtitle,
              ),
            ),
            if (onEdit != null)
              TextButton.icon(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );

  Widget _empty(String message) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      message,
      style: const TextStyle(color: AppColors.hint, fontSize: 13),
    ),
  );

  Widget _identificationSection(PatientProfile profile) {
    final patient = profile.patient;
    return _section(
      index: '01',
      title: 'Identificacion',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Tipo de documento', _docTypeLabel(patient.documentType)),
          _info('Numero de documento', patient.documentNumber, mono: true),
          _info('Primer nombre', patient.firstName),
          _info('Segundo nombre', patient.secondName),
          _info('Primer apellido', patient.lastName),
          _info('Segundo apellido', patient.secondLastName),
          _info(
            'Fecha de nacimiento',
            PatientDetailPage._date(patient.birthDate),
            mono: true,
          ),
          _info('Sexo', _sexLabel(patient.sex)),
        ],
      ),
    );
  }

  Widget _complementarySection(PatientProfile profile) {
    final demographics = profile.demographics;
    final patient = profile.patient;
    return _section(
      index: '02',
      title: 'Datos complementarios',
      onEdit: _editDemographics,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Genero', _genderLabel(demographics?.gender)),
          _info(
            'Orientacion sexual',
            _humanize(demographics?.sexualOrientation),
          ),
          _info('Pertenencia etnica', _humanize(demographics?.ethnicity)),
          _info('Escolaridad', demographics?.educationLevel),
          _info('Tipo de carnet', _carnetLabel(patient.vaccinationCardType)),
          _info('Pais de nacimiento', _countryName(patient.birthCountryId)),
          _info('Estatus migratorio', _humanize(patient.migrationStatus)),
          _info('Lugar de nacimiento', patient.birthPlace),
          _info(
            'Edad gestacional al nacer',
            patient.gestationalAgeAtBirth == null
                ? null
                : '${patient.gestationalAgeAtBirth} semanas',
          ),
        ],
      ),
    );
  }

  Widget _affiliationSection(PatientProfile profile) {
    final affiliation = profile.affiliation;
    return _section(
      index: '03',
      title: 'Afiliacion en salud',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Regimen', _humanize(affiliation?.affiliationRegime)),
          _info('Aseguradora / EPS', affiliation?.insurer),
        ],
      ),
    );
  }

  Widget _residenceSection(PatientProfile profile) {
    final address = profile.addresses.isEmpty ? null : profile.addresses.first;
    return _section(
      index: '04',
      title: 'Residencia',
      onEdit: _editAddress,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Pais', _countryName(address?.countryId)),
          _info('Departamento', _departmentName(address?.departmentId)),
          _info('Municipio', _municipalityName(address?.municipalityId)),
          _info('Comuna / Localidad', address?.locality),
          _info('Area', _humanize(address?.area)),
          _info('Direccion', address?.street),
        ],
      ),
    );
  }

  Widget _contactSection(PatientProfile profile) {
    final landline = _contactByKind(profile, 'LANDLINE');
    final cellphone = _contactByKind(profile, 'CELLPHONE');
    final genericPhone = _contactByKind(profile, null, phonesOnly: true);
    final email = _firstContact(profile, 'EMAIL');
    final patient = profile.patient;
    return _section(
      index: '05',
      title: 'Contacto',
      onEdit: _editContact,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Telefono fijo', landline, mono: true),
          _info('Celular', cellphone, mono: true),
          if (genericPhone != null) _info('Telefono', genericPhone, mono: true),
          _info('Correo electronico', email),
          const SizedBox(height: 2),
          _flagRow(
            'Autoriza llamadas telefonicas',
            patient.authorizeCalls,
            trueTone: StatusTone.applied,
          ),
          _flagRow(
            'Autoriza envio de correo',
            patient.authorizeEmail,
            trueTone: StatusTone.applied,
          ),
        ],
      ),
    );
  }

  Widget _specialConditionsSection(PatientProfile profile) {
    final conditions = profile.specialConditions!;
    return _section(
      index: '06',
      title: 'Condiciones especiales',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _flagRow('Desplazado', conditions.displaced),
          _flagRow('Discapacitado', conditions.disabled),
          _flagRow('Fallecido', conditions.deceased),
          _flagRow(
            'Victima del conflicto armado',
            conditions.armedConflictVictim,
          ),
          _flagRow('Estudia actualmente', conditions.currentlyStudying),
        ],
      ),
    );
  }

  Widget _userConditionSection(PatientProfile profile) {
    final condition = profile.userCondition!;
    return _section(
      index: '07',
      title: 'Condicion de la usuaria',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Condicion', _humanize(condition.userCondition)),
          _info(
            'Fecha ultima menstruacion',
            PatientDetailPage._date(condition.lastMenstrualDate),
            mono: true,
          ),
          _info(
            'Semanas de gestacion',
            condition.gestationWeeks == null
                ? null
                : '${condition.gestationWeeks}',
          ),
          _info(
            'Fecha probable de parto',
            PatientDetailPage._date(condition.probableDeliveryDate),
            mono: true,
          ),
          _info(
            'Embarazos previos',
            condition.previousPregnancies == null
                ? null
                : '${condition.previousPregnancies}',
          ),
          _flagRow('Ha dado a luz', condition.hasGivenBirth),
          _info('Lugar de atencion del parto', condition.birthPlaceDelivery),
        ],
      ),
    );
  }

  Widget _guardianSection(PatientProfile profile) {
    if (profile.guardians.isEmpty) {
      return _section(
        index: '08',
        title: 'Madre / cuidador',
        child: _empty('Sin datos registrados.'),
      );
    }
    return _section(
      index: '08',
      title: 'Madre / cuidador',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < profile.guardians.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            Text(
              _relationshipLabel(profile.guardians[i].relationship),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 10),
            ..._guardianRows(profile.guardians[i]),
          ],
        ],
      ),
    );
  }

  List<Widget> _guardianRows(PatientGuardian guardian) => [
    _info('Nombre completo', guardian.fullName),
    _info('Tipo de documento', _docTypeLabel(guardian.documentType)),
    _info('Numero de documento', guardian.documentNumber, mono: true),
    _info('Telefono fijo', guardian.landline ?? guardian.phone, mono: true),
    _info('Celular', guardian.cellphone, mono: true),
    _info('Correo electronico', guardian.email),
    _info('Regimen', _humanize(guardian.affiliationRegime)),
    _info('Aseguradora / EPS', guardian.insurer),
    _info('Pertenencia etnica', _humanize(guardian.ethnicity)),
    _flagRow('Desplazado', guardian.displaced),
  ];

  Widget _historySection(PatientProfile profile) {
    if (profile.medicalHistories.isEmpty) {
      return _section(
        index: '09',
        title: 'Antecedentes medicos',
        onEdit: _editHistories,
        child: _empty('Sin antecedentes registrados.'),
      );
    }
    return _section(
      index: '09',
      title: 'Antecedentes medicos',
      onEdit: _editHistories,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < profile.medicalHistories.length; i++) ...[
            if (i > 0) const Divider(height: 28),
            Row(
              children: [
                Expanded(
                  child: Text(
                    profile.medicalHistories[i].condition,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (profile.medicalHistories[i].diagnosedAt != null)
                  MonoText(
                    PatientDetailPage._date(
                      profile.medicalHistories[i].diagnosedAt,
                    )!,
                    muted: true,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _info('Tipo', profile.medicalHistories[i].historyType),
            _info('Notas', profile.medicalHistories[i].notes),
            _info(
              'Observaciones especiales',
              profile.medicalHistories[i].specialObservations,
            ),
            if (profile.medicalHistories[i].hasContraindication)
              _flagRow(
                'Contraindica la vacunacion',
                true,
                detail: profile.medicalHistories[i].contraindicationDetails,
                trueTone: StatusTone.cancelled,
              ),
            if (profile.medicalHistories[i].hasPreviousReaction)
              _flagRow(
                'Reaccion moderada/severa previa',
                true,
                detail: profile.medicalHistories[i].reactionDetails,
                trueTone: StatusTone.cancelled,
              ),
          ],
        ],
      ),
    );
  }

  Widget _vaccinationSection(Patient patient) {
    final attentions = widget.controller.attentions;
    final doses = [for (final attention in attentions) ...attention.doses];
    final activeDoses = doses.where((dose) => !dose.isCancelled).toList();
    final lastDate = attentions.isEmpty ? null : attentions.first.attentionDate;
    return _section(
      index: '10',
      title: 'Vacunacion',
      subtitle: 'Resumen de dosis aplicadas (detalle en Historial)',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _info('Tipo de carnet', _carnetLabel(patient.vaccinationCardType)),
          _info('Atenciones', '${attentions.length}'),
          _info('Dosis registradas', '${activeDoses.length}'),
          _info(
            'Ultima aplicacion',
            PatientDetailPage._date(lastDate),
            mono: true,
          ),
          const SizedBox(height: 6),
          if (activeDoses.isEmpty)
            _empty('Sin dosis registradas.')
          else
            for (final dose in activeDoses.take(5)) _doseTile(dose),
        ],
      ),
    );
  }

  Widget _doseTile(AppliedDose dose) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 5),
          decoration: const BoxDecoration(
            color: AppColors.success,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dose.vaccineNameSnapshot,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${dose.doseLabelSnapshot}'
                '${(dose.lotNumber ?? '').isNotEmpty ? '  ·  Lote ${dose.lotNumber}' : ''}',
                style: const TextStyle(color: AppColors.slate, fontSize: 12.5),
              ),
            ],
          ),
        ),
        if (dose.applicationDate != null)
          MonoText(PatientDetailPage._date(dose.applicationDate)!, muted: true),
      ],
    ),
  );

  // ---------- filas ----------

  Widget _info(String label, String? value, {bool mono = false}) {
    final hasValue = value != null && value.trim().isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 132,
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: hasValue
                ? (mono
                      ? MonoText(value, style: const TextStyle(fontSize: 14))
                      : Text(value, style: const TextStyle(height: 1.35)))
                : const Text('—', style: TextStyle(color: AppColors.hint)),
          ),
        ],
      ),
    );
  }

  Widget _flagRow(
    String label,
    bool? value, {
    String? detail,
    StatusTone trueTone = StatusTone.draft,
  }) {
    final text = value == null ? 'Sin dato' : (value ? 'Si' : 'No');
    final tone = value == null
        ? StatusTone.neutral
        : (value ? trueTone : StatusTone.neutral);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.slate,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.3,
              ),
            ),
          ),
          if (detail != null && detail.trim().isNotEmpty) ...[
            Flexible(
              child: Text(
                detail,
                textAlign: TextAlign.right,
                style: const TextStyle(color: AppColors.hint, fontSize: 12),
              ),
            ),
            const SizedBox(width: 8),
          ],
          StatusPill(label: text, tone: tone),
        ],
      ),
    );
  }

  String? _contactByKind(
    PatientProfile profile,
    String? kind, {
    bool phonesOnly = false,
  }) {
    for (final contact in profile.contacts) {
      if (phonesOnly) {
        if (contact.type == 'PHONE' &&
            (contact.phoneKind == null || contact.phoneKind!.isEmpty)) {
          return contact.value;
        }
        continue;
      }
      if (contact.type == 'PHONE' && contact.phoneKind == kind) {
        return contact.value;
      }
    }
    return null;
  }

  // ---------- edicion ----------

  Future<void> _editDemographics() async {
    final current = widget.controller.profile?.demographics;
    final result = await showDialog<_DemographicsResult>(
      context: context,
      builder: (_) => _DemographicsDialog(
        gender: current?.gender,
        ethnicity: current?.ethnicity,
        educationLevel: current?.educationLevel,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveDemographics(
      offline: widget.offline,
      gender: result.gender,
      ethnicity: result.ethnicity,
      educationLevel: result.educationLevel,
    );
    if (mounted) _notify(ok, 'Demografia actualizada.');
  }

  Future<void> _editContact() async {
    final profile = widget.controller.profile!;
    final phone = _firstContact(profile, 'PHONE');
    final email = _firstContact(profile, 'EMAIL');
    final result = await showDialog<_ContactResult>(
      context: context,
      builder: (_) => _ContactDialog(phone: phone, email: email),
    );
    if (result == null || !mounted) return;
    final contacts = <NewPatientContact>[
      if (result.phone != null && result.phone!.isNotEmpty)
        NewPatientContact(type: 'PHONE', value: result.phone!, primary: true),
      if (result.email != null && result.email!.isNotEmpty)
        NewPatientContact(type: 'EMAIL', value: result.email!),
    ];
    final ok = await widget.controller.saveContact(
      offline: widget.offline,
      contacts: contacts,
      addresses: _currentAddresses(profile),
    );
    if (mounted) _notify(ok, 'Contacto actualizado.');
  }

  Future<void> _editAddress() async {
    final profile = widget.controller.profile!;
    final current = profile.addresses.isEmpty ? null : profile.addresses.first;
    await widget.controller.loadDepartments();
    if (!mounted) return;
    final result = await showDialog<_AddressResult>(
      context: context,
      builder: (_) => _AddressDialog(
        controller: widget.controller,
        departmentId: current?.departmentId,
        municipalityId: current?.municipalityId,
        street: current?.street,
      ),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveContact(
      offline: widget.offline,
      contacts: _currentContacts(profile),
      addresses: [
        NewPatientAddress(
          street: result.street,
          departmentId: result.departmentId,
          municipalityId: result.municipalityId,
          countryId: current?.countryId,
        ),
      ],
    );
    if (mounted) _notify(ok, 'Direccion actualizada.');
  }

  Future<void> _editHistories() async {
    final profile = widget.controller.profile!;
    final result = await showDialog<List<NewPatientMedicalHistory>>(
      context: context,
      builder: (_) => _HistoriesDialog(histories: profile.medicalHistories),
    );
    if (result == null || !mounted) return;
    final ok = await widget.controller.saveMedicalHistories(
      offline: widget.offline,
      histories: result,
    );
    if (mounted) _notify(ok, 'Antecedentes actualizados.');
  }

  void _notify(bool ok, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(ok ? message : 'No se pudo guardar el cambio.')),
    );
  }

  List<NewPatientContact> _currentContacts(PatientProfile profile) => [
    for (final contact in profile.contacts)
      NewPatientContact(
        type: contact.type,
        value: contact.value,
        primary: contact.primary,
      ),
  ];

  List<NewPatientAddress> _currentAddresses(PatientProfile profile) => [
    for (final address in profile.addresses)
      NewPatientAddress(
        street: address.street,
        departmentId: address.departmentId,
        municipalityId: address.municipalityId,
        countryId: address.countryId,
        primary: address.primary,
      ),
  ];

  String? _firstContact(PatientProfile profile, String type) {
    for (final contact in profile.contacts) {
      if (contact.type == type) return contact.value;
    }
    return null;
  }

  String? _countryName(String? id) {
    if (id == null) return null;
    for (final country in widget.controller.countries) {
      if (country.id == id) return country.name;
    }
    return null;
  }

  String? _departmentName(String? id) {
    if (id == null) return null;
    for (final department in widget.controller.departments) {
      if (department.id == id) return department.name;
    }
    return null;
  }

  String? _municipalityName(String? id) {
    if (id == null) return null;
    for (final municipality in widget.controller.municipalities) {
      if (municipality.id == id) return municipality.name;
    }
    return null;
  }

  static String _sexLabel(String sex) => switch (sex) {
    'MALE' => 'Masculino',
    'FEMALE' => 'Femenino',
    'INDETERMINATE' => 'Indeterminado',
    _ => sex,
  };

  static String? _genderLabel(String? gender) => switch (gender) {
    'MALE' || 'MASCULINO' => 'Masculino',
    'FEMALE' || 'FEMENINO' => 'Femenino',
    'OTHER' || 'TRANSGENDER' || 'TRANSGENERO' => 'Transgenero',
    'INDETERMINATE' || 'INDETERMINADO' => 'Indeterminado',
    _ => gender,
  };

  static String _relationshipLabel(String relationship) =>
      switch (relationship) {
        'MOTHER' => 'Madre',
        'FATHER' => 'Padre',
        'CAREGIVER' => 'Cuidador',
        'OTHER' => 'Otro',
        _ => relationship,
      };

  static String _docTypeLabel(String? code) {
    if (code == null || code.trim().isEmpty) return code ?? '';
    for (final option in documentTypeFallback) {
      if (option.code == code) return '${option.label} ($code)';
    }
    return code;
  }

  static String _carnetLabel(String? code) => switch (code) {
    'CARNE_VACUNACION_INFANTIL' => 'Carne de vacunacion infantil',
    'CARNE_VACUNACION_ADULTOS' => 'Carne de vacunacion de adultos',
    'CARNE_VACUNACION_INTERNACIONAL' =>
      'Carne/certificado internacional de vacunacion',
    'TARJETAS_UNIFICADAS_VACUNACION_ADULTOS' =>
      'Tarjetas unificadas de vacunacion - adultos',
    'TARJETAS_UNIFICADAS_VACUNACION_NINOS' =>
      'Tarjetas unificadas de vacunacion - ninos',
    null || '' => '',
    _ => code,
  };

  /// Convierte codigos tipo `POBLACION_POBRE_NO_ASEGURADA` en texto legible.
  static String? _humanize(String? code) {
    if (code == null || code.trim().isEmpty) return null;
    final lower = code.replaceAll('_', ' ').toLowerCase();
    return lower[0].toUpperCase() + lower.substring(1);
  }
}

// ---------- dialogs ----------

class _DemographicsResult {
  const _DemographicsResult(this.gender, this.ethnicity, this.educationLevel);
  final String? gender;
  final String? ethnicity;
  final String? educationLevel;
}

class _DemographicsDialog extends StatefulWidget {
  const _DemographicsDialog({this.gender, this.ethnicity, this.educationLevel});

  final String? gender;
  final String? ethnicity;
  final String? educationLevel;

  @override
  State<_DemographicsDialog> createState() => _DemographicsDialogState();
}

class _DemographicsDialogState extends State<_DemographicsDialog> {
  late String? _gender = widget.gender;
  late final TextEditingController _ethnicity = TextEditingController(
    text: widget.ethnicity,
  );
  late final TextEditingController _education = TextEditingController(
    text: widget.educationLevel,
  );

  @override
  void dispose() {
    _ethnicity.dispose();
    _education.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Demografia'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<String?>(
          initialValue: _gender,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Genero'),
          items: const [
            DropdownMenuItem(value: null, child: Text('Sin dato')),
            DropdownMenuItem(value: 'MALE', child: Text('Masculino')),
            DropdownMenuItem(value: 'FEMALE', child: Text('Femenino')),
            DropdownMenuItem(value: 'OTHER', child: Text('Otro')),
          ],
          onChanged: (value) => setState(() => _gender = value),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _ethnicity,
          inputFormatters: maxLengthFormatters(FieldLimits.ethnicity),
          decoration: const InputDecoration(labelText: 'Etnia'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _education,
          inputFormatters: maxLengthFormatters(FieldLimits.educationLevel),
          decoration: const InputDecoration(labelText: 'Escolaridad'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _DemographicsResult(
            _gender,
            _ethnicity.text.trim().isEmpty ? null : _ethnicity.text.trim(),
            _education.text.trim().isEmpty ? null : _education.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _ContactResult {
  const _ContactResult(this.phone, this.email);
  final String? phone;
  final String? email;
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({this.phone, this.email});

  final String? phone;
  final String? email;

  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  late final TextEditingController _phone = TextEditingController(
    text: widget.phone,
  );
  late final TextEditingController _email = TextEditingController(
    text: widget.email,
  );

  @override
  void dispose() {
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Contacto'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: phoneFormatters(),
          decoration: const InputDecoration(labelText: 'Telefono'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          inputFormatters: maxLengthFormatters(FieldLimits.email),
          decoration: const InputDecoration(labelText: 'Correo'),
        ),
      ],
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _ContactResult(
            _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            _email.text.trim().isEmpty ? null : _email.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _AddressResult {
  const _AddressResult(this.departmentId, this.municipalityId, this.street);
  final String? departmentId;
  final String? municipalityId;
  final String? street;
}

class _AddressDialog extends StatefulWidget {
  const _AddressDialog({
    required this.controller,
    this.departmentId,
    this.municipalityId,
    this.street,
  });

  final PatientDetailController controller;
  final String? departmentId;
  final String? municipalityId;
  final String? street;

  @override
  State<_AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<_AddressDialog> {
  late String? _departmentId = widget.departmentId;
  late String? _municipalityId = widget.municipalityId;
  late final TextEditingController _street = TextEditingController(
    text: widget.street,
  );

  @override
  void dispose() {
    _street.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Direccion'),
    content: AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _departmentId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Departamento'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin dato')),
              for (final GeoDepartment department
                  in widget.controller.departments)
                DropdownMenuItem(
                  value: department.id,
                  child: Text(department.name),
                ),
            ],
            onChanged: (value) {
              setState(() {
                _departmentId = value;
                _municipalityId = null;
              });
              if (value != null) widget.controller.loadMunicipalities(value);
            },
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _municipalityId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Municipio'),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin dato')),
              for (final GeoMunicipality municipality
                  in widget.controller.municipalities)
                DropdownMenuItem(
                  value: municipality.id,
                  child: Text(municipality.name),
                ),
            ],
            onChanged: (value) => setState(() => _municipalityId = value),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _street,
            inputFormatters: maxLengthFormatters(FieldLimits.street),
            decoration: const InputDecoration(labelText: 'Direccion'),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(
          context,
          _AddressResult(
            _departmentId,
            _municipalityId,
            _street.text.trim().isEmpty ? null : _street.text.trim(),
          ),
        ),
        child: const Text('Guardar'),
      ),
    ],
  );
}

class _HistoriesDialog extends StatefulWidget {
  const _HistoriesDialog({required this.histories});

  final List<PatientMedicalHistory> histories;

  @override
  State<_HistoriesDialog> createState() => _HistoriesDialogState();
}

class _HistoriesDialogState extends State<_HistoriesDialog> {
  late final List<_HistoryEdit> _edits = [
    for (final history in widget.histories)
      _HistoryEdit(
        condition: history.condition,
        diagnosedAt: history.diagnosedAt,
        notes: history.notes,
        historyType: history.historyType,
        specialObservations: history.specialObservations,
        hasContraindication: history.hasContraindication,
        contraindicationDetails: history.contraindicationDetails,
        hasPreviousReaction: history.hasPreviousReaction,
        reactionDetails: history.reactionDetails,
      ),
  ];

  @override
  void dispose() {
    for (final edit in _edits) {
      edit.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Antecedentes'),
    content: SizedBox(
      width: 440,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _edits.length; i++) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _edits[i].condition,
                      inputFormatters: maxLengthFormatters(
                        FieldLimits.historyCondition,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Descripcion',
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _edits[i].type,
                      inputFormatters: maxLengthFormatters(FieldLimits.name),
                      decoration: const InputDecoration(labelText: 'Tipo'),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _edits[i].dateText,
                            readOnly: true,
                            onTap: () => _pickDate(i),
                            decoration: const InputDecoration(
                              labelText: 'Fecha de registro',
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          onPressed: () =>
                              setState(() => _edits.removeAt(i).dispose()),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _edits[i].notes,
                      inputFormatters: maxLengthFormatters(
                        FieldLimits.historyNotes,
                      ),
                      decoration: const InputDecoration(labelText: 'Notas'),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _edits[i].observations,
                      inputFormatters: maxLengthFormatters(
                        FieldLimits.historyNotes,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Observaciones especiales',
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Contraindica la vacunacion'),
                      value: _edits[i].hasContraindication,
                      onChanged: (value) =>
                          setState(() => _edits[i].hasContraindication = value),
                    ),
                    if (_edits[i].hasContraindication)
                      TextField(
                        controller: _edits[i].contraindicationDetails,
                        inputFormatters: maxLengthFormatters(FieldLimits.name),
                        decoration: const InputDecoration(labelText: '¿Cual?'),
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Reaccion moderada/severa previa'),
                      value: _edits[i].hasPreviousReaction,
                      onChanged: (value) =>
                          setState(() => _edits[i].hasPreviousReaction = value),
                    ),
                    if (_edits[i].hasPreviousReaction)
                      TextField(
                        controller: _edits[i].reactionDetails,
                        inputFormatters: maxLengthFormatters(FieldLimits.name),
                        decoration: const InputDecoration(labelText: '¿Cual?'),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            OutlinedButton.icon(
              onPressed: () => setState(() => _edits.add(_HistoryEdit())),
              icon: const Icon(Icons.add),
              label: const Text('Agregar antecedente'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancelar'),
      ),
      FilledButton(
        onPressed: () => Navigator.pop(context, [
          for (final edit in _edits)
            if (edit.condition.text.trim().isNotEmpty)
              NewPatientMedicalHistory(
                condition: edit.condition.text.trim(),
                diagnosedAt: edit.diagnosedAt == null
                    ? null
                    : PatientDetailPage._formatIso(edit.diagnosedAt!),
                notes: edit.notes.text.trim().isEmpty
                    ? null
                    : edit.notes.text.trim(),
                historyType: edit.type.text.trim().isEmpty
                    ? null
                    : edit.type.text.trim(),
                specialObservations: edit.observations.text.trim().isEmpty
                    ? null
                    : edit.observations.text.trim(),
                hasContraindication: edit.hasContraindication,
                contraindicationDetails:
                    edit.contraindicationDetails.text.trim().isEmpty
                    ? null
                    : edit.contraindicationDetails.text.trim(),
                hasPreviousReaction: edit.hasPreviousReaction,
                reactionDetails: edit.reactionDetails.text.trim().isEmpty
                    ? null
                    : edit.reactionDetails.text.trim(),
              ),
        ]),
        child: const Text('Guardar'),
      ),
    ],
  );

  Future<void> _pickDate(int index) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _edits[index].diagnosedAt ?? now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _edits[index].diagnosedAt = picked;
      _edits[index].dateText.text = PatientDetailPage._formatDate(picked);
    });
  }
}

class _HistoryEdit {
  _HistoryEdit({
    String? condition,
    this.diagnosedAt,
    String? notes,
    String? historyType,
    String? specialObservations,
    this.hasContraindication = false,
    String? contraindicationDetails,
    this.hasPreviousReaction = false,
    String? reactionDetails,
  }) : condition = TextEditingController(text: condition),
       notes = TextEditingController(text: notes),
       type = TextEditingController(text: historyType),
       observations = TextEditingController(text: specialObservations),
       contraindicationDetails = TextEditingController(
         text: contraindicationDetails,
       ),
       reactionDetails = TextEditingController(text: reactionDetails),
       dateText = TextEditingController(
         text: diagnosedAt == null
             ? ''
             : PatientDetailPage._formatDate(diagnosedAt),
       );

  final TextEditingController condition;
  final TextEditingController notes;
  final TextEditingController type;
  final TextEditingController observations;
  final TextEditingController contraindicationDetails;
  final TextEditingController reactionDetails;
  final TextEditingController dateText;
  DateTime? diagnosedAt;
  bool hasContraindication;
  bool hasPreviousReaction;

  void dispose() {
    condition.dispose();
    notes.dispose();
    type.dispose();
    observations.dispose();
    contraindicationDetails.dispose();
    reactionDetails.dispose();
    dateText.dispose();
  }
}
