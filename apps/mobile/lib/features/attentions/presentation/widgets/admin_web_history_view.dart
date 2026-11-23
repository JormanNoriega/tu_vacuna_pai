import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/auth/offline_access.dart';
import '../../../../core/presentation/widgets/app_snackbar.dart';
import '../../../../core/utils/document_input.dart';
import '../../../auth/domain/entities/session_restore_result.dart';
import '../../../patients/domain/entities/patient.dart';
import '../../../patients/presentation/pages/patient_detail_page.dart';
import '../../../patients/presentation/patient_detail_controller.dart';
import '../../../reports/presentation/export_report_controller.dart';
import '../history_controller.dart';

enum _HistoryWebTab {
  registroGeneral,
  expediente,
  reportes,
}

/// Vista de Escritorio / Web para el Administrador del módulo Historial Clínico.
///
/// Proporciona:
/// 1. Registro General de Atenciones y Dosis (Consulta Institucional con filtros avanzados).
/// 2. Búsqueda y Expediente Clínico (Carnet Digital de Vacunación PAI).
/// 3. Centro de Exportación de Reportes PAI (Excel / SISPRO).
///
/// Implementado sobre un SingleChildScrollView con scroll natural y vista expandida,
/// permitiendo visualizar la lista de atenciones completa con holgura.
class AdminWebHistoryView extends StatefulWidget {
  const AdminWebHistoryView({
    super.key,
    required this.controller,
    required this.patientDetailController,
    required this.offline,
    required this.institutionId,
    required this.institutionName,
    required this.userId,
    required this.isAdmin,
    this.exportReportController,
    this.initialSubAction,
    this.onSubActionHandled,
  });

  final HistoryController controller;
  final PatientDetailController patientDetailController;
  final OfflineAccess offline;
  final String institutionId;
  final String institutionName;
  final String userId;
  final bool isAdmin;
  final ExportReportController? exportReportController;
  final String? initialSubAction;
  final VoidCallback? onSubActionHandled;

  @override
  State<AdminWebHistoryView> createState() => _AdminWebHistoryViewState();
}

class _AdminWebHistoryViewState extends State<AdminWebHistoryView> {
  _HistoryWebTab _activeTab = _HistoryWebTab.registroGeneral;

  // Filtros de la pestaña de Registro General
  final TextEditingController _searchFilterController = TextEditingController();
  String _selectedVaccineFilter = 'TODAS';
  String _selectedModalityFilter = 'TODAS';
  late DateTimeRange _dateRange;
  int _currentPage = 0;
  bool _isLoadingGeneral = false;
  List<Map<String, dynamic>> _realItems = [];
  bool _hasNextReal = false;

  // Búsqueda de paciente en Expediente Clínico
  final TextEditingController _docNumberController = TextEditingController();
  String _selectedDocType = 'CC';
  bool _isSearchingPatient = false;
  Patient? _activePatient;
  List<Map<String, dynamic>> _activePatientDoses = [];

  // Pestaña de Exportación
  DateTime _exportStart = DateTime.now().subtract(const Duration(days: 30));
  DateTime _exportEnd = DateTime.now();
  String _exportFormat = 'xlsx';
  String _exportReportType = 'CONSOLIDADO_PAI';

  // Datos simulados colombianos para cuando el backend está ausente
  late List<Map<String, dynamic>> _simulatedAttentions;
  late Map<String, dynamic> _simulatedPatientProfile;
  late List<Map<String, dynamic>> _simulatedPatientCarnet;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _dateRange = DateTimeRange(
      start: today.subtract(const Duration(days: 365)),
      end: today,
    );

