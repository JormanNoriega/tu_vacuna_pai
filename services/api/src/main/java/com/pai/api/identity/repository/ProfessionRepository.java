package com.pai.api.identity.repository;

import com.pai.api.identity.entity.ProfessionEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProfessionRepository extends JpaRepository<ProfessionEntity, UUID> {

    boolean existsByCode(String code);
}
