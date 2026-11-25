import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_admin_web/connection/admin_api.dart';

void main() {
  test('busca pacientes y sus atenciones con parámetros escapados', () async {
    final paths = <String>[];
    final api = AdminApi(
      Uri.parse('https://example.test/api/v1'),
      client: MockClient((request) async {
        paths.add(request.url.toString());
        expect(request.headers['Authorization'], 'Bearer token');
        if (request.url.path.endsWith('/patients')) {
          expect(request.url.queryParameters, {
            'documentType': 'CC',
            'documentNumber': '10 20+',
          });
          return http.Response(
            '[{"id":"p-1","firstName":"Ana","documentNumber":"10 20+"}]',
            200,
          );
        }
        expect(request.url.path, '/api/v1/attentions');
        expect(request.url.queryParameters, {'patientId': 'p-1'});
        return http.Response('[{"id":"a-1","doses":[]}]', 200);
      }),
    );
    addTearDown(api.close);

    final patients = await api.searchPatients(
      'token',
      documentType: 'CC',
      documentNumber: '10 20+',
    );
    final attentions = await api.fetchPatientAttentions(
      'token',
      patientId: 'p-1',
    );
    expect(patients.single['id'], 'p-1');
    expect(attentions.single['id'], 'a-1');
    expect(paths, hasLength(2));
  });

  test('resume y descarga el reporte con cabeceras y nombre saneado', () async {
    final api = AdminApi(
      Uri.parse('https://example.test/api/v1'),
      client: MockClient((request) async {
        expect(request.headers['Authorization'], 'Bearer token');
        if (request.url.path.endsWith('/summary')) {
          expect(request.url.path, '/api/v1/reports/registro-diario/summary');
          return http.Response(
            '{"patientsCount":2,"dosesCount":4,"vaccineTypesCount":3}',
            200,
          );
        }
        expect(request.url.path, '/api/v1/reports/registro-diario');
        expect(request.url.queryParameters['format'], 'csv');
        return http.Response.bytes(
          [0xEF, 0xBB, 0xBF, 65],
          200,
          headers: {
            'content-type': 'text/csv; charset=UTF-8',
            'content-disposition': 'attachment; filename="../reporte.csv"',
          },
        );
      }),
    );
    addTearDown(api.close);
    final from = DateTime.utc(2026, 1, 1);
    final to = DateTime.utc(2026, 1, 31);

    final summary = await api.fetchReportSummary('token', from: from, to: to);
    final report = await api.downloadReport(
      'token',
      from: from,
      to: to,
      format: 'csv',
    );

    expect(summary['dosesCount'], 4);
    expect(report.filename, '_reporte.csv');
    expect(report.contentType, contains('text/csv'));
    expect(report.bytes, [0xEF, 0xBB, 0xBF, 65]);
  });

  test(
    'no permite documento vacío ni formatos de exportación arbitrarios',
    () async {
      var calls = 0;
      final api = AdminApi(
        Uri.parse('https://example.test/api/v1'),
        client: MockClient((_) async {
          calls++;
          return http.Response('[]', 200);
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.searchPatients('token', documentNumber: '  '),
        throwsA(isA<AdminApiException>()),
      );
      await expectLater(
        api.downloadReport(
          'token',
          from: DateTime.utc(2026),
          to: DateTime.utc(2026, 1, 2),
          format: 'pdf',
        ),
        throwsA(isA<AdminApiException>()),
      );
      expect(calls, 0);
    },
  );
}
