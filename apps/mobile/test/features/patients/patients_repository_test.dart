import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:tu_vacuna_pai/core/network/api_client.dart';
import 'package:tu_vacuna_pai/features/patients/data/patients_repository_impl.dart';
import 'package:tu_vacuna_pai/features/patients/domain/entities/new_patient.dart';

void main() {
  test('crea un paciente con el perfil completo', () async {
    late Map<String, dynamic> captured;
    final mockClient = MockClient((request) async {
      captured = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 'p1',
          'documentType': 'CC',
          'documentNumber': '12345678',
          'firstName': 'Ana',
          'lastName': 'Diaz',
          'birthDate': '2021-01-02',
          'sex': 'FEMALE',
          'status': 'ACTIVE',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      httpClient: mockClient,
    );
    final repository = PatientsRepositoryImpl(api);

    await repository.create(
      'token-123',
      input: const NewPatientInput(
        documentType: 'CC',
        documentNumber: '12345678',
        firstName: 'Ana',
        lastName: 'Diaz',
        birthDate: '2021-01-02',
        sex: 'FEMALE',
        demographics: NewPatientDemographic(
          gender: 'FEMALE',
          ethnicity: 'Mestiza',
        ),
        contacts: [
          NewPatientContact(type: 'PHONE', value: '3001234567', primary: true),
          NewPatientContact(type: 'EMAIL', value: 'ana@test.com'),
        ],
        addresses: [
          NewPatientAddress(
            street: 'Calle 1',
            departmentId: 'dept-1',
            municipalityId: 'mun-1',
          ),
        ],
        guardians: [
          NewPatientGuardian(
            relationship: 'MOTHER',
            fullName: 'Maria',
            phone: '301',
          ),
        ],
        medicalHistories: [
          NewPatientMedicalHistory(
            condition: 'Asma',
            diagnosedAt: '2020-01-01',
          ),
        ],
      ),
      operationId: 'op-1',
    );

    expect(captured['documentNumber'], '12345678');
    expect(captured['sex'], 'FEMALE');
    expect(captured['demographics']['gender'], 'FEMALE');
    expect(captured['demographics']['ethnicity'], 'Mestiza');
    expect(captured['contacts'], hasLength(2));
    expect(captured['addresses'], hasLength(1));
    expect(captured['addresses'][0]['departmentId'], 'dept-1');
    expect(captured['addresses'][0]['municipalityId'], 'mun-1');
    expect(captured['guardians'][0]['relationship'], 'MOTHER');
    expect(captured['medicalHistories'][0]['condition'], 'Asma');
  });

  test('omite los bloques opcionales vacios', () async {
    late Map<String, dynamic> captured;
    final mockClient = MockClient((request) async {
      captured = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'id': 'p1',
          'documentType': 'TI',
          'documentNumber': '99',
          'firstName': 'Bebe',
          'lastName': 'Perez',
          'birthDate': '2024-01-01',
          'sex': 'MALE',
          'status': 'ACTIVE',
        }),
        201,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = ApiClient(
      baseUrl: 'http://localhost:8080/api/v1',
      httpClient: mockClient,
    );
    final repository = PatientsRepositoryImpl(api);

    await repository.create(
      'token-123',
      input: const NewPatientInput(
        documentType: 'TI',
        documentNumber: '99',
        firstName: 'Bebe',
        lastName: 'Perez',
        birthDate: '2024-01-01',
        sex: 'MALE',
      ),
    );

    expect(captured.containsKey('demographics'), isFalse);
    expect(captured.containsKey('contacts'), isFalse);
    expect(captured.containsKey('addresses'), isFalse);
    expect(captured.containsKey('guardians'), isFalse);
    expect(captured.containsKey('medicalHistories'), isFalse);
  });
}
