package com.pai.api.shared.util;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.junit.jupiter.params.provider.ValueSource;

class DocumentNormalizerTest {

  @Test
  void normalizesSeparatorsAndCase() {
    assertThat(DocumentNormalizer.normalize("12.345.678")).isEqualTo("12345678");
    assertThat(DocumentNormalizer.normalize(" ab-12 ")).isEqualTo("AB12");
    assertThat(DocumentNormalizer.normalize("   ")).isNull();
    assertThat(DocumentNormalizer.normalize(null)).isNull();
  }

  @Test
  void everyCatalogTypeHasARule() {
    List<String> types =
        List.of("CC", "TI", "RC", "CN", "CE", "PA", "PPT", "PE", "SC", "CD", "DE", "AS", "MS");
    assertThat(types)
        .allSatisfy(type -> assertThat(DocumentNormalizer.ruleFor(type)).isNotNull());
    assertThat(DocumentNormalizer.ruleFor("XX")).isNull();
  }

  @ParameterizedTest
  @CsvSource({
    // CC: solo digitos 6-10
    "CC, 12345, false",
    "CC, 123456, true",
    "CC, 1234567890, true",
    "CC, 12345678901, false",
    "CC, ABC123, false",
    // TI/RC/CN: solo digitos 6-11
    "TI, 12345, false",
    "TI, 123456, true",
    "TI, 12345678901, true",
    "TI, 123456789012, false",
    "TI, ABC123, false",
    "RC, 12345, false",
    "RC, 123456, true",
    "RC, 12345678901, true",
    "RC, 123456789012, false",
    "RC, ABC123, false",
    "CN, 12345, false",
    "CN, 123456, true",
    "CN, 12345678901, true",
    "CN, 123456789012, false",
    "CN, ABC123, false",
    // Alfanumericos 4-20
    "CE, ABC, false",
    "CE, AB12, true",
    "CE, ABCDEFGHIJ1234567890, true",
    "CE, ABCDEFGHIJ12345678901, false",
    "PA, AB12, true",
    "PPT, AB12, true",
    "PE, AB12, true",
    "SC, AB12, true",
    "CD, AB12, true",
    "DE, AB12, true",
    "AS, AB12, true",
    "MS, AB12, true",
    // tipo desconocido
    "XX, 123456, false",
  })
  void validatesPerType(String type, String number, boolean expected) {
    assertThat(DocumentNormalizer.isValidForType(DocumentNormalizer.normalize(number), type))
        .isEqualTo(expected);
  }

  @ParameterizedTest
  @ValueSource(strings = {"CC", "TI", "RC", "CN"})
  void numericTypesRejectAlphanumeric(String type) {
    assertThat(DocumentNormalizer.isValidForType("12345A", type)).isFalse();
    assertThat(DocumentNormalizer.isValidForType("AB1234", type)).isFalse();
  }

  @Test
  void rejectsNullOrEmpty() {
    assertThat(DocumentNormalizer.isValidForType(null, "CC")).isFalse();
    assertThat(DocumentNormalizer.isValidForType("123456", null)).isFalse();
  }
}
