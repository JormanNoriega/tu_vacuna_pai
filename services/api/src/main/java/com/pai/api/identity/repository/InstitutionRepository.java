package com.pai.api.identity.repository;

import com.pai.api.identity.entity.InstitutionEntity;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface InstitutionRepository extends JpaRepository<InstitutionEntity, UUID> {

    Optional<InstitutionEntity> findByCode(String code);

    List<InstitutionEntity> findAllByOrderByNameAsc();
}
