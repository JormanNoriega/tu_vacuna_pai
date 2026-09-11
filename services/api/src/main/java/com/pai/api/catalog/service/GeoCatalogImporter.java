package com.pai.api.catalog.service;

import java.io.InputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.io.ClassPathResource;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.pai.api.catalog.entity.GeoCountryEntity;
import com.pai.api.catalog.entity.GeoDepartmentEntity;
import com.pai.api.catalog.entity.GeoMunicipalityEntity;
import com.pai.api.catalog.repository.GeoCountryRepository;
import com.pai.api.catalog.repository.GeoDepartmentRepository;
import com.pai.api.catalog.repository.GeoMunicipalityRepository;

/**
 * Siembra el catalogo geografico desde {@code catalog/divipola.json}
 * (proyeccion versionada de DIVIPOLA - DANE). Es idempotente: si ya hay
 * municipios cargados no vuelve a sembrar. El pais queda fijo (Colombia).
 *
 * <p>Se cargan las entidades en memoria y se persisten en bloque
 * ({@code saveAll}) para evitar una consulta por fila durante el seed.
 */
@Component
public class GeoCatalogImporter implements ApplicationRunner {

    private static final String COUNTRY_CODE = "CO";
    private static final String COUNTRY_NAME = "Colombia";
    private static final Logger log = LoggerFactory.getLogger(GeoCatalogImporter.class);

    private final GeoCountryRepository countries;
    private final GeoDepartmentRepository departments;
    private final GeoMunicipalityRepository municipalities;
    private final ObjectMapper mapper = new ObjectMapper();

    public GeoCatalogImporter(GeoCountryRepository countries,
            GeoDepartmentRepository departments,
            GeoMunicipalityRepository municipalities) {
        this.countries = countries;
        this.departments = departments;
        this.municipalities = municipalities;
    }

    @Override
    @Transactional
    public void run(ApplicationArguments args) throws Exception {
        if (municipalities.count() > 0) {
            log.info("Geo catalog already seeded: {} departamentos, {} municipios",
                departments.count(), municipalities.count());
            return;
        }

        GeoCountryEntity country = countries.findByCode(COUNTRY_CODE).orElseGet(
            () -> countries.save(new GeoCountryEntity(
                UUID.randomUUID(), COUNTRY_CODE, COUNTRY_NAME)));

        Map<String, GeoDepartmentEntity> existingDepartments = new HashMap<>();
        for (GeoDepartmentEntity department : departments.findAll()) {
            existingDepartments.put(department.getCode(), department);
        }

        List<GeoDepartmentEntity> newDepartments = new ArrayList<>();
        List<GeoMunicipalityEntity> newMunicipalities = new ArrayList<>();

        try (InputStream input = new ClassPathResource(
                "catalog/divipola.json").getInputStream()) {
            for (JsonNode departmentNode : mapper.readTree(input)) {
                String departmentCode = departmentNode.path("code").asText();
                GeoDepartmentEntity department = existingDepartments.get(departmentCode);
                if (department == null) {
                    department = new GeoDepartmentEntity(UUID.randomUUID(), country.getId(),
                        departmentCode, departmentNode.path("name").asText());
                    newDepartments.add(department);
                    existingDepartments.put(departmentCode, department);
                }
                for (JsonNode municipalityNode : departmentNode.path("municipalities")) {
                    newMunicipalities.add(new GeoMunicipalityEntity(
                        UUID.randomUUID(), department.getId(),
                        municipalityNode.path("code").asText(),
                        municipalityNode.path("name").asText()));
                }
            }
        }

        departments.saveAll(newDepartments);
        departments.flush();
        municipalities.saveAll(newMunicipalities);
        log.info("Geo catalog seeded: {} departamentos, {} municipios",
            newDepartments.size(), newMunicipalities.size());
    }
}
