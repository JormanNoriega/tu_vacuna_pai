package com.pai.api.patients.repository;

import com.pai.api.patients.entity.PatientEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

/**
 * Acceso a {@link PatientEntity}. Regla de alcance: los pacientes se leen y
 * modifican SIEMPRE con criterio de institucion, de modo que un recurso de otra
 * institucion nunca se materializa (equivalente a RLS en la capa de datos).
 */
public interface PatientRepository extends JpaRepository<PatientEntity, UUID> {

    Optional<PatientEntity> findByIdAndInstitutionId(UUID id, UUID institutionId);

    Optional<PatientEntity> findByInstitutionIdAndDocumentTypeAndDocumentNumber(
            UUID institutionId, String documentType, String documentNumber);

    List<PatientEntity> findByInstitutionIdAndDocumentNumber(UUID institutionId, String documentNumber);

    boolean existsByInstitutionIdAndDocumentTypeAndDocumentNumber(
            UUID institutionId, String documentType, String documentNumber);
}
