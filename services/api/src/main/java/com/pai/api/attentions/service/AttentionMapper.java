package com.pai.api.attentions.service;

import com.pai.api.attentions.dto.AppliedDoseResponse;
import com.pai.api.attentions.dto.AttentionResponse;
import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import java.util.List;
import org.springframework.stereotype.Component;

/**
 * Convierte entidades del agregado {@code Attention} a DTOs de salida.
 *
 * <p>Extraido del servicio para respetar el principio de responsabilidad
 * unica (SRP): el mapeo entidad {@literal ->} DTO es una responsabilidad
 * distinta de la orquestacion de la operacion de negocio.
 */
@Component
public class AttentionMapper {

    public AttentionResponse toResponse(AttentionEntity attention, List<AppliedDoseResponse> doseResponses) {
        return new AttentionResponse(
                attention.getId(),
                attention.getPatientId(),
                attention.getProfessionalId(),
                attention.getInstitutionId(),
                attention.getAttentionDate(),
                attention.getConsecutive(),
                attention.getStatus().name(),
                attention.getObservations(),
                attention.isCompleteScheme(),
                attention.isPaiwebRegistered(),
                attention.getPaiwebNotRegisteredReason(),
                attention.getVersion(),
                attention.getCreatedAt(),
                attention.getUpdatedAt(),
                doseResponses);
    }

    public AppliedDoseResponse toDoseResponse(AppliedDoseEntity dose) {
        return new AppliedDoseResponse(
                dose.getId(),
                dose.getAttentionId(),
                dose.getVaccineId(),
                dose.getVaccineNameSnapshot(),
                dose.getVaccineCodeSnapshot(),
                dose.getDoseOptionId(),
                dose.getDoseLabelSnapshot(),
                dose.getDoseValueSnapshot(),
                dose.getPneumococcalTypeOptionId(),
                dose.getPneumococcalTypeSnapshot(),
                dose.getLotId(),
                dose.getLotNumber(),
                dose.getApplicationDate(),
                dose.getCatalogVersion(),
                dose.getSelectedLaboratorySnapshot(),
                dose.getSelectedSyringeSnapshot(),
                dose.getSelectedDropperSnapshot(),
                dose.getSelectedObservationSnapshot(),
                dose.getStatus().name(),
                dose.getCancelledReason(),
                dose.getCancelledAt(),
                dose.getCreatedAt());
    }
}