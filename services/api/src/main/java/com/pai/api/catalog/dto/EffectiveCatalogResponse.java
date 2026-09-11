package com.pai.api.catalog.dto;

import java.util.List;
import java.util.UUID;

/**
 * Catalogo efectivo para el formulario clinico: solo las vacunas habilitadas en
 * la institucion del actor, con sus dosis globales, tipos de neumococo y
 * opciones operativas institucionales. Evita que el cliente combine varios
 * endpoints (N+1) y mantiene el alcance calculado en el servidor.
 */
public record EffectiveCatalogResponse(List<EffectiveVaccine> vaccines) {

    public record EffectiveVaccine(
            UUID vaccineId,
            String name,
            String code,
            String category,
            short maxDoses,
            Integer minAgeMonths,
            Integer maxAgeMonths,
            long version,
            boolean hasLaboratory,
            boolean hasLot,
            boolean hasSyringe,
            boolean hasSyringeLot,
            boolean hasDiluent,
            boolean hasDropper,
            boolean hasPneumococcalType,
            boolean hasVialCount,
            boolean hasObservation,
            List<OptionItem> doses,
            List<OptionItem> pneumococcalTypes,
            List<OptionItem> operationalOptions) {}

    public record OptionItem(
            UUID id, String fieldType, String value, String displayName, int sortOrder, boolean isDefault) {}
}
