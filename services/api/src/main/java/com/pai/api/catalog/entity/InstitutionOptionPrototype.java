package com.pai.api.catalog.entity;

import java.util.UUID;

/**
 * Prototype: contrato para clonar una opcion del catalogo global hacia su
 * variante institucional.
 *
 * <p>La implementa el <b>prototipo concreto</b> ({@link VaccineOptionTemplateEntity}),
 * que copia su propio estado en un {@link InstitutionVaccineOptionEntity}. El
 * cliente ({@code InstitutionVaccineService}) clona a traves de esta abstraccion
 * sin volver a especificar campo por campo.
 */
public interface InstitutionOptionPrototype {

  /** Clona este prototipo como opcion operativa de la institucion. */
  InstitutionVaccineOptionEntity copyToInstitution(UUID institutionId, UUID actorId);
}
