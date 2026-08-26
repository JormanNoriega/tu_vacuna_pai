package com.pai.api.identity.service;

import java.time.Instant;
import java.util.List;
import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.pai.api.identity.dto.CreateInstitutionRequest;
import com.pai.api.identity.dto.InstitutionResponse;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.shared.exceptions.InstitutionCodeAlreadyExistsException;
import com.pai.api.shared.exceptions.InstitutionNotFoundException;

/**
 * Gestion de instituciones. Escrituras exclusivas de {@code SUPER_ADMIN}
 * (permiso {@code INSTITUTION_WRITE}); la autorizacion se valida en el
 * controller con {@code @PreAuthorize}.
 */
@Service
public class InstitutionService {

    private final InstitutionRepository institutionRepository;

    public InstitutionService(InstitutionRepository institutionRepository) {
        this.institutionRepository = institutionRepository;
    }

    @Transactional
    public InstitutionResponse create(CreateInstitutionRequest request) {
        String code = request.code().trim().toUpperCase();
        String name = request.name().trim();
        short offlineWindowHours = request.offlineWindowHours() == null
                ? (short) 72
                : request.offlineWindowHours();

        institutionRepository.findByCode(code).ifPresent(existing -> {
            throw new InstitutionCodeAlreadyExistsException(
                "Ya existe una institucion con el codigo " + code + ".");
        });

        Instant now = Instant.now();
        InstitutionEntity entity = new InstitutionEntity(
            UUID.randomUUID(),
            code,
            name,
            InstitutionEntity.Status.ACTIVE,
            offlineWindowHours,
            now,
            now);

        InstitutionEntity saved = institutionRepository.save(entity);
        return toResponse(saved);
    }

    @Transactional(readOnly = true)
    public List<InstitutionResponse> list() {
        return institutionRepository.findAllByOrderByNameAsc().stream()
            .map(this::toResponse)
            .toList();
    }

    @Transactional
    public InstitutionResponse updateStatus(UUID id, String status) {
        InstitutionEntity entity = institutionRepository.findById(id)
            .orElseThrow(() -> new InstitutionNotFoundException(
                "La institucion no existe."));

        InstitutionEntity.Status parsed;
        try {
            parsed = InstitutionEntity.Status.valueOf(status.trim().toUpperCase());
        } catch (IllegalArgumentException ex) {
            throw new IllegalArgumentException(
                "Estado invalido. Usa ACTIVE o INACTIVE.");
        }

        entity.setStatus(parsed);
        entity.setUpdatedAt(Instant.now());
        return toResponse(institutionRepository.save(entity));
    }

    @Transactional
    public InstitutionResponse updateConfig(UUID id, short offlineWindowHours) {
        if (offlineWindowHours < 1 || offlineWindowHours > 168) {
            throw new IllegalArgumentException(
                "La ventana offline debe estar entre 1 y 168 horas.");
        }

        InstitutionEntity entity = institutionRepository.findById(id)
            .orElseThrow(() -> new InstitutionNotFoundException(
                "La institucion no existe."));

        entity.setOfflineWindowHours(offlineWindowHours);
        entity.setUpdatedAt(Instant.now());
        return toResponse(institutionRepository.save(entity));
    }

    private InstitutionResponse toResponse(InstitutionEntity entity) {
        return new InstitutionResponse(
            entity.getId(),
            entity.getCode(),
            entity.getName(),
            entity.getStatus().name(),
            entity.getOfflineWindowHours());
    }
}
