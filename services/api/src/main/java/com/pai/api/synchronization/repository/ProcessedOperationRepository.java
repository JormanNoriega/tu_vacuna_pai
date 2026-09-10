package com.pai.api.synchronization.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.synchronization.entity.ProcessedOperationEntity;

public interface ProcessedOperationRepository
        extends JpaRepository<ProcessedOperationEntity, UUID> {
}
