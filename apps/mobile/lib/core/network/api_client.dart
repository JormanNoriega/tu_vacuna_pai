import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'me_response.dart';

/// Cliente HTTP de la API Spring. Enviar el JWT de Supabase como Bearer token
/// y decodificar las respuestas de negocio.
class ApiClient {
  ApiClient({required this.baseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final String baseUrl;
  final http.Client _http;

  /// Obtiene el perfil autorizado del usuario autenticado.
  Future<MeResponse> fetchMe(String accessToken) async {
    final uri = Uri.parse('$baseUrl/me');
    final response = await _http.get(uri, headers: {
      'Authorization': 'Bearer $accessToken',
      'Accept': 'application/json',
    });

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      return MeResponse.fromJson(body);
    }

    throw ApiException(
      _messageFromBody(response.body) ?? 'Error al consultar el perfil.',
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