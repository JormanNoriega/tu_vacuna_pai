import '../../../core/presentation/async_controller.dart';
import '../../catalogs/domain/entities/catalog_entities.dart';
import '../../catalogs/domain/use_cases/catalog_use_cases.dart';
import '../../patients/domain/entities/patient.dart';
import '../../patients/domain/use_cases/search_patient.dart';
import '../domain/entities/attention.dart';
import '../domain/use_cases/attentions_use_cases.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/app_database.dart';

/// Controlador del historial de atenciones de un paciente. Separado del flujo
/// de nueva atencion: su estado de carga/error es independiente y no se
/// contamina con el del formulario.
class HistoryController extends AsyncController {
  HistoryController({
    required super.sessionManager,
    required this.searchPatient,
    required this.listPatientAttentions,
    required this.listReferenceCatalogs,
    this.api,
    this.database,
  });

  final SearchPatient searchPatient;
  final ListPatientAttentions listPatientAttentions;
  final ListReferenceCatalogs listReferenceCatalogs;
  final ApiClient? api;
  final AppDatabase? database;

  Future<Map<String, dynamic>> recentPage({
    required bool admin,
    required String institutionId,
    required String userId,
    required DateTime from,
    required DateTime to,
    required int page,
  }) async {
    if (!admin) {
      if (database == null) {
        throw StateError('Almacenamiento local no disponible');
      }
      return database!.attentionHistoryLocal(
        institutionId,
        userId,
        from: from,
        to: to,
        page: page,
      );
    }
    final token = (await sessionManager.loadSession())?.accessToken;
    if (token == null || api == null) throw const SessionExpiredException();
    return api!.fetchAttentionHistory(token, from: from, to: to, page: page);
  }

  Patient? _patient;
  List<Attention> _history = const [];
  List<ReferenceOption> _documentTypes = const [];

  Patient? get patient => _patient;
  List<Attention> get history => List.unmodifiable(_history);

  /// Tipos de identificacion para el buscador (catalogo `document_type`).
  List<ReferenceOption> get documentTypes => List.unmodifiable(_documentTypes);

  /// Carga los tipos de identificacion (una sola vez).
  Future<void> loadDocumentTypes() async {
    if (_documentTypes.isNotEmpty) return;
    await execute((token) async {
      final catalogs = await listReferenceCatalogs(token);
      for (final catalog in catalogs) {
        if (catalog.code == 'document_type') {
          _documentTypes = catalog.options;
        }
      }
    });
  }

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

  /// Limpia solo el resultado de la busqueda (paciente e historial) sin tocar
  /// el catalogo de tipos de documento. Se usa al entrar a la vista para no
  /// arrastrar la busqueda anterior.
  void resetResults() {
    _patient = null;
    _history = const [];
    clearError();
    notifyListeners();
  }

  /// Limpia todo el estado de la sesion (al cerrar sesion o cambiar de
  /// usuario), incluido el catalogo de tipos de documento.
  void clearSession() {
    _patient = null;
    _history = const [];
    _documentTypes = const [];
    clearError();
    notifyListeners();
  }
}
