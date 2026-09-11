package com.pai.api.audit.repository;

import com.pai.api.audit.entity.AuditEventEntity;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;

public interface AuditEventRepository extends JpaRepository<AuditEventEntity, UUID> {}
