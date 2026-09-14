package com.pai.api.catalog.repository;

import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import java.util.*;
import org.springframework.data.jpa.repository.*;
import org.springframework.data.repository.query.Param;

public interface InstitutionVaccineRepository extends JpaRepository<InstitutionVaccineEntity, UUID> {
    Optional<InstitutionVaccineEntity> findByInstitutionIdAndVaccineId(UUID i, UUID v);

    List<InstitutionVaccineEntity> findByInstitutionId(UUID i);

    @Modifying
    @Query("update InstitutionVaccineEntity x set x.enabled=:enabled where x.id=:id")
    int setEnabledById(@Param("id") UUID id, @Param("enabled") boolean enabled);

    /**
     * Upsert nativo copy-once: habilita la vacuna en la institucion solo si la
     * relacion no existe. Devuelve 1 si inserto, 0 si la relacion ya existia.
     * Reemplaza el SQL nativo con {@code EntityManager} que usaba
     * {@code InstitutionVaccineService} (DIP: el repositorio contiene la query).
     */
    @Modifying
    @Query(
            value = "INSERT INTO app.institution_vaccines "
                    + "(institution_id, vaccine_id, is_enabled, enabled_at, enabled_by) "
                    + "VALUES (:institution, :vaccine, true, now(), :actor) "
                    + "ON CONFLICT (institution_id, vaccine_id) DO NOTHING",
            nativeQuery = true)
    int insertEnabledIfAbsent(
            @Param("institution") UUID institutionId,
            @Param("vaccine") UUID vaccineId,
            @Param("actor") UUID actorId);
}
