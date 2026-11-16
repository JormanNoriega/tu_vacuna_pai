package com.pai.api.inventory.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import org.junit.jupiter.api.Test;

class DisposablePostgresConfigTest {
  private static final String DATABASE = "pai_inventory_test_0123456789abcdef0123456789abcdef";

  @Test
  void acceptsOnlyExplicitDedicatedLocalConfiguration() {
    assertThat(DisposablePostgresConfig.validate("jdbc:postgresql://127.0.0.1:5432/" + DATABASE,
        "pai_inventory_test_runner", "secret")).isEqualTo(DATABASE);
    for (String url : new String[] {
        "jdbc:postgresql://production.example:5432/" + DATABASE,
        "jdbc:postgresql://localhost:5432/" + DATABASE,
        "jdbc:postgresql://127.0.0.1:5432/postgres",
        "jdbc:postgresql://127.0.0.1:5432/" + DATABASE + "?host=production.example",
        "jdbc:postgresql://127.0.0.1:5432," + "production.example:5432/" + DATABASE}) {
      assertThatThrownBy(() -> DisposablePostgresConfig.validate(url, "pai_inventory_test_runner", "secret"))
          .isInstanceOf(IllegalArgumentException.class);
    }
    assertThatThrownBy(() -> DisposablePostgresConfig.validate(
        "jdbc:postgresql://127.0.0.1:5432/" + DATABASE, "postgres", "secret"))
        .isInstanceOf(IllegalArgumentException.class);
    assertThatThrownBy(() -> DisposablePostgresConfig.validate(
        "jdbc:postgresql://127.0.0.1:5432/" + DATABASE, "pai_inventory_test_runner", ""))
        .isInstanceOf(IllegalArgumentException.class);
  }
}
