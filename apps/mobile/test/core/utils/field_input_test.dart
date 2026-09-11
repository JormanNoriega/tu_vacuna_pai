import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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

  test('phoneFormatters permite solo digitos y simbolos y limita', () {
    final input = '300abc123+45(x)${'9' * 30}';
    final result = applyFormatters(phoneFormatters(), input);
    expect(result.contains(RegExp(r'[a-zA-Z]')), isFalse);
    expect(result.length <= FieldLimits.phone, isTrue);
  });
}
