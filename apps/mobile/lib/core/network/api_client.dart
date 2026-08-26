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
    this._timeout = const Duration(seconds: 10),
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
  /// y nunca se devuelve en la respuesta.
  Future<Map<String, dynamic>> createInstitutionAdmin(
    String accessToken, {
    required String email,
    required String fullName,
    required String institutionId,
    required String temporaryPassword,
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
        }),
      ),
    );

    return _decodeObject(
      response,
      fallback: 'Error al crear el usuario admin.',
    );
  }

  /// Lista los usuarios de una institucion. Para ADMIN_INSTITUTION el scope se
  /// valida en el backend.
  Future<List<Map<String, dynamic>>> listUsersByInstitution(
    String accessToken, {
    required String institutionId,
  }) async {
    final uri = Uri.parse('$baseUrl/users')
        .replace(queryParameters: {'institutionId': institutionId});
    final response = await _send(
      _http.get(uri, headers: _jsonHeaders(accessToken)),
    );

    return _decodeList(response, fallback: 'Error al consultar los usuarios.');
  }

  /// Crea un VACCINATOR en la institucion del usuario autenticado. Requiere
  /// `USER_MANAGE` (ADMIN_INSTITUTION). La contrasena temporal viaja solo en el
  /// request y nunca se devuelve en la respuesta; el institutionId se deriva
  /// del token en el servidor, no se envia en el body.
  Future<Map<String, dynamic>> createVaccinator(
    String accessToken, {
    required String email,
    required String fullName,
    required String temporaryPassword,
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

  Map<String, String> _jsonHeaders(String accessToken) => {
    'Authorization': 'Bearer $accessToken',
    'Accept': 'application/json',
    'Content-Type': 'application/json',
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
