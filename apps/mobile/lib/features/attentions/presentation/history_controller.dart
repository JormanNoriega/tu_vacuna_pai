import '../../../core/presentation/async_controller.dart';
import '../../patients/domain/entities/patient.dart';
import '../../patients/domain/use_cases/search_patient.dart';
import '../domain/entities/attention.dart';
import '../domain/use_cases/attentions_use_cases.dart';

/// Controlador del historial de atenciones de un paciente. Separado del flujo
/// de nueva atencion: su estado de carga/error es independiente y no se
/// contamina con el del formulario.
class HistoryController extends AsyncController {
  HistoryController({
    required super.sessionManager,
    required this.searchPatient,
    required this.listPatientAttentions,
  });

  final SearchPatient searchPatient;
  final ListPatientAttentions listPatientAttentions;

  Patient? _patient;
  List<Attention> _history = const [];

  Patient? get patient => _patient;
  List<Attention> get history => List.unmodifiable(_history);

  /// Busca al paciente por documento y carga sus atenciones.
  Future<void> loadHistory({
    required String documentType,
    required String documentNumber,
  }) => execute((token) async {
    final patients = await searchPatient(
      token,
      documentType: documentType,
      documentNumber: documentNumber,
    );
    _patient = patients.isEmpty ? null : patients.first;
    _history = patients.isEmpty
        ? const []
        : await listPatientAttentions(token, patients.first.id);
  });

  /// Limpia el resultado y el error (al cambiar de busqueda o de sesion).
  void clearSession() {
    _patient = null;
    _history = const [];
    clearError();
    notifyListeners();
  }
}
