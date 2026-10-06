package com.pai.api.identity.service;

import java.util.UUID;

/**
 * Puerto (DIP) para sembrar el catalogo global en una institucion recien
 * creada. La implementacion vive en el modulo {@code catalog}, de modo que
 * {@code identity} no depende de sus servicios concretos.
 *
 * <p>Es sincrono: se ejecuta dentro de la misma transaccion que la creacion de
 * la institucion, preservando la semantica actual.
 */
public interface InstitutionCatalogSeeder {

  /** Habilita el catalogo global activo en la institucion indicada. */
  void seed(UUID institutionId, UUID actorId);
}
