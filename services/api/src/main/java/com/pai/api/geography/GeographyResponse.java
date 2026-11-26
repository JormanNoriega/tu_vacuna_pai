package com.pai.api.geography;

import java.time.Instant;
import java.time.LocalDate;
import java.util.List;

public record GeographyResponse(
    int days, LocalDate referenceDate, Instant generatedAt, List<Cell> cells) {
  public record Cell(double latitude, double longitude, long count) {}
}