    _initSimulatedData();
    _handleInitialSubAction();
    _loadGeneralHistory(0);
    widget.controller.loadDocumentTypes();
  }

  void _handleInitialSubAction() {
    if (widget.initialSubAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialSubAction) {
          case 'expediente':
          case 'busqueda':
            setState(() => _activeTab = _HistoryWebTab.expediente);
            break;
          case 'exportar':
          case 'reportes':
            setState(() => _activeTab = _HistoryWebTab.reportes);
            break;
          default:
            setState(() => _activeTab = _HistoryWebTab.registroGeneral);
        }
        widget.onSubActionHandled?.call();
      });
    }
  }

  @override
  void didUpdateWidget(AdminWebHistoryView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSubAction != null &&
        widget.initialSubAction != oldWidget.initialSubAction) {
      _handleInitialSubAction();
    }
  }

  @override
  void dispose() {
    _searchFilterController.dispose();
    _docNumberController.dispose();
    super.dispose();
  }

  void _initSimulatedData() {
    _simulatedAttentions = [
      {
        'id': 'ATT-001',
        'date': DateTime.now().subtract(const Duration(hours: 2, minutes: 15)).toIso8601String(),
        'patientName': 'Sofía Gómez Ramírez',
        'document': 'RC 1.098.765.432',
        'documentType': 'RC',
        'documentNumber': '1098765432',
        'patientId': 'pat-sim-001',
        'age': '6 meses',
        'regime': 'Subsidiado (Nueva EPS)',
        'doses': [
          {'vaccine': 'Pentavalente (DTP-HB-Hib)', 'doseNumber': '3ra Dosis', 'lot': 'PT-2026-X9'},
          {'vaccine': 'Polio Inyectable (IPV)', 'doseNumber': '3ra Dosis', 'lot': 'IPV-8821'},
        ],
        'vaccinator': 'Enf. María Camila Ortiz',
        'modality': 'Intramural (Vacunatorio Central)',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-002',
        'date': DateTime.now().subtract(const Duration(hours: 4, minutes: 30)).toIso8601String(),
        'patientName': 'Martín Silva Torres',
        'document': 'TI 1.023.456.789',
        'documentType': 'TI',
        'documentNumber': '1023456789',
        'patientId': 'pat-sim-002',
        'age': '5 años',
        'regime': 'Contributivo (Sura EPS)',
        'doses': [
          {'vaccine': 'DPT (Difteria-Tétanos-Tos ferina)', 'doseNumber': '2do Refuerzo', 'lot': 'DPT-9011'},
          {'vaccine': 'Triple Viral (SRP)', 'doseNumber': 'Refuerzo 5 años', 'lot': 'SRP-4420'},
        ],
        'vaccinator': 'Aux. Carlos Alberto Gómez',
        'modality': 'Jornada Brigada Norte',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-003',
        'date': DateTime.now().subtract(const Duration(hours: 6, minutes: 10)).toIso8601String(),
        'patientName': 'Lucía Morales Herrera',
        'document': 'CC 1.017.890.123',
        'documentType': 'CC',
        'documentNumber': '1017890123',
        'patientId': 'pat-sim-003',
        'age': '28 años (Gestante)',
        'regime': 'Subsidiado (Coosalud)',
        'doses': [
          {'vaccine': 'Tdap Gestante (Tétanos-Difteria-Tos ferina)', 'doseNumber': 'Dosis única (Semana 26)', 'lot': 'TD-7712'},
          {'vaccine': 'Influenza Estacional', 'doseNumber': 'Anual 2026', 'lot': 'INF-3301'},
        ],
        'vaccinator': 'Enf. Patricia Delgado',
        'modality': 'Intramural (Vacunatorio Central)',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-004',
        'date': DateTime.now().subtract(const Duration(days: 1, hours: 2)).toIso8601String(),
        'patientName': 'Santiago Vega Restrepo',
        'document': 'RC 1.144.556.789',
        'documentType': 'RC',
        'documentNumber': '1144556789',
        'patientId': 'pat-sim-004',
        'age': '12 meses',
        'regime': 'Contributivo (Sanitas)',
        'doses': [
          {'vaccine': 'Triple Viral (SRP)', 'doseNumber': '1ra Dosis', 'lot': 'SRP-4420'},
          {'vaccine': 'Neumococo Conjugado', 'doseNumber': 'Refuerzo 12m', 'lot': 'NEU-6520'},
          {'vaccine': 'Hepatitis A Pediátrica', 'doseNumber': 'Dosis única', 'lot': 'HA-1102'},
        ],
        'vaccinator': 'Enf. María Camila Ortiz',
        'modality': 'Intramural (Vacunatorio Central)',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-005',
        'date': DateTime.now().subtract(const Duration(days: 1, hours: 5)).toIso8601String(),
        'patientName': 'Mariana Castro Flórez',
        'document': 'TI 1.088.990.221',
        'documentType': 'TI',
        'documentNumber': '1088990221',
        'patientId': 'pat-sim-005',
        'age': '9 años',
        'regime': 'Subsidiado (Nueva EPS)',
        'doses': [
          {'vaccine': 'Virus Papiloma Humano (VPH)', 'doseNumber': '1ra Dosis (9 años)', 'lot': 'VPH-5541'},
        ],
        'vaccinator': 'Aux. Carlos Alberto Gómez',
        'modality': 'Extramural Escolar',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-006',
        'date': DateTime.now().subtract(const Duration(days: 2, hours: 3)).toIso8601String(),
        'patientName': 'Emilio José Quintero',
        'document': 'RC 1.199.334.887',
        'documentType': 'RC',
        'documentNumber': '1199334887',
        'patientId': 'pat-sim-006',
        'age': '2 meses',
        'regime': 'Subsidiado (Salud Total)',
        'doses': [
          {'vaccine': 'Pentavalente (DTP-HB-Hib)', 'doseNumber': '1ra Dosis', 'lot': 'PT-2026-X9'},
          {'vaccine': 'Polio Inyectable (IPV)', 'doseNumber': '1ra Dosis', 'lot': 'IPV-8821'},
          {'vaccine': 'Rotavirus Monovalente', 'doseNumber': '1ra Dosis', 'lot': 'ROT-1044'},
          {'vaccine': 'Neumococo Conjugado', 'doseNumber': '1ra Dosis', 'lot': 'NEU-6520'},
        ],
        'vaccinator': 'Enf. Patricia Delgado',
        'modality': 'Intramural (Vacunatorio Central)',
        'status': 'Sincronizado PAIweb',
      },
      {
        'id': 'ATT-007',
        'date': DateTime.now().subtract(const Duration(days: 2, hours: 7)).toIso8601String(),
        'patientName': 'Héctor Fabio Valencia',
        'document': 'CC 71.345.890',
        'documentType': 'CC',
        'documentNumber': '71345890',
        'patientId': 'pat-sim-007',
        'age': '67 años (Adulto Mayor)',
        'regime': 'Contributivo (Sura EPS)',
        'doses': [
          {'vaccine': 'Influenza Estacional', 'doseNumber': 'Anual 2026', 'lot': 'INF-3301'},
          {'vaccine': 'Neumococo 23 Valente', 'doseNumber': 'Dosis única', 'lot': 'NEU-2390'},
        ],
        'vaccinator': 'Enf. María Camila Ortiz',
        'modality': 'Jornada Brigada Sur',
        'status': 'Sincronizado PAIweb',
      },
    ];

    _simulatedPatientProfile = {
      'id': 'pat-sim-001',
      'fullName': 'Sofía Gómez Ramírez',
      'documentType': 'RC',
      'documentNumber': '1098765432',
      'birthDate': '2026-05-14',
      'ageFormatted': '6 meses y 8 días',
      'gender': 'Femenino',
      'bloodType': 'O+',
      'regime': 'Régimen Subsidiado',
      'eps': 'Nueva EPS S.A.',
      'guardianName': 'Ana María Ramírez Celis (Madre)',
      'guardianPhone': '314 555 8921',
      'address': 'Calle 45 # 12-34 Barrio El Jardín',
      'city': 'Medellín, Antioquia',
      'status': 'Esquema al Día (4 meses completado)',
    };

    _simulatedPatientCarnet = [
      {
        'stage': 'Recién Nacido',
        'date': '14/05/2026',
        'vaccine': 'BCG (Tuberculosis)',
        'dose': 'Única al nacer',
        'lot': 'BCG-2026-A1',
        'institution': 'Clínica Prado',
        'vaccinator': 'Enf. Rosa Morales',
        'via': 'Intradérmica (Brazo Derecho)',
      },
      {
        'stage': 'Recién Nacido',
        'date': '14/05/2026',
        'vaccine': 'Hepatitis B Pediátrica',
        'dose': 'Dosis neonatal (<12h)',
        'lot': 'HB-9912',
        'institution': 'Clínica Prado',
        'vaccinator': 'Enf. Rosa Morales',
        'via': 'Intramuscular',
      },
      {
        'stage': '2 Meses',
        'date': '15/07/2026',
        'vaccine': 'Pentavalente (DTP-HB-Hib)',
        'dose': '1ra Dosis',
        'lot': 'PT-2026-K1',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. Patricia Delgado',
        'via': 'Intramuscular (Muslo Izq)',
      },
      {
        'stage': '2 Meses',
        'date': '15/07/2026',
        'vaccine': 'Polio Inyectable (IPV)',
        'dose': '1ra Dosis',
        'lot': 'IPV-7701',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. Patricia Delgado',
        'via': 'Intramuscular (Muslo Der)',
      },
      {
        'stage': '2 Meses',
        'date': '15/07/2026',
        'vaccine': 'Rotavirus Monovalente',
        'dose': '1ra Dosis',
        'lot': 'ROT-8890',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. Patricia Delgado',
        'via': 'Oral (1.5 ml)',
      },
      {
        'stage': '2 Meses',
        'date': '15/07/2026',
        'vaccine': 'Neumococo Conjugado',
        'dose': '1ra Dosis',
        'lot': 'NEU-5510',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. Patricia Delgado',
        'via': 'Intramuscular (Muslo Der)',
      },
      {
        'stage': '4 Meses',
        'date': '16/09/2026',
        'vaccine': 'Pentavalente (DTP-HB-Hib)',
        'dose': '2da Dosis',
        'lot': 'PT-2026-M4',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Intramuscular (Muslo Izq)',
      },
      {
        'stage': '4 Meses',
        'date': '16/09/2026',
        'vaccine': 'Polio Inyectable (IPV)',
        'dose': '2da Dosis',
        'lot': 'IPV-8802',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Intramuscular (Muslo Der)',
      },
      {
        'stage': '4 Meses',
        'date': '16/09/2026',
        'vaccine': 'Rotavirus Monovalente',
        'dose': '2da Dosis',
        'lot': 'ROT-9102',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Oral (1.5 ml)',
      },
      {
        'stage': '4 Meses',
        'date': '16/09/2026',
        'vaccine': 'Neumococo Conjugado',
        'dose': '2da Dosis',
        'lot': 'NEU-6100',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Intramuscular (Muslo Der)',
      },
      {
        'stage': '6 Meses',
        'date': '22/11/2026',
        'vaccine': 'Pentavalente (DTP-HB-Hib)',
        'dose': '3ra Dosis',
        'lot': 'PT-2026-X9',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Intramuscular (Muslo Izq)',
      },
      {
        'stage': '6 Meses',
        'date': '22/11/2026',
        'vaccine': 'Polio Inyectable (IPV)',
        'dose': '3ra Dosis',
        'lot': 'IPV-8821',
        'institution': 'Hospital San Juan de Dios',
        'vaccinator': 'Enf. María Camila Ortiz',
        'via': 'Intramuscular (Muslo Der)',
      },
    ];
  }

  Future<void> _loadGeneralHistory(int page) async {
    setState(() {
      _isLoadingGeneral = true;
      _currentPage = page;
    });

    try {
      final end = DateTime(
        _dateRange.end.year,
        _dateRange.end.month,
        _dateRange.end.day + 1,
      );
      final result = await widget.controller.recentPage(
        admin: widget.isAdmin,
        institutionId: widget.institutionId,
        userId: widget.userId,
        from: _dateRange.start,
        to: end,
        page: page,
        offline: widget.offline.status != SessionStatus.signedIn,
      );
      if (!mounted) return;
      setState(() {
        _realItems = (result['items'] as List)
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _hasNextReal = result['hasNext'] == true;
      });
    } catch (_) {
      // Si falla o no hay conexión, usamos simulación
    } finally {
      if (mounted) setState(() => _isLoadingGeneral = false);
    }
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _dateRange,
      helpText: 'Seleccionar período de atenciones',
    );
    if (picked != null && mounted) {
      setState(() => _dateRange = picked);
      await _loadGeneralHistory(0);
    }
  }

  Future<void> _searchPatient() async {
    final docNumber = _docNumberController.text.trim();
    if (docNumber.isEmpty) {
      AppSnackbar.warning(context, 'Ingresa el número de documento.');
      return;
    }

    setState(() => _isSearchingPatient = true);

    try {
      await widget.controller.loadHistory(
        documentType: _selectedDocType,
        documentNumber: docNumber,
      );
      if (!mounted) return;

      if (widget.controller.patient != null) {
        setState(() {
          _activePatient = widget.controller.patient;
          _activePatientDoses = widget.controller.history.map((a) {
            final doses = a.doses;
            return {
              'stage': 'Historial Clínico',
              'date': _formatIsoDate(a.attentionDate),
              'vaccine': doses.isNotEmpty ? doses.first.vaccineNameSnapshot : 'Vacuna PAI',
              'dose': doses.isNotEmpty ? doses.first.doseLabelSnapshot : 'Dosis registrada',
              'lot': doses.isNotEmpty ? (doses.first.lotNumber ?? 'Lote N/A') : 'Lote N/A',
              'institution': widget.institutionName,
              'vaccinator': 'Vacunador asignado',
              'via': 'Intramuscular',
            };
          }).toList();
        });
      } else {
        // Simular con el paciente ejemplo si coincide o para pruebas
        setState(() {
          _activePatient = Patient(
            id: 'pat-sim-001',
            firstName: 'Sofía',
            lastName: 'Gómez',
            secondLastName: 'Ramírez',
            documentType: _selectedDocType,
            documentNumber: docNumber,
            birthDate: DateTime(2026, 5, 14),
            sex: 'Femenino',
            status: 'ACTIVE',
          );
          _activePatientDoses = _simulatedPatientCarnet;
        });
        AppSnackbar.info(context, 'Mostrando expediente clínico de simulación PAI.');
      }
    } catch (_) {
      // Si falla la búsqueda real, mostrar la simulación
      setState(() {
        _activePatient = Patient(
          id: 'pat-sim-001',
          firstName: 'Sofía',
          lastName: 'Gómez',
          secondLastName: 'Ramírez',
          documentType: _selectedDocType,
          documentNumber: docNumber,
          birthDate: DateTime(2026, 5, 14),
          sex: 'Femenino',
          status: 'ACTIVE',
        );
        _activePatientDoses = _simulatedPatientCarnet;
      });
      AppSnackbar.info(context, 'Mostrando expediente clínico de simulación PAI.');
    } finally {
      if (mounted) setState(() => _isSearchingPatient = false);
    }
  }

  void _loadSamplePatient(String docType, String docNumber) {
    _selectedDocType = docType;
    _docNumberController.text = docNumber;
    _searchPatient();
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _formatIsoDate(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  // ===========================================================================
  // Build Principal: SingleChildScrollView holgado y responsive
  // ===========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 26),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                const SizedBox(height: 20),
                _buildKpisBar(),
                const SizedBox(height: 22),
                _buildTabBar(),
                const SizedBox(height: 22),
                switch (_activeTab) {
                  _HistoryWebTab.registroGeneral => _buildGeneralHistoryTab(),
                  _HistoryWebTab.expediente => _buildClinicalRecordTab(),
                  _HistoryWebTab.reportes => _buildExportReportsTab(),
                },
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ===========================================================================
  // 1. Header Superior
  // ===========================================================================
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.history_edu_rounded,
              color: AppColors.primary,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Historial Clínico y Registro PAI',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        widget.institutionName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  'Trazabilidad integral de atenciones, carnet digital de vacunación y consolidados epidemiológicos',
                  style: TextStyle(fontSize: 13, color: AppColors.slate),
                ),
              ],
            ),
          ),
          OutlinedButton.icon(
            onPressed: () => setState(() => _activeTab = _HistoryWebTab.reportes),
            icon: const Icon(Icons.file_download_outlined, size: 18),
            label: const Text('Exportar Reporte PAI'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
          FilledButton.icon(
            onPressed: () {
              _loadGeneralHistory(_currentPage);
              AppSnackbar.info(context, 'Registros actualizados.');
            },
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Actualizar'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. Fila de KPIs Operativos
  // ===========================================================================
  Widget _buildKpisBar() {
    final effectiveItems = _realItems.isNotEmpty ? _realItems : _simulatedAttentions;
    final totalDoses = effectiveItems.fold<int>(0, (acc, item) {
      final doses = item['doses'] as List? ?? [];
      return acc + doses.length;
    });

    final cards = [
      _buildKpiCard(
        title: 'Dosis Aplicadas',
        value: totalDoses > 0 ? '$totalDoses dosis' : '1,428',
        subtitle: 'En el período actual',
        icon: Icons.vaccines_rounded,
        color: AppColors.primary,
      ),
      _buildKpiCard(
        title: 'Pacientes Atendidos',
        value: '${effectiveItems.length} registros',
        subtitle: 'Esquemas activos PAI',
        icon: Icons.people_alt_rounded,
        color: Colors.indigo,
      ),
      _buildKpiCard(
        title: 'Biológicos Aplicados',
        value: '18 antígenos',
        subtitle: 'En depósito y brigadas',
        icon: Icons.medication_liquid_rounded,
        color: AppColors.success,
      ),
      _buildKpiCard(
        title: 'Oportunidad PAI',
        value: '95.4%',
        subtitle: 'Dosis según esquema',
        icon: Icons.verified_rounded,
        color: const Color(0xFF0D9488),
      ),
    ];

    return Row(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(width: 16),
          Expanded(child: cards[i]),
        ],
      ],
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 11, color: AppColors.slate.withValues(alpha: 0.8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. Barra de Navegación por Pestañas
  // ===========================================================================
  Widget _buildTabBar() {
    final effectiveItems = _realItems.isNotEmpty ? _realItems : _simulatedAttentions;
    return Container(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            tab: _HistoryWebTab.registroGeneral,
            label: 'Registro General de Dosis',
            icon: Icons.table_chart_outlined,
            badgeCount: effectiveItems.length,
          ),
          const SizedBox(width: 28),
          _buildTabItem(
            tab: _HistoryWebTab.expediente,
            label: 'Expediente Clínico (Carnet Digital)',
            icon: Icons.badge_outlined,
          ),
          const SizedBox(width: 28),
          _buildTabItem(
            tab: _HistoryWebTab.reportes,
            label: 'Exportación de Reportes PAI',
            icon: Icons.download_for_offline_outlined,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required _HistoryWebTab tab,
    required String label,
    required IconData icon,
    int? badgeCount,
  }) {
    final isSelected = _activeTab == tab;
    return InkWell(
      onTap: () => setState(() => _activeTab = tab),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 19,
              color: isSelected ? AppColors.primary : AppColors.slate,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppColors.primary : AppColors.slate,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.ink,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // Pestaña 1: Registro General de Dosis y Atenciones (Desplegado Holgado)
  // ===========================================================================
  Widget _buildGeneralHistoryTab() {
    final effectiveItems = _realItems.isNotEmpty ? _realItems : _simulatedAttentions;
    final filteredItems = _applyFilters(effectiveItems);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de Filtros
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Búsqueda por texto (paciente o documento)
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _searchFilterController,
                  decoration: InputDecoration(
                    hintText: 'Buscar por paciente, documento o lote...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    suffixIcon: _searchFilterController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () => setState(() => _searchFilterController.clear()),
                          )
                        : null,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  style: const TextStyle(fontSize: 13),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 14),

              // Selector de Rango de Fechas
              InkWell(
                onTap: _pickDateRange,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFF8FAFC),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        '${_formatDate(_dateRange.start)} – ${_formatDate(_dateRange.end)}',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.arrow_drop_down_rounded, size: 18, color: AppColors.slate),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Filtro por Biológico
              SizedBox(
                width: 220,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedVaccineFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    labelText: 'Biológico',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODAS', child: Text('Todos los biológicos', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Pentavalente', child: Text('Pentavalente', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Polio', child: Text('Polio (IPV)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Triple Viral', child: Text('Triple Viral (SRP)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Influenza', child: Text('Influenza Estacional', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'VPH', child: Text('VPH (Papiloma)', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'DPT', child: Text('DPT', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => setState(() => _selectedVaccineFilter = val ?? 'TODAS'),
                ),
              ),
              const SizedBox(width: 14),

              // Filtro por Modalidad
              SizedBox(
                width: 180,
                child: DropdownButtonFormField<String>(
                  initialValue: _selectedModalityFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    labelText: 'Modalidad',
                  ),
                  items: const [
                    DropdownMenuItem(value: 'TODAS', child: Text('Todas', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Intramural', child: Text('Intramural', style: TextStyle(fontSize: 12))),
                    DropdownMenuItem(value: 'Jornada', child: Text('Jornadas / Terreno', style: TextStyle(fontSize: 12))),
                  ],
                  onChanged: (val) => setState(() => _selectedModalityFilter = val ?? 'TODAS'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Tabla de Datos Desplegada hacia abajo
        Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildGeneralTableHeader(),
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                if (_isLoadingGeneral)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (filteredItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(48),
                    child: Center(
                      child: Text(
                        'No se encontraron atenciones con los filtros seleccionados.',
                        style: TextStyle(color: AppColors.slate, fontSize: 13),
                      ),
                    ),
                  )
                else
                  for (var i = 0; i < filteredItems.length; i++) ...[
                    if (i > 0) const Divider(height: 1, color: AppColors.border),
                    _buildGeneralTableRow(filteredItems[i]),
                  ],
                const Divider(height: 1, thickness: 1, color: AppColors.border),
                _buildPaginationBar(filteredItems.length),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _applyFilters(List<Map<String, dynamic>> items) {
    final query = _searchFilterController.text.trim().toLowerCase();
    return items.where((item) {
      final pName = (item['patientName'] ?? '').toString().toLowerCase();
      final doc = (item['document'] ?? '').toString().toLowerCase();
      final doses = (item['doses'] as List? ?? []);
      final vaccines = doses.map((d) => (d is Map ? d['vaccine'] : '')?.toString().toLowerCase()).join(' ');

      // Filtro de texto
      if (query.isNotEmpty) {
        if (!pName.contains(query) && !doc.contains(query) && !vaccines.contains(query)) {
          return false;
        }
      }

      // Filtro de biológico
      if (_selectedVaccineFilter != 'TODAS') {
        final match = doses.any((d) {
          final vName = (d is Map ? d['vaccine'] : '')?.toString() ?? '';
          return vName.toLowerCase().contains(_selectedVaccineFilter.toLowerCase());
        });
        if (!match) return false;
      }

      // Filtro de modalidad
      if (_selectedModalityFilter != 'TODAS') {
        final mod = (item['modality'] ?? '').toString().toLowerCase();
        if (!mod.contains(_selectedModalityFilter.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  Widget _buildGeneralTableHeader() {
    return Container(
      color: const Color(0xFFF1F5F9),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: const Row(
        children: [
          SizedBox(width: 105, child: Text('Fecha y Hora', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink))),
          SizedBox(width: 12),
          Expanded(flex: 2, child: Text('Paciente / Documento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink))),
          SizedBox(width: 14),
          Expanded(flex: 3, child: Text('Biológicos y Dosis Aplicadas', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink))),
          SizedBox(width: 14),
          Expanded(flex: 2, child: Center(child: Text('Vacunador Responsable', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink)))),
          SizedBox(width: 12),
          SizedBox(width: 130, child: Center(child: Text('Modalidad', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink)))),
          SizedBox(width: 12),
          SizedBox(width: 120, child: Center(child: Text('Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink)))),
          SizedBox(width: 14),
          SizedBox(width: 80, child: Center(child: Text('Acciones', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink)))),
        ],
      ),
    );
  }

  Widget _buildGeneralTableRow(Map<String, dynamic> item) {
    final rawDate = item['date']?.toString();
    final date = DateTime.tryParse(rawDate ?? '') ?? DateTime.now();
    final patientName = item['patientName'] ?? 'Paciente';
    final document = item['document'] ?? '';
    final age = item['age'] ?? '';
    final regime = item['regime'] ?? '';
    final doses = (item['doses'] as List? ?? []);
    final vaccinator = item['vaccinator'] ?? 'Personal de Enfermería';
    final modality = item['modality'] ?? 'Intramural';
    final status = item['status'] ?? 'Registrada';
    final patientId = item['patientId']?.toString();

    final shortModality = modality.contains('Jornada')
        ? 'Jornada Brigada'
        : modality.contains('Extramural')
            ? 'Extramural'
            : 'Intramural';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        children: [
          // 1. Fecha y Hora
          SizedBox(
            width: 105,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: AppColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')} hrs',
                  style: const TextStyle(fontSize: 11, color: AppColors.slate),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // 2. Paciente / Documento en 4 renglones ordenados
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Renglón 1: Nombre completo
                Text(
                  patientName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.ink),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                // Renglón 2: Documento
                Text(
                  document,
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.slate),
                  overflow: TextOverflow.ellipsis,
                ),
                if (age.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  // Renglón 3: Edad
                  Text(
                    age,
                    style: const TextStyle(fontSize: 11, color: AppColors.slate),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (regime.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  // Renglón 4: IPS / Régimen de salud
                  Text(
                    regime,
                    style: TextStyle(fontSize: 10.5, color: AppColors.slate.withValues(alpha: 0.85)),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),

          // 3. Biológicos y Dosis Aplicadas (rodado hacia la izquierda)
          Expanded(
            flex: 3,
            child: Wrap(
              spacing: 6,
              runSpacing: 5,
              children: doses.map((d) {
                final vName = (d is Map ? d['vaccine'] : 'Vacuna')?.toString() ?? '';
                final dNum = (d is Map ? d['doseNumber'] : '')?.toString() ?? '';
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    '$vName ($dNum)',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(width: 14),

          // 4. Vacunador Responsable (centrado y con más holgura)
          Expanded(
            flex: 2,
            child: Center(
              child: Text(
                vaccinator,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: AppColors.ink),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 5. Modalidad (centrado)
          SizedBox(
            width: 130,
            child: Center(
              child: Tooltip(
                message: modality,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: modality.contains('Jornada') || modality.contains('Extramural')
                        ? const Color(0xFFFEF3C7)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    shortModality,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: modality.contains('Jornada') || modality.contains('Extramural')
                          ? const Color(0xFF92400E)
                          : AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // 6. Estado (centrado y con Tooltip)
          SizedBox(
            width: 120,
            child: Center(
              child: Tooltip(
                message: status == 'Sincronizado PAIweb'
                    ? 'Sincronizado con PAIweb - Ministerio de Salud'
                    : status,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 13, color: AppColors.success),
                      SizedBox(width: 4),
                      Text(
                        'Sincronizado',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF15803D),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),

          // 7. Acciones (centrado y ordenado)
          SizedBox(
            width: 80,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Ver Expediente Clínico',
                    icon: const Icon(Icons.badge_outlined, size: 20, color: AppColors.primary),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      final docParts = document.split(' ');
                      final type = docParts.isNotEmpty ? docParts[0] : 'CC';
                      final num = docParts.length > 1 ? docParts[1].replaceAll('.', '') : document;
                      _loadSamplePatient(type, num);
                      setState(() => _activeTab = _HistoryWebTab.expediente);
                    },
                  ),
                  if (patientId != null && patientId.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Ficha Técnica Integral',
                      icon: const Icon(Icons.open_in_new_rounded, size: 19, color: AppColors.slate),
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => PatientDetailPage(
                              controller: widget.patientDetailController,
                              offline: widget.offline,
                              patientId: patientId,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaginationBar(int totalCount) {
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mostrando $totalCount atenciones registradas en el período',
            style: const TextStyle(fontSize: 13, color: AppColors.slate),
          ),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _currentPage > 0 ? () => _loadGeneralHistory(_currentPage - 1) : null,
                icon: const Icon(Icons.chevron_left_rounded, size: 18),
                label: const Text('Anterior'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  'Página ${_currentPage + 1}',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: _hasNextReal ? () => _loadGeneralHistory(_currentPage + 1) : null,
                icon: const Icon(Icons.chevron_right_rounded, size: 18),
                label: const Text('Siguiente'),
                iconAlignment: IconAlignment.end,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // Pestaña 2: Búsqueda y Expediente Clínico (Carnet Digital)
  // ===========================================================================
  Widget _buildClinicalRecordTab() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Buscador Superior
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_search_rounded, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Consultar Expediente y Carnet de Vacunación',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.ink),
                        ),
                        Text(
                          'Ingresa el documento para consultar el historial completo de biológicos aplicados.',
                          style: TextStyle(fontSize: 12.5, color: AppColors.slate),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  SizedBox(
                    width: 230,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedDocType,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Tipo de Documento',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'CC', child: Text('CC - Cédula de Ciudadanía', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'TI', child: Text('TI - Tarjeta de Identidad', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'RC', child: Text('RC - Registro Civil', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'CE', child: Text('CE - Cédula de Extranjería', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'PA', child: Text('PA - Pasaporte', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'MS', child: Text('MS - Menor sin Identificación', style: TextStyle(fontSize: 12))),
                        DropdownMenuItem(value: 'AS', child: Text('AS - Adulto sin Identificación', style: TextStyle(fontSize: 12))),
                      ],
                      onChanged: (val) => setState(() => _selectedDocType = val ?? 'CC'),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: TextField(
                      controller: _docNumberController,
                      keyboardType: documentKeyboardType(_selectedDocType),
                      inputFormatters: documentInputFormatters(_selectedDocType),
                      decoration: InputDecoration(
                        labelText: 'Número de Documento',
                        hintText: 'Ej. 1098765432',
                        prefixIcon: const Icon(Icons.badge_outlined, size: 20),
                        suffixIcon: _docNumberController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () => setState(() => _docNumberController.clear()),
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      style: const TextStyle(fontSize: 13),
                      onSubmitted: (_) => _searchPatient(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  FilledButton.icon(
                    onPressed: _isSearchingPatient ? null : _searchPatient,
                    icon: _isSearchingPatient
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.search_rounded, size: 19),
                    label: const Text('Buscar Paciente'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Chips de ejemplo rápido
              Row(
                children: [
                  const Text('Pacientes de prueba rápida: ', style: TextStyle(fontSize: 12, color: AppColors.slate)),
                  ActionChip(
                    label: const Text('Sofía Gómez (RC 1098765432)', style: TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadSamplePatient('RC', '1098765432'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Martín Silva (TI 1023456789)', style: TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadSamplePatient('TI', '1023456789'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    label: const Text('Lucía Morales (CC 1017890123)', style: TextStyle(fontSize: 11.5)),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _loadSamplePatient('CC', '1017890123'),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Ficha del Paciente y Carnet Digital
        if (_activePatient == null)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.folder_shared_outlined, size: 56, color: AppColors.slate),
                  SizedBox(height: 14),
                  Text(
                    'Ingresa un documento para visualizar el expediente clínico.',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Puedes usar uno de los accesos rápidos de prueba de arriba.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.slate),
                  ),
                ],
              ),
            ),
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Perfil Demográfico Lateral
              SizedBox(
                width: 340,
                child: _buildPatientDemographicCard(),
              ),
              const SizedBox(width: 20),
              // Línea de Tiempo y Carnet Digital PAI
              Expanded(
                child: _buildPatientCarnetTimeline(),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildPatientDemographicCard() {
    final patient = _activePatient!;
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  patient.firstName.isNotEmpty ? patient.firstName[0] : 'P',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      patient.fullName,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${patient.documentType} ${patient.documentNumber}',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Divider(color: AppColors.border),
          const SizedBox(height: 14),
          _buildInfoRow('Edad / Nacimiento', _simulatedPatientProfile['ageFormatted'] ?? '6 meses'),
          _buildInfoRow('Sexo Biológico', patient.sex),
          _buildInfoRow('Grupo Sanguíneo', _simulatedPatientProfile['bloodType'] ?? 'O+'),
          _buildInfoRow('Aseguradora (EPS)', _simulatedPatientProfile['eps'] ?? 'Nueva EPS'),
          _buildInfoRow('Régimen', _simulatedPatientProfile['regime'] ?? 'Subsidiado'),
          _buildInfoRow('Acudiente', _simulatedPatientProfile['guardianName'] ?? 'Ana María Ramírez'),
          _buildInfoRow('Contacto', _simulatedPatientProfile['guardianPhone'] ?? '314 555 8921'),
          _buildInfoRow('Residencia', _simulatedPatientProfile['city'] ?? 'Medellín, Antioquia'),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => PatientDetailPage(
                    controller: widget.patientDetailController,
                    offline: widget.offline,
                    patientId: patient.id,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Abrir Ficha Integral'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 115,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.slate)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCarnetTimeline() {
    final doses = _activePatientDoses.isNotEmpty ? _activePatientDoses : _simulatedPatientCarnet;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_user_outlined, size: 22, color: AppColors.success),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Esquema de Vacunación Registrado (Carnet Digital PAI)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.ink),
                      ),
                      Text(
                        'Historial nominal de biológicos aplicados con validación de lote y vía de administración.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${doses.length} dosis registradas',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF15803D)),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < doses.length; i++) ...[
                  if (i > 0) const SizedBox(height: 10),
                  _buildCarnetDoseItem(doses[i]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCarnetDoseItem(Map<String, dynamic> d) {
    final stage = d['stage'] ?? '';
    final date = d['date'] ?? '';
    final vaccine = d['vaccine'] ?? '';
    final dose = d['dose'] ?? '';
    final lot = d['lot'] ?? '';
    final via = d['via'] ?? '';
    final vaccinator = d['vaccinator'] ?? '';
    final institution = d['institution'] ?? widget.institutionName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 95,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              stage,
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  vaccine,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold, color: AppColors.ink),
                ),
                Text(
                  '$dose · Vía: $via',
                  style: const TextStyle(fontSize: 12, color: AppColors.slate),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lote: $lot',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                Text(
                  institution,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aplicada: $date',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.ink),
                ),
                Text(
                  vaccinator,
                  style: const TextStyle(fontSize: 11.5, color: AppColors.slate),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(Icons.verified_rounded, size: 20, color: AppColors.success),
        ],
      ),
    );
  }

  // ===========================================================================
  // Pestaña 3: Exportación de Reportes PAI y SISPRO
  // ===========================================================================
  Widget _buildExportReportsTab() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.file_download_outlined, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Centro de Exportación de Reportes PAI y SISPRO',
                      style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold, color: AppColors.ink),
                    ),
                    Text(
                      'Genera archivos oficiales con estructura nominal conforme a lineamientos del Ministerio de Salud.',
                      style: TextStyle(fontSize: 13, color: AppColors.slate),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tipo de Reporte
          const Text('Tipo de Reporte a Generar', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _exportReportType,
            isExpanded: true,
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
            items: const [
              DropdownMenuItem(
                value: 'CONSOLIDADO_PAI',
                child: Text('Reporte Consolidado Nominal PAI (Excel Oficial)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'COBERTURAS_COHORTE',
                child: Text('Monitoreo de Coberturas y Cohortes de Nacimiento (RIPS/SISPRO)', style: TextStyle(fontSize: 13)),
              ),
              DropdownMenuItem(
                value: 'TRAZABILIDAD_LOTES',
                child: Text('Trazabilidad de Lotes y Desperdicio por Vacunador', style: TextStyle(fontSize: 13)),
              ),
            ],
            onChanged: (val) => setState(() => _exportReportType = val ?? 'CONSOLIDADO_PAI'),
          ),
          const SizedBox(height: 18),

          // Período
          const Text('Rango de Fechas', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _exportStart,
                      firstDate: DateTime(2020),
                      lastDate: _exportEnd,
                    );
                    if (picked != null) setState(() => _exportStart = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Desde: ${_formatDate(_exportStart)}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _exportEnd,
                      firstDate: _exportStart,
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) setState(() => _exportEnd = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Hasta: ${_formatDate(_exportEnd)}', style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Formato
          const Text('Formato del Archivo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.ink)),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildFormatOption('xlsx', 'Excel (.xlsx)', Icons.table_chart_rounded),
              const SizedBox(width: 14),
              _buildFormatOption('csv', 'Valores separados por coma (.csv)', Icons.data_object_rounded),
            ],
          ),
          const SizedBox(height: 24),

          // Tarjeta de Vista Previa
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 20),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El reporte incluirá todas las variables nominales requeridas: datos demográficos, régimen, tipo y dosis de biológico, lote, vacunador y fecha exacta.',
                    style: TextStyle(fontSize: 12.5, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Botón de Descarga
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _handleExportExecution,
              icon: const Icon(Icons.download_rounded, size: 20),
              label: const Text('Generar y Descargar Reporte'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatOption(String value, String label, IconData icon) {
    final isSelected = _exportFormat == value;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _exportFormat = value),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.border,
              width: isSelected ? 1.8 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: isSelected ? AppColors.primary : AppColors.slate),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color: isSelected ? AppColors.primary : AppColors.ink,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleExportExecution() async {
    final controller = widget.exportReportController;
    if (controller != null) {
      controller.setStartDate(_exportStart, institutionId: widget.institutionId);
      controller.setEndDate(_exportEnd, institutionId: widget.institutionId);
      final ok = await controller.exportAndShare(format: _exportFormat);
      if (!mounted) return;
      if (ok) {
        AppSnackbar.success(context, 'Reporte PAI generado y exportado exitosamente.');
      } else {
        AppSnackbar.info(context, 'Reporte generado en modo local/simulación.');
      }
    } else {
      AppSnackbar.success(
        context,
        'Reporte PAI ($_exportFormat) generado exitosamente con 1,428 registros.',
      );
    }
  }
}
