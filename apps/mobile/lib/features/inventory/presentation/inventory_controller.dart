import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/presentation/async_controller.dart';

/// Logistica online: no almacena saldos en cache ni encola operaciones offline.
class InventoryController extends AsyncController {
  InventoryController({
    required super.sessionManager,
    required this.api,
    this.renewSession,
  });
  final ApiClient api;
  final Future<void> Function()? renewSession;
  Future<void>? _renewing;
  List<Map<String, dynamic>> lots = const [];
  List<Map<String, dynamic>> assignments = const [];
  List<Map<String, dynamic>> vaccines = const [];
  List<Map<String, dynamic>> vaccinators = const [];
  List<Map<String, dynamic>> campaigns = const [];
  List<Map<String, dynamic>> custodyEvents = const [];
  List<Map<String, dynamic>> movements = const [];

  @override
  Future<void> execute(Future<void> Function(String token) action) async {
    final session = await sessionManager.loadSession();
    if (session != null &&
        !session.expiresAt.isAfter(DateTime.now()) &&
        renewSession != null) {
      try {
        _renewing ??= renewSession!();
        await _renewing;
      } catch (_) {
        // La operación informará el error; nunca reintentar una escritura.
      } finally {
        _renewing = null;
      }
    }
    await super.execute(action);
  }

  @override
  String mapApiError(ApiException e) {
    if (e.statusCode == 401) {
      return 'Tu sesión expiró. Inicia sesión de nuevo.';
    }
    if (e.statusCode == 403) {
      return 'No tienes permiso para consultar o modificar este inventario.';
    }
    if (e.statusCode == 404 && e.message.contains('No static resource')) {
      return 'El inventario no está disponible en este servidor. Verifica que la API de inventario esté habilitada y que la app use la dirección correcta.';
    }
    return e.message;
  }

  void clearSession() {
    lots = const [];
    assignments = const [];
    vaccines = const [];
    vaccinators = const [];
    campaigns = const [];
    custodyEvents = const [];
    movements = const [];
    clearError();
    notifyListeners();
  }

  Future<void> load(String institution, {required bool admin}) =>
      execute((token) async {
        lots = const [];
        assignments = const [];
        campaigns = const [];
        custodyEvents = const [];
        final loadedLots = admin
            ? await api.inventoryList(token, institution, 'lots')
            : <Map<String, dynamic>>[];
        final loadedAssignments = await api.inventoryList(
          token,
          institution,
          admin ? 'assignments' : 'my-assignments',
        );
        final loadedCampaigns = admin
            ? await api.inventoryList(token, institution, 'campaigns')
            : <Map<String, dynamic>>[];
        final loadedEvents = await api.inventoryList(
          token,
          institution,
          admin ? 'custody-events' : 'my-custody-events',
        );
        lots = loadedLots;
        assignments = loadedAssignments;
        campaigns = loadedCampaigns;
        custodyEvents = loadedEvents;
      });

  /// Consulta solo existencias para la ficha de configuración de una vacuna.
  Future<void> loadLots(String institution) => execute((token) async {
    lots = await api.inventoryList(token, institution, 'lots');
  });

  Future<void> loadMovements(String institution) => execute((token) async {
    movements = await api.inventoryList(token, institution, 'movements');
  });

  Future<void> loadFormOptions(String institution, {required bool isLot}) =>
      execute((token) async {
        if (isLot) {
          vaccines = const [];
          vaccines = (await api.listInstitutionCatalogVaccines(
            token,
            institution,
          )).where((v) => v['enabled'] == true).toList();
        } else {
          vaccinators = const [];
          campaigns = (await api.inventoryList(
            token,
            institution,
            'campaigns',
          )).where((item) => item['status'] == 'ACTIVE').toList();
          vaccinators =
              (await api.listUsersByInstitution(
                    token,
                    institutionId: institution,
                    roles: const ['VACCINATOR'],
                  ))
                  .where(
                    (u) =>
                        u['status'] == 'ACTIVE' &&
                        (u['roles'] as List<dynamic>? ?? const []).contains(
                          'VACCINATOR',
                        ),
                  )
                  .toList();
        }
      });

  Future<bool> post(
    String institution,
    String resource,
    Map<String, dynamic> body,
  ) async {
    var success = false;
    await execute((token) async {
      await api.inventoryPost(token, institution, resource, body);
      success = true;
    });
    return success;
  }
}
