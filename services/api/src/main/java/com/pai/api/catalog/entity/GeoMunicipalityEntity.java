package com.pai.api.catalog.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.util.UUID;

/** Municipio o area no municipalizada (codigo DANE unico nacional). */
@Entity
@Table(name = "geo_municipalities", schema = "app")
public class GeoMunicipalityEntity {

    @Id
    private UUID id;

    @Column(name = "department_id", nullable = false)
    private UUID departmentId;

    @Column(nullable = false)
    private String code;

    @Column(nullable = false)
    private String name;

    protected GeoMunicipalityEntity() {}

    public GeoMunicipalityEntity(UUID id, UUID departmentId, String code, String name) {
        this.id = id;
        this.departmentId = departmentId;
        this.code = code;
        this.name = name;
    }

    public UUID getId() {
        return id;
    }

    public UUID getDepartmentId() {
        return departmentId;
    }

    public String getCode() {
        return code;
    }

    public String getName() {
        return name;
    }
}
