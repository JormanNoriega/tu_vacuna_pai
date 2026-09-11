package com.pai.api.identity.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/**
 * Catalogo de profesiones/cargos del personal de salud (catálogo, no texto
 * libre). Su codigo se referencia en {@code app.users.profession_code}.
 */
@Entity
@Table(name = "professions", schema = "app")
public class ProfessionEntity {

    @Id
    private UUID id;

    @Column(nullable = false)
    private String code;

    @Column(nullable = false)
    private String name;

    protected ProfessionEntity() {}

    public ProfessionEntity(UUID id, String code, String name) {
        this.id = id;
        this.code = code;
        this.name = name;
    }

    public UUID getId() {
        return id;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }
}
