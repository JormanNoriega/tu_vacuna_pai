package com.pai.api.identity.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.identity.entity.ProfessionEntity;

public interface ProfessionRepository extends JpaRepository<ProfessionEntity, UUID> {

    boolean existsByCode(String code);
}