import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'me_response.dart';

/// Cliente HTTP de la API Spring. Envia el JWT de Supabase como Bearer token
/// y decodifica las respuestas de negocio.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? httpClient,
    this._timeout = const Duration(seconds: 30),
  }) : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;
  final Duration _timeout;

  /// Ejecuta la peticion con timeout y convierte los errores de red en un
  /// [ApiException] con mensaje amigable, para que la UI nunca se quede
  /// colgada ni reciba excepciones de transporte sin formato.
  Future<http.Response> _send(Future<http.Response> request) async {
    try {
      return await request.timeout(_timeout);
    } on TimeoutException {
      throw const ApiException(
        'El servidor no respondio a tiempo. Verifica tu conexion e intenta de nuevo.',
      );
    } on http.ClientException {
      throw const ApiException(
        'No se pudo conectar con el servidor. Verifica que el servidor este '
        'encendido y tu conexion, e intenta de nuevo.',
      );
    }
  }

  /// Resumen de metricas del home (pacientes atendidos y dosis aplicadas),
  /// acotado a la institucion del actor.
  Future<Map<String, dynamic>> fetchMetricsSummary(String accessToken) async {
    final uri = Uri.parse('$baseUrl/metrics/summary');
    final response = await _send(
      _http.get(uri, headers: _jsonHeaders(accessToken)),
    );
    return _decodeObject(
      response,
      fallback: 'Error al consultar las metricas.',
    );
  }

  /// Obtiene el perfil autorizado del usuario autenticado.
  Future<MeResponse> fetchMe(String accessToken) async {
    final uri = Uri.parse('$baseUrl/me');
    final response = await _send(
      _http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Accept': 'application/json',
        },
      ),
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return MeResponse.fromJson(body);
    }

    throw ApiException(
      _messageFromBody(response.body) ?? 'Error al consultar el perfil.',
      statusCode: response.statusCode,
    );
  }

  /// Crea una institucion. Requiere `INSTITUTION_WRITE` (SUPER_ADMIN).
  Future<Map<String, dynamic>> createInstitution(
    String accessToken, {
    required String code,
    required String name,
    int? offlineWindowHours,
  }) async {
    final uri = Uri.parse('$baseUrl/institutions');
    final response = await _send(
      _http.post(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({
          'code': code,
          'name': name,
          'offlineWindowHours': ?offlineWindowHours,
        }),
      ),
    );

    return _decodeObject(response, fallback: 'Error al crear la institucion.');
  }

  /// Lista las instituciones. Requiere `INSTITUTION_WRITE` (SUPER_ADMIN).
  Future<List<Map<String, dynamic>>> listInstitutions(
    String accessToken,
  ) async {
    final uri = Uri.parse('$baseUrl/institutions');
    final response = await _send(
      _http.get(uri, headers: _jsonHeaders(accessToken)),
    );

    return _decodeList(
      response,
      fallback: 'Error al consultar las instituciones.',
    );
  }

  /// Actualiza el estado de una institucion (ACTIVE/INACTIVE).
  Future<Map<String, dynamic>> updateInstitutionStatus(
    String accessToken, {
    required String institutionId,
    required String status,
  }) async {
    final uri = Uri.parse('$baseUrl/institutions/$institutionId/status');
    final response = await _send(
      _http.put(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({'status': status}),
      ),
    );

    return _decodeObject(
      response,
      fallback: 'Error al actualizar la institucion.',
    );
  }

  /// Crea un ADMIN_INSTITUTION para una institucion. Requiere
  /// `INSTITUTION_WRITE` (SUPER_ADMIN). La contrasena viaja solo en el request
  /// y nunca se devuelve en la respuesta. [operationId] es la clave de
  /// idempotencia: se reenvia el mismo valor en reintentos del mismo intento.
  Future<Map<String, dynamic>> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
    required String operationId,
  }) async {
    final uri = Uri.parse('$baseUrl/users/institution-admins');
    final response = await _send(
      _http.post(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({
          'email': email,
          'fullName': fullName,
          'institutionId': institutionId,
          'temporaryPassword': temporaryPassword,
          'operationId': operationId,
        }),
      ),
    );

    return _decodeObject(
      response,
      fallback: 'Error al crear el usuario admin.',
    );
  }

  /// Lista los usuarios de una institucion. Para ADMIN_INSTITUTION el scope se
  /// valida en el backend y el listado se fuerza a los roles gestionables
  /// (VACCINATOR, READ_ONLY); el parametro [roles] es opcional y solo lo usa
  /// quien tiene INSTITUTION_WRITE.
  Future<List<Map<String, dynamic>>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
    List<String>? roles,
  }) async {
    final uri = Uri.parse('$baseUrl/users').replace(
      queryParameters: {
        'institutionId': institutionId,
        if (roles != null && roles.isNotEmpty) 'roles': roles.join(','),
      },
    );
    final response = await _send(
      _http.get(uri, headers: _jsonHeaders(accessToken)),
    );

    return _decodeList(response, fallback: 'Error al consultar los usuarios.');
  }

  /// Crea un VACCINATOR en la institucion del usuario autenticado. Requiere
  /// `USER_MANAGE` (ADMIN_INSTITUTION). La contrasena temporal viaja solo en el
  /// request y nunca se devuelve en la respuesta; el institutionId se deriva
  /// del token en el servidor, no se envia en el body. [operationId] es la
  /// clave de idempotencia de reintentos. El perfil (documento, contacto,
  /// profesion) viaja crudo; el backend lo normaliza y valida.
  Future<Map<String, dynamic>> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
    required String operationId,
    required String documentType,
    required String documentNumber,
    String? phone,
    String? birthDate,
    String? gender,
    required String professionCode,
    String? professionalRegistrationNumber,
    String? professionalRegistrationType,
  }) async {
    final uri = Uri.parse('$baseUrl/users/vaccinators');
    final response = await _send(
      _http.post(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({
          'email': email,
          'fullName': fullName,
          'temporaryPassword': temporaryPassword,
          'operationId': operationId,
          'documentType': documentType,
          'documentNumber': documentNumber,
          'professionCode': professionCode,
          if (phone != null && phone.isNotEmpty) 'phone': phone,
          if (birthDate != null && birthDate.isNotEmpty) 'birthDate': birthDate,
          if (gender != null && gender.isNotEmpty) 'gender': gender,
          if (professionalRegistrationNumber != null &&
              professionalRegistrationNumber.isNotEmpty)
            'professionalRegistrationNumber': professionalRegistrationNumber,
          if (professionalRegistrationType != null &&
              professionalRegistrationType.isNotEmpty)
            'professionalRegistrationType': professionalRegistrationType,
        }),
      ),
    );

    return _decodeObject(response, fallback: 'Error al crear el vacunador.');
  }

  /// Activa o desactiva un usuario de la institucion del actor. El scope se
  /// valida en el backend.
  Future<Map<String, dynamic>> updateUserStatus(
    String accessToken, {
    required String userId,
    required String status,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/status');
    final response = await _send(
      _http.put(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({'status': status}),
      ),
    );

    return _decodeObject(response, fallback: 'Error al actualizar el usuario.');
  }

  /// Reemplaza los roles de un usuario de la institucion del actor. El rol
  /// SUPER_ADMIN no se puede asignar por esta via.
  Future<Map<String, dynamic>> updateUserRoles(
    String accessToken, {
    required String userId,
    required List<String> roles,
  }) async {
    final uri = Uri.parse('$baseUrl/users/$userId/roles');
    final response = await _send(
      _http.put(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({'roles': roles}),
      ),
    );

    return _decodeObject(response, fallback: 'Error al actualizar los roles.');
  }

  /// Actualiza la configuracion de una institucion. Requiere
  /// `INSTITUTION_WRITE` (SUPER_ADMIN).
  Future<Map<String, dynamic>> updateInstitutionConfig(
    String accessToken, {
    required String institutionId,
    required int offlineWindowHours,
  }) async {
    final uri = Uri.parse('$baseUrl/institutions/$institutionId/config');
    final response = await _send(
      _http.put(
        uri,
        headers: _jsonHeaders(accessToken),
        body: jsonEncode({'offlineWindowHours': offlineWindowHours}),
      ),
    );

    return _decodeObject(
      response,
      fallback: 'Error al actualizar la configuracion.',
    );
  }

  Future<List<Map<String, dynamic>>> listCatalogVaccines(String token) async =>
      _decodeList(
        await _send(
          _http.get(
            Uri.parse('$baseUrl/catalogs/vaccines'),
            headers: _jsonHeaders(token),
          ),
        ),
        fallback: 'Error al consultar el catalogo.',
      );

  Future<List<Map<String, dynamic>>> listInstitutionCatalogVaccines(
    String token,
    String institutionId,
  ) async => _decodeList(
    await _send(
      _http.get(
        Uri.parse('$baseUrl/institutions/$institutionId/vaccines'),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar el catalogo institucional.',
  );

  /// Lista las vacunas activas del catalogo global que aun no tienen relacion
  /// con la institucion, para que el ADMIN_INSTITUTION pueda habilitarlas.
  Future<List<Map<String, dynamic>>> listAvailableInstitutionVaccines(
    String token,
    String institutionId,
  ) async => _decodeList(
    await _send(
      _http.get(
        Uri.parse('$baseUrl/institutions/$institutionId/vaccines/available'),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar las vacunas disponibles.',
  );
  Future<Map<String, dynamic>> createCatalogVaccine(
    String token,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/catalogs/vaccines'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al crear la vacuna.',
  );
  Future<Map<String, dynamic>> updateCatalogVaccine(
    String token,
    String id,
    int version,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse('$baseUrl/catalogs/vaccines/$id?version=$version'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar la vacuna.',
  );
  Future<void> deleteCatalogVaccine(
    String token,
    String id,
    int version,
  ) async {
    _decodeEmpty(
      await _send(
        _http.delete(
          Uri.parse('$baseUrl/catalogs/vaccines/$id?version=$version'),
          headers: _jsonHeaders(token),
        ),
      ),
      'Error al eliminar la vacuna.',
    );
  }

  Future<List<Map<String, dynamic>>> listCatalogOptions(
    String token,
    String vaccineId, {
    String? institutionId,
  }) async => _decodeList(
    await _send(
      _http.get(
        Uri.parse(
          institutionId == null
              ? '$baseUrl/catalogs/vaccines/$vaccineId/options'
              : '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/options',
        ),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar las opciones.',
  );
  Future<Map<String, dynamic>> createCatalogOption(
    String token,
    String vaccineId,
    Map<String, dynamic> body, {
    String? institutionId,
  }) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse(
          institutionId == null
              ? '$baseUrl/catalogs/vaccines/$vaccineId/options'
              : '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/options',
        ),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al crear la opcion.',
  );
  Future<Map<String, dynamic>> updateCatalogOption(
    String token,
    String vaccineId,
    String id,
    Map<String, dynamic> body, {
    String? institutionId,
  }) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse(
          institutionId == null
              ? '$baseUrl/catalogs/vaccines/$vaccineId/options/$id'
              : '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/options/$id',
        ),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar la opcion.',
  );
  Future<void> deleteCatalogOption(
    String token,
    String vaccineId,
    String id,
    int version, {
    String? institutionId,
  }) async {
    _decodeEmpty(
      await _send(
        _http.delete(
          Uri.parse(
            '${institutionId == null ? '$baseUrl/catalogs/vaccines/$vaccineId/options/$id' : '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/options/$id'}?version=$version',
          ),
          headers: _jsonHeaders(token),
        ),
      ),
      'Error al eliminar la opcion.',
    );
  }

  Future<List<Map<String, dynamic>>> listCatalogTemplates(
    String token,
    String vaccineId,
  ) async => _decodeList(
    await _send(
      _http.get(
        Uri.parse('$baseUrl/catalogs/vaccines/$vaccineId/templates'),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar las plantillas.',
  );

  Future<void> setInstitutionVaccineEnabled(
    String token,
    String institutionId,
    String vaccineId,
    bool enabled,
  ) async {
    final path =
        '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/${enabled ? 'enable' : 'disable'}';
    _decodeEmpty(
      await _send(_http.post(Uri.parse(path), headers: _jsonHeaders(token))),
      'Error al actualizar la vacuna.',
    );
  }

  /// Clona el catalogo global hacia una institucion. Requiere
  /// `CATALOG_CONFIG_WRITE`. [includeDefaultConfig] copia las opciones
  /// operativas de los templates como configuracion por defecto.
  Future<Map<String, dynamic>> cloneCatalogToInstitution(
    String token,
    String institutionId, {
    required bool includeDefaultConfig,
  }) async {
    final uri = Uri.parse(
      '$baseUrl/institutions/$institutionId/vaccines/clone',
    );
    final response = await _send(
      _http.post(
        uri,
        headers: _jsonHeaders(token),
        body: jsonEncode({'includeDefaultConfig': includeDefaultConfig}),
      ),
    );
    return _decodeObject(response, fallback: 'Error al clonar el catalogo.');
  }

  Future<List<Map<String, dynamic>>> suggestedCatalogOptions(
    String token,
    String institutionId,
    String vaccineId,
  ) async => _decodeList(
    await _send(
      _http.get(
        Uri.parse(
          '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/suggested-options',
        ),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar sugerencias.',
  );
  Future<List<Map<String, dynamic>>> importSuggestedCatalogOptions(
    String token,
    String institutionId,
    String vaccineId,
  ) async => _decodeList(
    await _send(
      _http.post(
        Uri.parse(
          '$baseUrl/institutions/$institutionId/vaccines/$vaccineId/import-suggested-options',
        ),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al importar sugerencias.',
  );

  // ---------- Pacientes ----------

  /// Busca pacientes por documento dentro de la institucion del actor.
  Future<List<Map<String, dynamic>>> searchPatients(
    String token, {
    required String documentType,
    required String documentNumber,
  }) async {
    final uri = Uri.parse('$baseUrl/patients').replace(
      queryParameters: {
        'documentType': documentType,
        'documentNumber': documentNumber,
      },
    );
    return _decodeList(
      await _send(_http.get(uri, headers: _jsonHeaders(token))),
      fallback: 'Error al buscar pacientes.',
    );
  }

  /// Obtiene un paciente por id (scope validado en el backend).
  Future<Map<String, dynamic>> getPatient(
    String token,
    String patientId,
  ) async => _decodeObject(
    await _send(
      _http.get(
        Uri.parse('$baseUrl/patients/$patientId'),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al consultar el paciente.',
  );

  /// Crea un paciente. [operationId] es la clave de idempotencia opcional.
  Future<Map<String, dynamic>> createPatient(
    String token,
    Map<String, dynamic> body, {
    String? operationId,
  }) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/patients'),
        headers: _jsonHeaders(token, idempotencyKey: operationId),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al crear el paciente.',
  );

  Future<Map<String, dynamic>> updatePatientDemographics(
    String token,
    String patientId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse('$baseUrl/patients/$patientId/demographics'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar la demografia.',
  );

  Future<Map<String, dynamic>> updatePatientContact(
    String token,
    String patientId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse('$baseUrl/patients/$patientId/contact'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar el contacto.',
  );

  Future<Map<String, dynamic>> updatePatientMedicalHistories(
    String token,
    String patientId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse('$baseUrl/patients/$patientId/medical-histories'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar los antecedentes.',
  );

  // ---------- Atenciones y dosis ----------
  Future<Map<String, dynamic>> createAttention(
    String token,
    Map<String, dynamic> body, {
    String? operationId,
  }) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/attentions'),
        headers: _jsonHeaders(token, idempotencyKey: operationId),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al crear la atencion.',
  );

  Future<Map<String, dynamic>> updateAttention(
    String token,
    String attentionId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.put(
        Uri.parse('$baseUrl/attentions/$attentionId'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al actualizar la atencion.',
  );

  Future<Map<String, dynamic>> completeAttention(
    String token,
    String attentionId,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/attentions/$attentionId/complete'),
        headers: _jsonHeaders(token),
      ),
    ),
    fallback: 'Error al completar la atencion.',
  );

  Future<List<Map<String, dynamic>>> listAttentionsByPatient(
    String token,
    String patientId,
  ) async {
    final uri = Uri.parse('$baseUrl/attentions')
        .replace(queryParameters: {'patientId': patientId});
    return _decodeList(
      await _send(_http.get(uri, headers: _jsonHeaders(token))),
      fallback: 'Error al consultar el historial.',
    );
  }

  Future<Map<String, dynamic>> registerDose(
    String token,
    String attentionId,
    Map<String, dynamic> body, {
    String? operationId,
  }) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/attentions/$attentionId/doses'),
        headers: _jsonHeaders(token, idempotencyKey: operationId),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al registrar la dosis.',
  );

  Future<Map<String, dynamic>> cancelAttention(
    String token,
    String attentionId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/attentions/$attentionId/cancel'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al anular la atencion.',
  );

  Future<Map<String, dynamic>> cancelDose(
    String token,
    String attentionId,
    String doseId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/attentions/$attentionId/doses/$doseId/cancel'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al anular la dosis.',
  );

  // ---------- Sincronizacion ----------

  /// Envia un batch de operaciones del outbox. El servidor responde con
  /// `accepted` y `rejected` (ver `docs/api/openapi.yaml` y `sync-contract.md`).
  Future<Map<String, dynamic>> pushSync(
    String token,
    List<Map<String, dynamic>> operations,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/sync/push'),
        headers: _jsonHeaders(token),
        body: jsonEncode({'operations': operations}),
      ),
    ),
    fallback: 'Error al sincronizar los cambios.',
  );

  /// Trae las operaciones del scope no vistas por el cliente.
  Future<Map<String, dynamic>> pullSync(
    String token, {
    required String since,
    int limit = 500,
  }) async {
    final uri = Uri.parse('$baseUrl/sync/pull')
        .replace(queryParameters: {'since': since, 'limit': '$limit'});
    return _decodeObject(
      await _send(_http.get(uri, headers: _jsonHeaders(token))),
      fallback: 'Error al consultar los cambios del servidor.',
    );
  }

  // ---------- Catalogo efectivo ----------

  /// Catalogo efectivo de la institucion del actor (vacunas habilitadas con
  /// sus dosis, tipos de neumococo y opciones operativas).
  Future<List<Map<String, dynamic>>> getEffectiveCatalog(String token) async {
    final response = await _send(
      _http.get(
        Uri.parse('$baseUrl/catalogs/effective'),
        headers: _jsonHeaders(token),
      ),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      return (decoded['vaccines'] as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    throw ApiException(
      _messageFromBody(response.body) ??
          'Error al consultar el catalogo efectivo.',
      statusCode: response.statusCode,
    );
  }

  // ---------- Catalogo geografico ----------

  Future<List<Map<String, dynamic>>> getCountries(String token) async =>
      _decodeList(
        await _send(
          _http.get(
            Uri.parse('$baseUrl/catalogs/geo/countries'),
            headers: _jsonHeaders(token),
          ),
        ),
        fallback: 'Error al consultar los paises.',
      );

  Future<List<Map<String, dynamic>>> getDepartments(String token) async =>
      _decodeList(
        await _send(
          _http.get(
            Uri.parse('$baseUrl/catalogs/geo/departments'),
            headers: _jsonHeaders(token),
          ),
        ),
        fallback: 'Error al consultar los departamentos.',
      );

  Future<List<Map<String, dynamic>>> getMunicipalities(
    String token,
    String departmentId,
  ) async {
    final uri = Uri.parse('$baseUrl/catalogs/geo/municipalities')
        .replace(queryParameters: {'departmentId': departmentId});
    return _decodeList(
      await _send(_http.get(uri, headers: _jsonHeaders(token))),
      fallback: 'Error al consultar los municipios.',
    );
  }

  // ---------- Catalogos de referencia ----------

  Future<List<Map<String, dynamic>>> getReferenceCatalogs(String token) async =>
      _decodeList(
        await _send(
          _http.get(
            Uri.parse('$baseUrl/catalogs/reference'),
            headers: _jsonHeaders(token),
          ),
        ),
        fallback: 'Error al consultar los catalogos de referencia.',
      );

  /// Aseguradoras en salud (EPS) activas. Si [regime] viene, el backend filtra
  /// incluyendo las de regimen AMBOS.
  Future<List<Map<String, dynamic>>> getInsurers(
    String token, {
    String? regime,
  }) async {
    final uri = Uri.parse('$baseUrl/catalogs/insurers')
        .replace(queryParameters: regime == null ? null : {'regime': regime});
    return _decodeList(
      await _send(_http.get(uri, headers: _jsonHeaders(token))),
      fallback: 'Error al consultar las aseguradoras.',
    );
  }

  Map<String, String> _jsonHeaders(
    String accessToken, {
    String? idempotencyKey,
  }) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
    if (idempotencyKey != null && idempotencyKey.isNotEmpty)
      'Idempotency-Key': idempotencyKey,
  };

  Map<String, dynamic> _decodeObject(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw ApiException(
      _messageFromBody(response.body) ?? fallback,
      statusCode: response.statusCode,
    );
  }

  List<Map<String, dynamic>> _decodeList(
    http.Response response, {
    required String fallback,
  }) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      return (decoded as List<dynamic>)
          .map((item) => item as Map<String, dynamic>)
          .toList();
    }
    throw ApiException(
      _messageFromBody(response.body) ?? fallback,
      statusCode: response.statusCode,
    );
  }

  Future<Map<String, dynamic>> createCatalogTemplate(
    String token,
    String vaccineId,
    Map<String, dynamic> body,
  ) async => _decodeObject(
    await _send(
      _http.post(
        Uri.parse('$baseUrl/catalogs/vaccines/$vaccineId/templates'),
        headers: _jsonHeaders(token),
        body: jsonEncode(body),
      ),
    ),
    fallback: 'Error al crear la plantilla.',
  );

  void _decodeEmpty(http.Response response, String fallback) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        _messageFromBody(response.body) ?? fallback,
        statusCode: response.statusCode,
      );
    }
  }

  String? _messageFromBody(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded['message'] as String?;
      }
    } on FormatException {
      // Cuerpo no JSON; se ignora.
    }
    return null;
  }
}
