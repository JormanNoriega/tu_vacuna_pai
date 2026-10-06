package com.pai.api.identity.service;

import com.pai.api.identity.dto.CreateVaccinatorRequest;
import com.pai.api.identity.repository.ProfessionRepository;
import com.pai.api.shared.util.DocumentNormalizer;
import com.pai.api.shared.util.Strings;
import org.springframework.stereotype.Component;

/**
 * Construye el {@link AuthUserProfile} de un vacunador a partir del request:
 * normaliza el documento (autoridad final) y valida el tipo de documento y la
 * profesion contra el catalogo. Extraido de {@link UserProvisioningService}
 * (SRP): la orquestacion no conoce las reglas del perfil.
 */
@Component
public class VaccinatorProfileFactory {

  private final ProfessionRepository professionRepository;

  public VaccinatorProfileFactory(ProfessionRepository professionRepository) {
    this.professionRepository = professionRepository;
  }

  public AuthUserProfile create(CreateVaccinatorRequest request) {
    String documentType = DocumentNormalizer.normalizeType(request.documentType());
    String documentNumber = DocumentNormalizer.normalize(request.documentNumber());
    if (!DocumentNormalizer.isValidForType(documentNumber, documentType)) {
      throw new IllegalArgumentException(
          "El numero de documento no es valido para el tipo seleccionado.");
    }

    String professionCode = DocumentNormalizer.normalizeType(request.professionCode());
    if (!professionRepository.existsByCode(professionCode)) {
      throw new IllegalArgumentException("La profesion seleccionada no esta configurada.");
    }

    return new AuthUserProfile(
        documentType,
        documentNumber,
        Strings.trimToNull(request.phone()),
        request.birthDate(),
        DocumentNormalizer.normalizeType(request.gender()),
        professionCode,
        DocumentNormalizer.normalize(request.professionalRegistrationNumber()),
        Strings.trimToNull(request.professionalRegistrationType()));
  }
}
