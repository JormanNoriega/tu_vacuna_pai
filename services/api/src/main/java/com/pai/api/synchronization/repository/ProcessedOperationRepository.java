package com.pai.api.synchronization.repository;

import com.pai.api.synchronization.entity.ProcessedOperationEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ProcessedOperationRepository extends JpaRepository<ProcessedOperationEntity, UUID> {}
