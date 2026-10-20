package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.OptionRequest;
import com.pai.api.catalog.dto.OptionResponse;
import com.pai.api.catalog.dto.VaccineRequest;
import com.pai.api.catalog.dto.VaccineResponse;
import com.pai.api.shared.security.PermissionGuard;
import java.util.List;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Service;

/**
 * Proxy de Proteccion (Protection Proxy) para el catalogo global de vacunas.
 *
 * <p>Implementa la misma interfaz {@link VaccineService} que el sujeto real
 * {@link DefaultVaccineService}. Intercepta cada llamada para validar que el
 * actor autenticado cuente con los permisos pertinentes ({@code CATALOG_GLOBAL_READ}
 * o {@code CATALOG_GLOBAL_WRITE}) a traves de {@link PermissionGuard}.
 *
 * <p>Si el actor no cuenta con los permisos, {@link PermissionGuard} lanza
 * {@link com.pai.api.shared.exceptions.PermissionDeniedException}, cortocircuitando
 * la ejecucion e impidiendo que se invoque el sujeto real o se acceda a la persistencia.
 */
@Service
@Primary
public class VaccineSecurityProxy implements VaccineService {

  private final VaccineService realService;
  private final PermissionGuard guard;

  public VaccineSecurityProxy(
      @Qualifier("defaultVaccineService") VaccineService realService,
      PermissionGuard guard) {
    this.realService = realService;
    this.guard = guard;
  }

  @Override
  public List<VaccineResponse> list(UUID actor) {
    guard.require(actor, "CATALOG_GLOBAL_READ");
    return realService.list(actor);
  }

  @Override
  public VaccineResponse create(UUID actor, VaccineRequest r) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.create(actor, r);
  }

  @Override
  public VaccineResponse update(UUID actor, UUID id, VaccineRequest r, long version) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.update(actor, id, r, version);
  }

  @Override
  public void delete(UUID actor, UUID id, long version) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    realService.delete(actor, id, version);
  }

  @Override
  public List<OptionResponse> globalOptions(UUID actor, UUID vaccine) {
    guard.require(actor, "CATALOG_GLOBAL_READ");
    return realService.globalOptions(actor, vaccine);
  }

  @Override
  public OptionResponse createOption(UUID actor, UUID vaccine, OptionRequest r) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.createOption(actor, vaccine, r);
  }

  @Override
  public OptionResponse createTemplate(UUID actor, UUID vaccine, OptionRequest r) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.createTemplate(actor, vaccine, r);
  }

  @Override
  public OptionResponse updateOption(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.updateOption(actor, vaccine, id, r);
  }

  @Override
  public OptionResponse updateTemplate(UUID actor, UUID vaccine, UUID id, OptionRequest r) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    return realService.updateTemplate(actor, vaccine, id, r);
  }

  @Override
  public void deleteOption(UUID actor, UUID vaccine, UUID id, long version) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    realService.deleteOption(actor, vaccine, id, version);
  }

  @Override
  public void deleteTemplate(UUID actor, UUID vaccine, UUID id, long version) {
    guard.require(actor, "CATALOG_GLOBAL_WRITE");
    realService.deleteTemplate(actor, vaccine, id, version);
  }

  @Override
  public List<OptionResponse> templates(UUID actor, UUID vaccine) {
    guard.require(actor, "CATALOG_GLOBAL_READ");
    return realService.templates(actor, vaccine);
  }
}
