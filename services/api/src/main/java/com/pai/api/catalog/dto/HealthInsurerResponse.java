package com.pai.api.catalog.dto;

import java.util.UUID;

/** Aseguradora en salud (EPS) del catalogo global. */
public record HealthInsurerResponse(UUID id, String nit, String name, String code, String regime) {}
