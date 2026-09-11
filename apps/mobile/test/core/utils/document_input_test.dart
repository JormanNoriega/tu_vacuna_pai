import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tu_vacuna_pai/core/utils/document_input.dart';

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
    test('CC y TI usan teclado numerico', () {
      expect(documentKeyboardType('CC'), TextInputType.number);
      expect(documentKeyboardType('TI'), TextInputType.number);
    });

    test('CE y PASAPORTE usan teclado de texto', () {
      expect(documentKeyboardType('CE'), TextInputType.text);
      expect(documentKeyboardType('PASAPORTE'), TextInputType.text);
    });
  });

  group('documentInputFormatters', () {
    test('CC solo admite digitos', () {
      final result = applyFormatters(
        documentInputFormatters('CC'),
        '12ab34',
      );
      expect(result, '1234');
    });

    test('CE/PASAPORTE admiten letras y digitos', () {
      final result = applyFormatters(
        documentInputFormatters('PASAPORTE'),
        'AB12!!cd',
      );
      expect(result, 'AB12cd');
    });

    test('limita a 10 caracteres', () {
      final result = applyFormatters(
        documentInputFormatters('CC'),
        '12345678901234',
      );
      expect(result, '1234567890');
    });
  });
}
