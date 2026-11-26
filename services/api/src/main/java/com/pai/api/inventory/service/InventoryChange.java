package com.pai.api.inventory.service;

import java.util.UUID;

/** Identificadores mínimos para avisar que debe consultarse de nuevo la API. */
public record InventoryChange(String type, UUID institutionId, UUID assignmentId,
    UUID eventId, UUID vaccinatorId) {}
