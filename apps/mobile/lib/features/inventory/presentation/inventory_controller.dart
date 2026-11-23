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

  /// Comprueba recepción vigente con frascos sin comprometer registrados.
  /// No representa saldo clínico de dosis ni prueba existencias físicas.
  Future<bool> hasReceivedLot(String institutionId, String vaccineId) async {
    final session = await sessionManager.loadSession();
    if (session == null) throw const SessionExpiredException();
    final lots = await api.inventoryList(
      session.accessToken,
      institutionId,
      'vaccines/${Uri.encodeComponent(vaccineId)}/my-uncommitted-received-lots',
    );
    return lots.isNotEmpty;
  }

  final Future<void> Function()? renewSession;
  Future<void>? _renewing;
  List<Map<String, dynamic>> lots = const [];
  List<Map<String, dynamic>> assignments = const [];
  List<Map<String, dynamic>> vaccines = const [];
  List<Map<String, dynamic>> vaccinators = const [];
  List<Map<String, dynamic>> campaigns = const [];
  List<Map<String, dynamic>> custodyEvents = const [];
  List<Map<String, dynamic>> movements = const [];

  /// Un 5xx o un fallo de red no demuestra si una escritura se confirmó.
  int? lastPostStatus;

  @override
  Future<void> execute(Future<void> Function(String token) action) async {
    if (isDisposed) return;
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

  Future<void> loadVaccinators(String institution) => execute((token) async {
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
  });

  Future<List<Map<String, dynamic>>?> loadCampaignParticipants(
    String institution,
    String campaignId,
  ) async {
    List<Map<String, dynamic>>? result;
    await execute((token) async {
      result = await api.inventoryList(
        token,
        institution,
        'campaigns/${Uri.encodeComponent(campaignId)}/participants',
      );
    });
    return result;
  }

  /// Solo lectura: null representa un fallo, no una lista vacía.
  Future<List<Map<String, dynamic>>?> loadPendingFollowUps(
    String institution,
  ) async {
    List<Map<String, dynamic>>? result;
    await execute((token) async {
      result = await api.inventoryList(
        token,
        institution,
        'pending-follow-ups',
      );
    });
    return result;
  }

  Future<Map<String, dynamic>?> loadHistoricalCustodyReview(
    String institution,
    String assignmentId,
  ) async {
    Map<String, dynamic>? result;
    await execute((token) async {
      result = await api.inventoryObject(
        token,
        institution,
        'assignments/${Uri.encodeComponent(assignmentId)}/historical-custody-review',
      );
    });
    return result;
  }

  Future<Map<String, dynamic>?> loadConciliation(
    String institution,
    String assignmentId,
  ) async {
    Map<String, dynamic>? result;
    await execute((token) async {
      result = await api.inventoryObject(
        token,
        institution,
        'assignments/${Uri.encodeComponent(assignmentId)}/conciliation',
      );
    });
    return result;
  }

  Future<Map<String, dynamic>?> loadCustodyWorkflow(
    String institution,
    String assignmentId, {
    required bool admin,
  }) async {
    Map<String, dynamic>? result;
    await execute((token) async {
      result = await api.inventoryObject(
        token,
        institution,
        '${admin ? 'assignments' : 'my-assignments'}/${Uri.encodeComponent(assignmentId)}/custody-workflow',
      );
    });
    return result;
  }

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
    lastPostStatus = null;
    await execute((token) async {
      try {
        await api.inventoryPost(token, institution, resource, body);
      } on ApiException catch (e) {
        lastPostStatus = e.statusCode;
        rethrow;
      }
      success = true;
    });
    return success;
  }
}
