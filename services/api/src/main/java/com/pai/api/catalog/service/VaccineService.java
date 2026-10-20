package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.OptionRequest;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineRequest;
import com.pai.api.catalog.dto.VaccineResponse;
import java.util.List;
import java.util.UUID;

/**
 * Sujeto (Subject) del patron estructural Proxy para el catalogo global de vacunas.
 *
 * <p>Define el contrato comun tanto para el Sujeto Real ({@link DefaultVaccineService})
 * como para el Proxy de Proteccion ({@link VaccineSecurityProxy}), permitiendo al cliente
 * ({@link com.pai.api.catalog.controller.CatalogController}) interactuar de forma transparente
 * y desacoplada respetando el Principio de Inversion de Dependencias (DIP).
 */
public interface VaccineService {

  List<VaccineResponse> list(UUID actor);

  VaccineResponse create(UUID actor, VaccineRequest r);

  VaccineResponse update(UUID actor, UUID id, VaccineRequest r, long version);

  void delete(UUID actor, UUID id, long version);

  List<OptionResponse> globalOptions(UUID actor, UUID vaccine);

  OptionResponse createOption(UUID actor, UUID vaccine, OptionRequest r);

  OptionResponse createTemplate(UUID actor, UUID vaccine, OptionRequest r);

  OptionResponse updateOption(UUID actor, UUID vaccine, UUID id, OptionRequest r);

  OptionResponse updateTemplate(UUID actor, UUID vaccine, UUID id, OptionRequest r);

  void deleteOption(UUID actor, UUID vaccine, UUID id, long version);

  void deleteTemplate(UUID actor, UUID vaccine, UUID id, long version);

  List<OptionResponse> templates(UUID actor, UUID vaccine);
}
