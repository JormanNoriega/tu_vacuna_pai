import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/utils/document_input.dart';
import 'package:tu_vacuna_pai/core/utils/document_rules.dart';

void main() {
  /// Aplica los formatters en cadena y devuelve el texto resultante.
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

  group('documentKeyboardType', () {
    test('tipos numericos usan teclado numerico', () {
      for (final type in ['CC', 'TI', 'RC', 'CN']) {
        expect(documentKeyboardType(type), TextInputType.number, reason: type);
      }
    });

    test('tipos alfanumericos usan teclado de texto', () {
      for (final type in [
        'CE',
        'PA',
        'PPT',
        'PE',
        'SC',
        'CD',
        'DE',
        'AS',
        'MS',
      ]) {
        expect(documentKeyboardType(type), TextInputType.text, reason: type);
      }
    });
  });

  group('documentInputFormatters', () {
    test('tipos numericos solo admiten digitos', () {
      for (final type in ['CC', 'TI', 'RC', 'CN']) {
        final result = applyFormatters(documentInputFormatters(type), '12ab34');
        expect(result, '1234', reason: type);
      }
    });

    test('tipos alfanumericos admiten letras y digitos', () {
      for (final type in ['CE', 'PA', 'PPT', 'AS', 'MS']) {
        final result = applyFormatters(
          documentInputFormatters(type),
          'AB12!!cd',
        );
        expect(result, 'AB12cd', reason: type);
      }
    });

    test('limita a la longitud maxima del tipo', () {
      // CC -> 10
      expect(
        applyFormatters(
          documentInputFormatters('CC'),
          '123456789012345',
        ).length,
        documentRuleFor('CC')!.maxLength,
      );
      // CE -> 20
      expect(
        applyFormatters(documentInputFormatters('CE'), 'A' * 30).length,
        documentRuleFor('CE')!.maxLength,
      );
    });

    test('tipo desconocido cae al tope por defecto', () {
      expect(
        applyFormatters(documentInputFormatters('ZZ'), '1' * 30).length,
        20,
      );
    });
  });
}
