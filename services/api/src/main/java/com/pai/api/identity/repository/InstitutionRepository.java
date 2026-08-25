package com.pai.api.identity.repository;

import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.pai.api.identity.entity.InstitutionEntity;

public interface InstitutionRepository extends JpaRepository<InstitutionEntity, UUID> {
}