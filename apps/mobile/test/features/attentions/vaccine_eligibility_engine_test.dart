import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/features/attentions/domain/services/vaccine_eligibility_engine.dart';
import 'package:tu_vacuna_pai/features/catalogs/domain/entities/effective_catalog.dart';

void main() {
  EffectiveVaccine createVaccine(
    String code, {
    String name = 'Test Vaccine',
    List<String> doses = const ['Dosis 1', 'Dosis 2'],
  }) {
    return EffectiveVaccine(
      vaccineId: 'vac-$code',
      name: name,
      code: code,
      category: 'PAI',
      maxDoses: doses.length,
      version: 1,
      doses: [
        for (int i = 0; i < doses.length; i++)
          EffectiveOption(
            id: 'dose-$i',
            fieldType: 'dose',
            value: doses[i],
            displayName: doses[i],
            sortOrder: i,
            isDefault: i == 0,
          ),
      ],
      pneumococcalTypes: const [],
      operationalOptions: const [],
    );
  }

  group('VaccineEligibilityEngine - Reglas PAI Colombia', () {
    final attentionDate = DateTime(2026, 11, 8);

    test('Recién nacido (10 días) solo recibe biológicos neonatales', () {
      final birthDate = DateTime(2026, 10, 29); // 10 días
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      expect(ctx.ageInDays, 10);
      expect(ctx.ageInMonths, 0);

      final bcg = createVaccine('bcg');
      final hepB = createVaccine('hepatitis_b');
      final penta = createVaccine('pentavalente');
      final rota = createVaccine('rotavirus');
      final srp = createVaccine('srp');

      expect(VaccineEligibilityEngine.isEligible(bcg, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(hepB, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(penta, ctx), isFalse);
      expect(VaccineEligibilityEngine.isEligible(rota, ctx), isFalse);
      expect(VaccineEligibilityEngine.isEligible(srp, ctx), isFalse);
    });

    test('Lactante a los 2 meses (65 días) habilita esquema primario', () {
      final birthDate = DateTime(2026, 9, 4); // ~65 días
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final penta = createVaccine('pentavalente');
      final polio = createVaccine('polio_ipv');
      final rota = createVaccine('rotavirus');
      final neumo = createVaccine('neumococo');
      final vph = createVaccine('vph');

      expect(VaccineEligibilityEngine.isEligible(penta, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(polio, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(rota, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(neumo, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(vph, ctx), isFalse);
    });

    group('Regla estricta de Rotavirus', () {
      test('1ra dosis permitida hasta 3 meses y 21 días (111 días)', () {
        // 100 días -> permitido
        final ctxPermitido = PatientEligibilityContext.fromDates(
          birthDate: attentionDate.subtract(const Duration(days: 100)),
          attentionDate: attentionDate,
        );
        expect(
          VaccineEligibilityEngine.isEligible(
            createVaccine('rotavirus'),
            ctxPermitido,
          ),
          isTrue,
        );

        // 115 días -> superó 3 meses y 21 días sin 1ra dosis -> NO permitido
        final ctxVencido = PatientEligibilityContext.fromDates(
          birthDate: attentionDate.subtract(const Duration(days: 115)),
          attentionDate: attentionDate,
        );
        expect(
          VaccineEligibilityEngine.isEligible(
            createVaccine('rotavirus'),
            ctxVencido,
          ),
          isFalse,
        );
      });

      test('2da dosis permitida si tiene 1ra dosis registrada previamente', () {
        final rota = createVaccine(
          'rotavirus',
          doses: ['Primera dosis', 'Segunda dosis'],
        );

        // Lactante de 6 meses CON 1ra dosis
        final ctxConDosis1 = PatientEligibilityContext.fromDates(
          birthDate: DateTime(2026, 5, 8), // 6 meses
          attentionDate: attentionDate,
          appliedDoseKeys: {'rotavirus_primera_dosis'},
        );

        expect(VaccineEligibilityEngine.isEligible(rota, ctxConDosis1), isTrue);
        expect(
          VaccineEligibilityEngine.isDoseEligible(
            rota,
            rota.doses[1],
            ctxConDosis1,
          ),
          isTrue,
        );

        // Lactante de 6 meses SIN 1ra dosis
        final ctxSinDosis1 = PatientEligibilityContext.fromDates(
          birthDate: DateTime(2026, 5, 8),
          attentionDate: attentionDate,
        );

        expect(
          VaccineEligibilityEngine.isEligible(rota, ctxSinDosis1),
          isFalse,
        );
        expect(
          VaccineEligibilityEngine.isDoseEligible(
            rota,
            rota.doses[1],
            ctxSinDosis1,
          ),
          isFalse,
        );
        expect(
          VaccineEligibilityEngine.getDoseIneligibilityWarning(
            rota,
            rota.doses[1],
            ctxSinDosis1,
          ),
          isNotNull,
        );
      });
    });

    test('Niño de 12 meses (1 año) habilita SRP, Varicela y Hepatitis A', () {
      final birthDate = DateTime(2025, 11, 8); // 12 meses exactos
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final srp = createVaccine('srp');
      final varicela = createVaccine('varicela');
      final hepA = createVaccine('hepatitis_a_pediatrica');
      final bcg = createVaccine('bcg');

      expect(VaccineEligibilityEngine.isEligible(srp, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(varicela, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(hepA, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(bcg, ctx), isFalse);
    });

    test('Niño de 18 meses habilita Fiebre Amarilla y 1er Refuerzo', () {
      final birthDate = DateTime(2025, 5, 8); // 18 meses
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final fiebreAmarilla = createVaccine('fiebre_amarilla');
      final penta = createVaccine('pentavalente');
      final polio = createVaccine('polio_ipv');

      expect(VaccineEligibilityEngine.isEligible(fiebreAmarilla, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(penta, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(polio, ctx), isTrue);
    });

    test('Niño de 5 años (60 meses) habilita 2dos refuerzos DPT y Polio', () {
      final birthDate = DateTime(2021, 11, 8); // 5 años
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final dpt = createVaccine('dpt');
      final polio = createVaccine('polio_ipv');
      final varicela = createVaccine('varicela');
      final rota = createVaccine('rotavirus');

      expect(VaccineEligibilityEngine.isEligible(dpt, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(polio, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(varicela, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(rota, ctx), isFalse);
    });

    test('Adolescente de 12 años habilita VPH y Td Adulto', () {
      final birthDate = DateTime(2014, 11, 8); // 12 años
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final vph = createVaccine('vph');
      final td = createVaccine('td_adulto');
      final rota = createVaccine('rotavirus');
      final penta = createVaccine('pentavalente');

      expect(VaccineEligibilityEngine.isEligible(vph, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(td, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(rota, ctx), isFalse);
      expect(VaccineEligibilityEngine.isEligible(penta, ctx), isFalse);
    });

    test('Gestante de 28 semanas habilita dTpa Adulto e Influenza', () {
      final birthDate = DateTime(1998, 5, 20); // 28 años
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
        userCondition: 'GESTANTE',
        gestationalWeeks: 28,
      );

      final dtpa = createVaccine('dtpa_adulto');
      final influenza = createVaccine('influenza');
      final td = createVaccine('td_adulto');
      final penta = createVaccine('pentavalente');

      expect(VaccineEligibilityEngine.isEligible(dtpa, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(influenza, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(td, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(penta, ctx), isFalse);
    });

    test('Adulto mayor de 65 años habilita Influenza obligatoria', () {
      final birthDate = DateTime(1961, 3, 10); // 65 años
      final ctx = PatientEligibilityContext.fromDates(
        birthDate: birthDate,
        attentionDate: attentionDate,
      );

      final influenza = createVaccine('influenza');
      final vph = createVaccine('vph');
      final rota = createVaccine('rotavirus');

      expect(VaccineEligibilityEngine.isEligible(influenza, ctx), isTrue);
      expect(VaccineEligibilityEngine.isEligible(vph, ctx), isFalse);
      expect(VaccineEligibilityEngine.isEligible(rota, ctx), isFalse);
    });
  });
}
