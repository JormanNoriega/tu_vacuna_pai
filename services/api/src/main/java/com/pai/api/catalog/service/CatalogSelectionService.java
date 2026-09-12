package com.pai.api.catalog.service;

import com.pai.api.attentions.exception.InvalidClinicalStateException;
import com.pai.api.attentions.service.VaccineCatalogPolicy;
import com.pai.api.catalog.entity.InstitutionVaccineEntity;
import com.pai.api.catalog.entity.InstitutionVaccineOptionEntity;
import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.entity.VaccineOptionEntity;
import com.pai.api.catalog.repository.InstitutionVaccineOptionRepository;
import com.pai.api.catalog.repository.InstitutionVaccineRepository;
import com.pai.api.catalog.repository.VaccineOptionRepository;
import com.pai.api.catalog.repository.VaccineRepository;
import java.util.UUID;
import org.springframework.stereotype.Service;

/**
 * Implementacion del puerto {@link VaccineCatalogPolicy} en el modulo
 * {@code catalog}. Encapsula las reglas de seleccion del catalogo (vacuna
 * habilitada, opcion global valida, opcion operativa institucional) y libera al
 * modulo clinico de depender de repositorios ajenos (DIP).
 *
 * <p>Ademas respeta el OCP: es la unica clase que decide "que campo es valido
 * para que vacuna", y lo hace via los metadatos {@code fieldType} de las
 * opciones del catalogo.
 */
@Service
public class CatalogSelectionService implements VaccineCatalogPolicy {

    private static final String FIELD_LABORATORY = "laboratory";
    private static final String FIELD_SYRINGE = "syringe";
    private static final String FIELD_DROPPER = "dropper";
    private static final String FIELD_OBSERVATION = "observation";

    private final VaccineRepository vaccines;
    private final VaccineOptionRepository vaccineOptions;
    private final InstitutionVaccineRepository institutionVaccines;
    private final InstitutionVaccineOptionRepository institutionOptions;

    public CatalogSelectionService(
            VaccineRepository vaccines,
            VaccineOptionRepository vaccineOptions,
            InstitutionVaccineRepository institutionVaccines,
            InstitutionVaccineOptionRepository institutionOptions) {
        this.vaccines = vaccines;
        this.vaccineOptions = vaccineOptions;
        this.institutionVaccines = institutionVaccines;
        this.institutionOptions = institutionOptions;
    }

    @Override
    public DoseSelection resolve(ResolutionRequest request) {
        VaccineEntity vaccine = requireEnabledVaccine(request.institutionId(), request.vaccineId());

        VaccineOptionEntity doseOption = requireGlobalOption(
                request.doseOptionId(),
                vaccine.getId(),
                "dose",
                "La dosis seleccionada no es valida.");
        VaccineOptionEntity pneumo = request.pneumococcalTypeOptionId() == null
                ? null
                : requireGlobalOption(
                        request.pneumococcalTypeOptionId(),
                        vaccine.getId(),
                        "pneumococcalType",
                        "El tipo de neumococo seleccionado no es valido.");

        InstitutionVaccineOptionEntity laboratory = requireInstitutionalOption(
                request.institutionId(),
                vaccine.getId(),
                request.laboratoryId(),
                FIELD_LABORATORY);
        InstitutionVaccineOptionEntity syringe =
                requireInstitutionalOption(request.institutionId(), vaccine.getId(), request.syringeId(), FIELD_SYRINGE);
        InstitutionVaccineOptionEntity dropper =
                requireInstitutionalOption(request.institutionId(), vaccine.getId(), request.dropperId(), FIELD_DROPPER);
        InstitutionVaccineOptionEntity observation = requireInstitutionalOption(
                request.institutionId(), vaccine.getId(), request.observationId(), FIELD_OBSERVATION);

        return new DoseSelection(
                vaccine.getId(),
                vaccine.getName(),
                vaccine.getCode(),
                vaccine.getVersion(),
                doseOption.getId(),
                doseOption.getDisplayName(),
                doseOption.getValue(),
                pneumo != null ? pneumo.getId() : null,
                pneumo != null ? pneumo.getDisplayName() : null,
                id(laboratory),
                label(laboratory),
                id(syringe),
                label(syringe),
                id(dropper),
                label(dropper),
                id(observation),
                label(observation));
    }

    private VaccineEntity requireEnabledVaccine(UUID institutionId, UUID vaccineId) {
        VaccineEntity vaccine =
                vaccines.findById(vaccineId).orElseThrow(() -> new IllegalArgumentException("La vacuna no existe."));
        if (!vaccine.isActive()) {
            throw new InvalidClinicalStateException("La vacuna esta inactiva.");
        }
        boolean enabled = institutionVaccines
                .findByInstitutionIdAndVaccineId(institutionId, vaccineId)
                .filter(InstitutionVaccineEntity::isEnabled)
                .isPresent();
        if (!enabled) {
            throw new InvalidClinicalStateException("La vacuna no esta habilitada en tu institucion.");
        }
        return vaccine;
    }

    private VaccineOptionEntity requireGlobalOption(UUID optionId, UUID vaccineId, String fieldType, String message) {
        VaccineOptionEntity option = vaccineOptions
                .findByIdAndVaccineId(optionId, vaccineId)
                .orElseThrow(() -> new IllegalArgumentException(message));
        if (!option.isActive() || !fieldType.equals(option.getFieldType())) {
            throw new IllegalArgumentException(message);
        }
        return option;
    }

    private InstitutionVaccineOptionEntity requireInstitutionalOption(
            UUID institutionId, UUID vaccineId, UUID optionId, String fieldType) {
        if (optionId == null) {
            return null;
        }
        InstitutionVaccineOptionEntity option = institutionOptions
                .findByIdAndInstitutionIdAndVaccineId(optionId, institutionId, vaccineId)
                .orElseThrow(() -> new IllegalArgumentException("La opcion operativa seleccionada no es valida."));
        if (!option.isActive() || !fieldType.equals(option.getFieldType())) {
            throw new IllegalArgumentException("La opcion operativa seleccionada no es valida.");
        }
        return option;
    }

    private UUID id(InstitutionVaccineOptionEntity option) {
        return option == null ? null : option.getId();
    }

    private String label(InstitutionVaccineOptionEntity option) {
        return option == null ? null : option.getDisplayName();
    }
}