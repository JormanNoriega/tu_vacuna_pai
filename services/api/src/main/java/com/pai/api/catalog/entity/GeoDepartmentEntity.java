package com.pai.api.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/** Departamento (codigo DANE de 2 digitos). */
@Entity
@Table(name = "geo_departments", schema = "app")
public class GeoDepartmentEntity {

    @Id
    private UUID id;

    @Column(name = "country_id", nullable = false)
    private UUID countryId;

    @Column(nullable = false)
    private String code;

    @Column(nullable = false)
    private String name;

    protected GeoDepartmentEntity() {}

    public GeoDepartmentEntity(UUID id, UUID countryId, String code, String name) {
        this.id = id;
        this.countryId = countryId;
        this.code = code;
        this.name = name;
    }

    public UUID getId() {
        return id;
    }

    public UUID getCountryId() {
        return countryId;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }
}
