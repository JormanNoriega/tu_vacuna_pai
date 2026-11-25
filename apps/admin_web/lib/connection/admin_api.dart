import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Acceso exclusivamente online a Spring. No conserva tokens ni datos.
class AdminApi {
  AdminApi(
    this.baseUrl, {
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  Future<Map<String, dynamic>> fetchMe(String accessToken) async {
    final body = await _get(accessToken, '/me');
    if (body is! Map<String, dynamic>) {
      throw const AdminApiException('Respuesta de perfil inválida.');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> fetchCatalog(
    String accessToken, {
    required String? institutionId,
  }) async {
    final path = institutionId == null
        ? '/catalogs/vaccines'
        : '/institutions/${Uri.encodeComponent(institutionId)}/vaccines';
    final body = await _get(accessToken, path);
    if (body is! List || !body.every((item) => item is Map<String, dynamic>)) {
      throw const AdminApiException('Respuesta de catálogo inválida.');
    }
    return body.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchUsers(
    String accessToken, {
    required String institutionId,
  }) async {
    final body = await _get(
      accessToken,
      '/users',
      query: {'institutionId': institutionId, 'roles': 'VACCINATOR,READ_ONLY'},
    );
    if (body is! List || !body.every((item) => item is Map<String, dynamic>)) {
      throw const AdminApiException('Respuesta de usuarios inválida.');
    }
    return body.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> updateUserStatus(
    String token, {
    required String userId,
    required String status,
  }) async {
    if (token.trim().isEmpty ||
        userId.trim().isEmpty ||
        !const {'ACTIVE', 'INACTIVE'}.contains(status)) {
      throw const AdminApiException('Solicitud de estado inválida.');
    }
    final path =
        '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/users/${Uri.encodeComponent(userId)}/status';
    try {
      final request =
          http.Request('PUT', baseUrl.replace(path: path, query: null))
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            })
            ..body = jsonEncode({'status': status});
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AdminApiException(
          'No se pudo actualizar el estado.',
          statusCode: response.statusCode,
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['id'] != userId ||
          body['status'] != status) {
        throw const AdminApiException('Respuesta de estado inválida.');
      }
      return body;
    } on TimeoutException {
      throw const AdminApiException(
        'No se confirmó el cambio. Actualiza la lista antes de reintentar.',
      );
    } on http.ClientException {
      throw const AdminApiException(
        'No se confirmó el cambio. Actualiza la lista antes de reintentar.',
      );
    } on FormatException {
      throw const AdminApiException(
        'Respuesta del servidor inválida. Actualiza la lista.',
      );
    }
  }

  Future<Map<String, dynamic>> fetchMetrics(String accessToken) async {
    final body = await _get(accessToken, '/metrics/summary');
    if (body is! Map<String, dynamic>) {
      throw const AdminApiException('Respuesta de métricas inválida.');
    }
    return body;
  }

  Future<Map<String, dynamic>> fetchHistory(
    String token, {
    required DateTime from,
    required DateTime to,
    required int page,
  }) async {
    final body = await _get(
      token,
      '/attention-history',
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
        'page': '$page',
      },
    );
    if (body is! Map<String, dynamic> ||
        body['items'] is! List ||
        !(body['items'] as List).every(
          (item) => item is Map<String, dynamic>,
        ) ||
        body['hasNext'] is! bool) {
      throw const AdminApiException('Respuesta de historial inválida.');
    }
    return body;
  }

  Future<List<Map<String, dynamic>>> searchPatients(
    String token, {
    required String documentNumber,
    String? documentType,
  }) async {
    final number = documentNumber.trim();
    if (number.isEmpty) {
      throw const AdminApiException('Escribe el número de documento.');
    }
    final body = await _get(
      token,
      '/patients',
      query: {
        if (documentType != null && documentType.trim().isNotEmpty)
          'documentType': documentType.trim(),
        'documentNumber': number,
      },
    );
    if (body is! List || !body.every((item) => item is Map<String, dynamic>)) {
      throw const AdminApiException('Respuesta de pacientes inválida.');
    }
    return body.cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> fetchPatientAttentions(
    String token, {
    required String patientId,
  }) async {
    if (patientId.trim().isEmpty) {
      throw const AdminApiException('Falta el identificador del paciente.');
    }
    final body = await _get(
      token,
      '/attentions',
      query: {'patientId': patientId},
    );
    if (body is! List || !body.every((item) => item is Map<String, dynamic>)) {
      throw const AdminApiException('Respuesta de atenciones inválida.');
    }
    return body.cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> fetchReportSummary(
    String token, {
    required DateTime from,
    required DateTime to,
  }) async {
    final body = await _get(
      token,
      '/reports/registro-diario/summary',
      query: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    if (body is! Map<String, dynamic> ||
        ![
          'patientsCount',
          'dosesCount',
          'vaccineTypesCount',
        ].every((key) => body[key] is int && (body[key] as int) >= 0)) {
      throw const AdminApiException(
        'Respuesta del resumen de exportación inválida.',
      );
    }
    return body;
  }

  Future<AdminReport> downloadReport(
    String token, {
    required DateTime from,
    required DateTime to,
    required String format,
  }) async {
    if (!const {'xlsx', 'csv'}.contains(format)) {
      throw const AdminApiException('Formato de reporte no válido.');
    }
    final query = {
      'from': from.toUtc().toIso8601String(),
      'to': to.toUtc().toIso8601String(),
      'format': format,
    };
    final path =
        '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/reports/registro-diario';
    try {
      final request =
          http.Request(
              'GET',
              baseUrl.replace(path: path, queryParameters: query),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $token',
              'Accept': format == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            });
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AdminApiException(
          'No se pudo generar el reporte.',
          statusCode: response.statusCode,
        );
      }
      if (response.bodyBytes.isEmpty) {
        throw const AdminApiException('El reporte llegó vacío.');
      }
      final disposition = response.headers['content-disposition'] ?? '';
      final match = RegExp(
        r'filename="?([^";]+)"?',
        caseSensitive: false,
      ).firstMatch(disposition);
      final candidate = match?.group(1)?.trim() ?? 'registro-diario.$format';
      final filename = candidate
          .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
          .replaceAll('..', '_');
      return AdminReport(
        bytes: response.bodyBytes,
        filename: filename.isEmpty ? 'registro-diario.$format' : filename,
        contentType:
            response.headers['content-type'] ??
            (format == 'csv' ? 'text/csv' : 'application/octet-stream'),
      );
    } on TimeoutException {
      throw const AdminApiException(
        'El servidor tardó demasiado en generar el reporte.',
      );
    } on http.ClientException {
      throw const AdminApiException(
        'No se pudo conectar para descargar el reporte.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchInventoryList(
    String token, {
    required String institutionId,
    required String resource,
  }) async {
    if (!const {
      'lots',
      'movements',
      'pending-follow-ups',
      'assignments',
      'campaigns',
      'custody-events',
    }.contains(resource)) {
      throw const AdminApiException('Consulta de inventario inválida.');
    }
    final body = await _get(
      token,
      '/institutions/${Uri.encodeComponent(institutionId)}/inventory/$resource',
    );
    if (body is! List || !body.every((item) => item is Map<String, dynamic>)) {
      throw const AdminApiException('Respuesta de inventario inválida.');
    }
    return body.cast<Map<String, dynamic>>();
  }

  Future<dynamic> _get(
    String accessToken,
    String resource, {
    Map<String, String>? query,
  }) async {
    if (accessToken.trim().isEmpty) {
      throw const AdminApiException('Falta la sesión.');
    }
    final path = '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}$resource';
    try {
      final request =
          http.Request(
              'GET',
              baseUrl.replace(path: path, queryParameters: query),
            )
            ..followRedirects = false
            ..headers.addAll({
              'Authorization': 'Bearer $accessToken',
              'Accept': 'application/json',
            });
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw AdminApiException(
          'No se pudo completar la consulta.',
          statusCode: response.statusCode,
        );
      }
      return jsonDecode(response.body);
    } on TimeoutException {
      throw const AdminApiException('El servidor no respondió a tiempo.');
    } on http.ClientException {
      throw const AdminApiException('No se pudo conectar con el servidor.');
    } on FormatException {
      throw const AdminApiException('Respuesta del servidor inválida.');
    }
  }

  void close() => _client.close();
}

class AdminApiException implements Exception {
  const AdminApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  @override
  String toString() => message;
}

class AdminReport {
  const AdminReport({
    required this.bytes,
    required this.filename,
    required this.contentType,
  });

  final List<int> bytes;
  final String filename;
  final String contentType;
}
