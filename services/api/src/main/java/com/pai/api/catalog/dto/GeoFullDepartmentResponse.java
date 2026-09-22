package com.pai.api.catalog.dto;

import java.util.List;
import java.util.UUID;

/**
 * Departamento con sus municipios (con UUID), para precargar el catalogo
 * geografico completo en el cliente offline.
 */
public record GeoFullDepartmentResponse(
    UUID id, String code, String name, List<GeoMunicipalityResponse> municipalities) {}
