import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/utils/document_rules.dart';
import 'package:tu_vacuna_pai/core/utils/field_input.dart';

String applyFormatters(List<TextInputFormatter> formatters, String input) {
  var current = input;
  for (final formatter in formatters) {
    current = formatter
        .formatEditUpdate(
          const TextEditingValue(text: ''),
          TextEditingValue(
            text: current,
            selection: TextSelection.collapsed(offset: current.length),
          ),
        )
        .text;
  }
  return current;
}

void main() {
  test('maxLengthFormatters limita la longitud', () {
    final result = applyFormatters(
      maxLengthFormatters(FieldLimits.name),
      'a' * 200,
    );
    expect(result.length, FieldLimits.name);
  });

  test('phoneFormatters deja solo digitos y limita a 10', () {
    final input = '300abc123+45(x)${'9' * 30}';
    final result = applyFormatters(phoneFormatters(), input);
    expect(RegExp(r'[^0-9]').hasMatch(result), isFalse);
    expect(result.length <= FieldLimits.phone, isTrue);
    expect(FieldLimits.phone, 10);
  });

  test('digitsOnlyFormatters deja solo digitos', () {
    final result = applyFormatters(digitsOnlyFormatters(), '12a3b4');
    expect(result, '1234');
  });

  test('digitsOnlyFormatters respeta la longitud maxima opcional', () {
    final result = applyFormatters(digitsOnlyFormatters(max: 3), '123456789');
    expect(result, '123');
  });

  test('documento de paciente y de personal tienen topes distintos', () {
    expect(FieldLimits.patientDocument, 20);
    expect(FieldLimits.staffDocument, 40);
  });

  test('constantes de catalogo coinciden con el backend', () {
    expect(FieldLimits.vaccineName, 120);
    expect(FieldLimits.vaccineCode, 40);
    expect(FieldLimits.category, 60);
    expect(FieldLimits.optionValue, 120);
    expect(FieldLimits.optionDisplayName, 120);
    expect(FieldLimits.institutionCode, 32);
    expect(FieldLimits.institutionName, 200);
    expect(FieldLimits.reason, 500);
    expect(FieldLimits.password, 128);
  });

  test('cotas numericas de negocio', () {
    expect(FieldLimits.vialCountMin, 0);
    expect(FieldLimits.vialCountMax, 999);
    expect(FieldLimits.maxDosesMin, 1);
    expect(FieldLimits.maxDosesMax, 100);
    expect(FieldLimits.ageMonthsMax, 240);
    expect(FieldLimits.offlineWindowMin, 1);
    expect(FieldLimits.offlineWindowMax, 168);
  });

  test('reglas de documento por tipo', () {
    expect(documentRules, hasLength(13));
    expect(documentRuleFor('CC')!.digitsOnly, isTrue);
    expect(documentRuleFor('CC')!.minLength, 6);
    expect(documentRuleFor('CC')!.maxLength, 10);
    expect(documentRuleFor('TI')!.maxLength, 11);
    expect(documentRuleFor('CE')!.digitsOnly, isFalse);
    expect(documentRuleFor('CE')!.minLength, 4);
    expect(documentRuleFor('CE')!.maxLength, 20);
    expect(documentRuleFor('zz'), isNull);
  });
}
