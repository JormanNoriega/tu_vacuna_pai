package com.pai.api.reports.service;

import com.pai.api.catalog.entity.VaccineEntity;
import com.pai.api.catalog.repository.VaccineRepository;
import com.pai.api.identity.entity.InstitutionEntity;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.InstitutionRepository;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.domain.RegistroDiarioDoseData;
import com.pai.api.reports.dto.RegistroDiarioSummaryResponse;
import com.pai.api.reports.export.ExportedReport;
import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportCategoryBlock;
import com.pai.api.reports.export.ReportCategoryColors;
import com.pai.api.reports.export.ReportFactoryProvider;
import com.pai.api.reports.export.ReportFieldHeader;
import com.pai.api.reports.export.ReportFormat;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Objects;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;

/**
 * Cliente del patron Abstract Factory para el reporte "Registro Diario" PAI.
 * Genera el reporte oficial de vacunacion con doble nivel de encabezados,
 * 76 columnas fijas, pivoteo dinamico de vacunas activas, datos de enfermera y
 * formato visual cebra segun los estandares gubernamentales.
 */
@Service
public class RegistroDiarioExportService {

  private static final DateTimeFormatter DATE_FORMAT = DateTimeFormatter.ofPattern("dd/MM/yyyy");
  private static final DateTimeFormatter FILE_DATE_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd");

  private static final Set<String> NO_DOSE_VACCINES =
      Set.of(
          "antirrabico_suero",
          "hepatitis_b_inmunoglobulina",
          "inmunoglobulina_antitetanica",
          "antitoxina_tetanica");

  private static final List<String> FIXED_HEADERS =
      List.of(
          // --- DATOS BÁSICOS (20) ---
          "CONSECUTIVO",
          "FECHA DE ATENCIÓN",
          "TIPO DE IDENTIFICACIÓN",
          "NÚMERO DE IDENTIFICACIÓN",
          "PRIMER NOMBRE",
          "SEGUNDO NOMBRE",
          "PRIMER APELLIDO",
          "SEGUNDO APELLIDO",
          "FECHA DE NACIMIENTO",
          "AÑOS",
          "MESES",
          "DÍAS",
          "TOTAL MESES",
          "ESQUEMA COMPLETO",
          "SEXO",
          "GÉNERO",
          "ORIENTACIÓN SEXUAL",
          "EDAD GESTACIONAL (SEMANAS)",
          "LATITUD",
          "LONGITUD",
          // --- DATOS COMPLEMENTARIOS (24) ---
          "PAÍS DE NACIMIENTO",
          "ESTATUS MIGRATORIO",
          "LUGAR DE ATENCIÓN DEL PARTO",
          "RÉGIMEN DE AFILIACIÓN",
          "ASEGURADORA",
          "PERTENENCIA ÉTNICA",
          "DESPLAZADO",
          "DISCAPACITADO",
          "FALLECIDO",
          "VÍCTIMA DEL CONFLICTO ARMADO",
          "ESTUDIA ACTUALMENTE",
          "PAÍS DE RESIDENCIA",
          "DEPARTAMENTO DE RESIDENCIA",
          "MUNICIPIO DE RESIDENCIA",
          "COMUNA/LOCALIDAD",
          "ÁREA",
          "DIRECCIÓN CON NOMENCLATURA",
          "TELÉFONO FIJO",
          "CELULAR",
          "EMAIL",
          "¿AUTORIZA LLAMADAS TELEFÓNICAS?",
          "¿AUTORIZA ENVÍO DE CORREO?",
          "NIVEL EDUCATIVO",
          "CÓDIGO ASEGURADORA",
          // --- ANTECEDENTES MÉDICOS (4) ---
          "¿SUFRE O HA SUFRIDO ALGÚN EVENTO O ENFERMEDAD QUE CONTRAINDIQUE LA VACUNACIÓN?",
          "CUÁL CONTRAINDICACIÓN",
          "¿HA PRESENTADO REACCIÓN MODERADA O SEVERA A BIOLÓGICOS ANTERIORES?",
          "CUÁL REACCIÓN",
          // --- CONDICIÓN USUARIA (7) ---
          "CONDICIÓN DE LA USUARIA",
          "FECHA DE ÚLTIMA MENSTRUACIÓN",
          "SEMANAS DE GESTACIÓN",
          "FECHA PROBABLE DE PARTO",
          "CANTIDAD DE EMBARAZOS PREVIOS",
          "¿HA TENIDO PARTOS PREVIOS?",
          "LUGAR PARTO USUARIA",
          // --- HISTÓRICO DE ANTECEDENTES (4) ---
          "FECHA DE REGISTRO DEL ANTECEDENTE",
          "TIPO",
          "DESCRIPCIÓN",
          "OBSERVACIONES ESPECIALES",
          // --- DATOS DE LA MADRE (13) ---
          "TIPO DE IDENTIFICACIÓN MADRE",
          "NÚMERO DE IDENTIFICACIÓN MADRE",
          "PRIMER NOMBRE MADRE",
          "SEGUNDO NOMBRE MADRE",
          "PRIMER APELLIDO MADRE",
          "SEGUNDO APELLIDO MADRE",
          "CORREO ELECTRÓNICO MADRE",
          "TELÉFONO FIJO MADRE",
          "CELULAR MADRE",
          "RÉGIMEN DE AFILIACIÓN MADRE",
          "PERTENENCIA ÉTNICA MADRE",
          "DESPLAZADO MADRE",
          "ASEGURADORA MADRE",
          // --- DATOS DEL CUIDADOR (14) ---
          "TIPO DE IDENTIFICACIÓN CUIDADOR",
          "NÚMERO DE IDENTIFICACIÓN CUIDADOR",
          "PRIMER NOMBRE CUIDADOR",
          "SEGUNDO NOMBRE CUIDADOR",
          "PRIMER APELLIDO CUIDADOR",
          "SEGUNDO APELLIDO CUIDADOR",
          "PARENTESCO",
          "CORREO ELECTRÓNICO CUIDADOR",
          "TELÉFONO FIJO CUIDADOR",
          "CELULAR CUIDADOR",
          "RÉGIMEN DE AFILIACIÓN CUIDADOR",
          "ASEGURADORA CUIDADOR",
          "PERTENENCIA ÉTNICA CUIDADOR",
          "DESPLAZADO CUIDADOR",
          // --- ESQUEMA DE VACUNACIÓN (4) ---
          "TIPO DE CARNET DE VACUNACIÓN",
          "REGISTRADO EN PAIWEB",
          "MOTIVO NO INGRESO PAIWEB",
          "OBSERVACIONES DE LA ATENCIÓN");

  private final RegistroDiarioQuery registroDiarioQuery;
  private final PatientIdentityQuery patientIdentityQuery;
  private final ReportFactoryProvider factoryProvider;
  private final DataScope dataScope;
  private final VaccineRepository vaccineRepository;
  private final UserRepository userRepository;
  private final InstitutionRepository institutionRepository;

  public RegistroDiarioExportService(
      RegistroDiarioQuery registroDiarioQuery,
      PatientIdentityQuery patientIdentityQuery,
      ReportFactoryProvider factoryProvider,
      DataScope dataScope,
      VaccineRepository vaccineRepository,
      UserRepository userRepository,
      InstitutionRepository institutionRepository) {
    this.registroDiarioQuery = registroDiarioQuery;
    this.patientIdentityQuery = patientIdentityQuery;
    this.factoryProvider = factoryProvider;
    this.dataScope = dataScope;
    this.vaccineRepository = vaccineRepository;
    this.userRepository = userRepository;
    this.institutionRepository = institutionRepository;
  }

  public RegistroDiarioSummaryResponse summary(
      AuthorizedUser actor, Instant from, Instant to) {
    UUID institutionId = dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    List<RegistroDiarioDoseData> doseRows = registroDiarioQuery.doses(institutionId, from, to);
    long patientsCount =
        doseRows.stream().map(RegistroDiarioDoseData::patientId).distinct().count();
    long dosesCount = doseRows.size();
    long vaccineTypesCount =
        doseRows.stream()
            .map(RegistroDiarioDoseData::vaccineCode)
            .filter(code -> code != null && !code.isBlank())
            .distinct()
            .count();
    return new RegistroDiarioSummaryResponse(patientsCount, dosesCount, vaccineTypesCount);
  }

  public ExportedReport export(
      AuthorizedUser actor, Instant from, Instant to, ReportFormat format) {
    UUID institutionId = dataScope.resolveInstitutionId(actor, actor.getInstitution().getId());
    List<RegistroDiarioDoseData> doseRows = registroDiarioQuery.doses(institutionId, from, to);

    List<VaccineEntity> activeVaccines =
        vaccineRepository.findByActiveTrueOrderByNameAsc();

    PaiReportFactory factory = factoryProvider.create(format);

    // 1. Construir definicion de encabezados (Fila 0 Categorias y Fila 1 Subencabezados)
    List<ReportCategoryBlock> categoryBlocks = new ArrayList<>();
    categoryBlocks.add(new ReportCategoryBlock("DATOS BÁSICOS", 20, ReportCategoryColors.BASIC_DATA));
    categoryBlocks.add(
        new ReportCategoryBlock(
            "DATOS COMPLEMENTARIOS", 24, ReportCategoryColors.COMPLEMENTARY_DATA));
    categoryBlocks.add(
        new ReportCategoryBlock("ANTECEDENTES MÉDICOS", 4, ReportCategoryColors.MEDICAL_HISTORY));
    categoryBlocks.add(
        new ReportCategoryBlock("CONDICIÓN USUARIA", 7, ReportCategoryColors.USER_CONDITION));
    categoryBlocks.add(
        new ReportCategoryBlock(
            "HISTÓRICO DE ANTECEDENTES", 4, ReportCategoryColors.ANTECEDENT_HISTORY));
    categoryBlocks.add(
        new ReportCategoryBlock("DATOS DE LA MADRE", 13, ReportCategoryColors.MOTHER_DATA));
    categoryBlocks.add(
        new ReportCategoryBlock("DATOS DEL CUIDADOR", 14, ReportCategoryColors.CAREGIVER_DATA));
    categoryBlocks.add(
        new ReportCategoryBlock(
            "ESQUEMA DE VACUNACIÓN", 4, ReportCategoryColors.VACCINATION_SCHEME));

    List<ReportFieldHeader> fieldHeaders = new ArrayList<>();
    for (String title : FIXED_HEADERS) {
      fieldHeaders.add(new ReportFieldHeader(title, ReportCategoryColors.HEADER_ROW));
    }

    // Categorias dinamicas de vacunas activas
    for (int i = 0; i < activeVaccines.size(); i++) {
      VaccineEntity vaccine = activeVaccines.get(i);
      List<String> enabledFields = getEnabledFields(vaccine);
      if (enabledFields.isEmpty()) continue;

      String catColor = (i % 2 == 0)
          ? ReportCategoryColors.VACCINE_DARK
          : ReportCategoryColors.VACCINE_LIGHT;
      categoryBlocks.add(
          new ReportCategoryBlock(vaccine.getName().toUpperCase(Locale.ROOT), enabledFields.size(), catColor));

      String fieldColor = (i % 2 == 0)
          ? ReportCategoryColors.VACCINE_FIELD_DARK
          : ReportCategoryColors.VACCINE_FIELD_LIGHT;
      for (String fieldKey : enabledFields) {
        fieldHeaders.add(new ReportFieldHeader(getFieldLabel(fieldKey), fieldColor));
      }
    }

    // Categoria final: DATOS ENFERMERA (7 columnas)
    categoryBlocks.add(new ReportCategoryBlock("DATOS ENFERMERA", 7, ReportCategoryColors.NURSE_DATA));
    fieldHeaders.add(new ReportFieldHeader("NOMBRE ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(new ReportFieldHeader("DOCUMENTO ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(
        new ReportFieldHeader("CORREO ELECTRÓNICO ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(new ReportFieldHeader("TELÉFONO ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(
        new ReportFieldHeader("INSTITUCIÓN ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(new ReportFieldHeader("PROFESIÓN ENFERMERA", ReportCategoryColors.NURSE_FIELD));
    fieldHeaders.add(
        new ReportFieldHeader("REGISTRO PROFESIONAL ENFERMERA", ReportCategoryColors.NURSE_FIELD));

    // Escribir los encabezados en la fabrica concreta
    factory.headerBuilder().writeCategoryHeader(categoryBlocks, fieldHeaders);

    // 2. Si no hay dosis, exportar solo el esquema de encabezados
    if (doseRows.isEmpty()) {
      byte[] content = factory.exporter().export();
      return new ExportedReport(
          content, filename(institutionId, from, format), format.contentType());
    }

    // 3. Consultar datos de pacientes y usuarios profesionales en lote
    Set<UUID> patientIds =
        doseRows.stream().map(RegistroDiarioDoseData::patientId).collect(Collectors.toSet());
    Map<UUID, PatientIdentity> patientMap =
        patientIdentityQuery.byIds(patientIds).stream()
            .collect(Collectors.toMap(PatientIdentity::id, p -> p));

    Set<UUID> vaccinatorIds =
        doseRows.stream()
            .map(RegistroDiarioDoseData::vaccinatorId)
            .filter(Objects::nonNull)
            .collect(Collectors.toSet());
    Map<UUID, UserEntity> userMap =
        vaccinatorIds.isEmpty()
            ? Collections.emptyMap()
            : userRepository.findAllById(vaccinatorIds).stream()
                .collect(Collectors.toMap(UserEntity::getId, u -> u));

    Set<UUID> instIds =
        userMap.values().stream().map(UserEntity::getInstitutionId).collect(Collectors.toSet());
    Map<UUID, InstitutionEntity> instMap =
        instIds.isEmpty()
            ? Collections.emptyMap()
            : institutionRepository.findAllById(instIds).stream()
                .collect(Collectors.toMap(InstitutionEntity::getId, in -> in));

    // 4. Agrupar dosis por (paciente + fecha de atencion normalizada al dia)
    Map<String, List<RegistroDiarioDoseData>> groupedByPatientDate = new LinkedHashMap<>();
    for (RegistroDiarioDoseData dose : doseRows) {
      String dateStr =
          dose.attentionDate() != null
              ? dose.attentionDate().atZone(ZoneOffset.UTC).toLocalDate().toString()
              : "sin-fecha";
      String key = dose.patientId() + "|" + dateStr;
      groupedByPatientDate.computeIfAbsent(key, k -> new ArrayList<>()).add(dose);
    }

    // 5. Pivoteo horizontal de vacunas y generacion de renglones
    for (List<RegistroDiarioDoseData> dosesGroup : groupedByPatientDate.values()) {
      RegistroDiarioDoseData firstDose = dosesGroup.get(0);
      PatientIdentity patient = patientMap.get(firstDose.patientId());
      if (patient == null) continue;

      // Agrupar dosis por ID de vacuna (o codigo si no hay id)
      Map<String, List<RegistroDiarioDoseData>> dosesByVaccineKey = new LinkedHashMap<>();
      for (RegistroDiarioDoseData d : dosesGroup) {
        String vKey =
            d.vaccineId() != null
                ? d.vaccineId().toString()
                : (d.vaccineCode() != null ? d.vaccineCode().toLowerCase(Locale.ROOT) : "");
        dosesByVaccineKey.computeIfAbsent(vKey, k -> new ArrayList<>()).add(d);
      }

      int maxDosesCount = 1;
      for (List<RegistroDiarioDoseData> dList : dosesByVaccineKey.values()) {
        if (dList.size() > maxDosesCount) {
          maxDosesCount = dList.size();
        }
      }

      for (int doseIndex = 0; doseIndex < maxDosesCount; doseIndex++) {
        List<String> row = new ArrayList<>();
        // 76 campos de paciente
        addPatientColumns(row, patient, firstDose);

        // Campos dinamicos de vacunas
        RegistroDiarioDoseData doseForNurse = null;
        for (VaccineEntity vaccine : activeVaccines) {
          List<String> enabledFields = getEnabledFields(vaccine);
          if (enabledFields.isEmpty()) continue;

          String vIdKey = vaccine.getId() != null ? vaccine.getId().toString() : "";
          String vCodeKey = vaccine.getCode() != null ? vaccine.getCode().toLowerCase(Locale.ROOT) : "";
          List<RegistroDiarioDoseData> vDoses = dosesByVaccineKey.get(vIdKey);
          if (vDoses == null || vDoses.isEmpty()) {
            vDoses = dosesByVaccineKey.get(vCodeKey);
          }

          RegistroDiarioDoseData currentDose =
              (vDoses != null && doseIndex < vDoses.size()) ? vDoses.get(doseIndex) : null;
          if (currentDose != null && doseForNurse == null) {
            doseForNurse = currentDose;
          }

          for (String fieldKey : enabledFields) {
            row.add(getDoseFieldValue(currentDose, fieldKey));
          }
        }

        // 5 campos de enfermera
        if (doseForNurse == null) {
          doseForNurse = firstDose;
        }
        addNurseColumns(row, doseForNurse, userMap, instMap);

        factory.rowWriter().writeRow(row);
      }
    }

    byte[] content = factory.exporter().export();
    return new ExportedReport(
        content, filename(institutionId, from, format), format.contentType());
  }

  private void addPatientColumns(
      List<String> row, PatientIdentity patient, RegistroDiarioDoseData dose) {
    LocalDate attentionDay =
        dose.attentionDate() != null
            ? dose.attentionDate().atZone(ZoneOffset.UTC).toLocalDate()
            : LocalDate.now(ZoneOffset.UTC);

    AgeCalculator.Age age =
        patient.birthDate() != null
            ? AgeCalculator.calculate(patient.birthDate(), attentionDay)
            : new AgeCalculator.Age(0, 0, 0, 0);

    // --- DATOS BÁSICOS (20) ---
    row.add(dose.consecutive() != null ? String.valueOf(dose.consecutive()) : "");
    row.add(formatDate(attentionDay));
    row.add(IdTypeFormatter.toAbbreviation(patient.documentType()));
    row.add(text(patient.documentNumber()));
    row.add(upper(patient.firstName()));
    row.add(upper(patient.secondName()));
    row.add(upper(patient.lastName()));
    row.add(upper(patient.secondLastName()));
    row.add(formatDate(patient.birthDate()));
    row.add(String.valueOf(age.years()));
    row.add(String.valueOf(age.months()));
    row.add(String.valueOf(age.days()));
    row.add(String.valueOf(age.totalMonths()));
    row.add(boolVal(dose.completeScheme()));
    row.add(mapSex(patient.sex()));
    row.add(upper(patient.gender()));
    row.add(upper(patient.sexualOrientation()));
    row.add(text(patient.gestationalAgeAtBirth()));
    row.add(dose.latitude() != null ? String.valueOf(dose.latitude()) : "");
    row.add(dose.longitude() != null ? String.valueOf(dose.longitude()) : "");

    // --- DATOS COMPLEMENTARIOS (24) ---
    row.add(upper(defaultIfBlank(patient.birthCountry(), "COLOMBIA")));
    row.add(upper(patient.migrationStatus()));
    row.add(upper(patient.birthPlace()));
    row.add(upper(patient.affiliationRegime()));
    row.add(upper(patient.insurer()));
    row.add(upper(patient.ethnicity()));
    row.add(boolVal(patient.displaced()));
    row.add(boolVal(patient.disabled()));
    row.add(boolVal(patient.deceased()));
    row.add(boolVal(patient.armedConflictVictim()));
    row.add(boolVal(patient.currentlyStudying()));
    row.add(defaultIfBlank(patient.residenceCountry(), "COLOMBIA"));
    row.add(text(patient.residenceDepartment()));
    row.add(text(patient.residenceMunicipality()));
    row.add(text(patient.commune()));
    row.add(text(patient.area()));
    row.add(text(patient.address()));
    row.add(text(patient.landline()));
    row.add(text(patient.cellphone()));
    row.add(text(patient.email()));
    row.add(boolVal(patient.authorizeCalls()));
    row.add(boolVal(patient.authorizeEmail()));
    row.add(upper(patient.educationLevel()));
    row.add(text(patient.insurerCode()));

    // --- ANTECEDENTES MÉDICOS (4) ---
    row.add(boolVal(patient.hasContraindication()));
    row.add(upper(patient.contraindicationDetails()));
    row.add(boolVal(patient.hasPreviousReaction()));
    row.add(upper(patient.reactionDetails()));

    // --- CONDICIÓN USUARIA (7) ---
    row.add(upper(patient.userCondition()));
    row.add(formatDate(patient.lastMenstrualDate()));
    row.add(text(patient.gestationWeeks()));
    row.add(formatDate(patient.probableDeliveryDate()));
    row.add(text(patient.previousPregnancies()));
    row.add(boolVal(patient.hasGivenBirth()));
    row.add(upper(patient.birthPlaceDelivery()));

    // --- HISTÓRICO DE ANTECEDENTES (4) ---
    row.add(formatDate(patient.historyRecordDate()));
    row.add(upper(patient.historyType()));
    row.add(upper(patient.historyDescription()));
    row.add(upper(patient.specialObservations()));

    // --- DATOS DE LA MADRE (13) ---
    row.add(IdTypeFormatter.toAbbreviation(patient.motherIdType()));
    row.add(text(patient.motherIdNumber()));
    row.add(upper(patient.motherFirstName()));
    row.add(upper(patient.motherSecondName()));
    row.add(upper(patient.motherLastName()));
    row.add(upper(patient.motherSecondLastName()));
    row.add(text(patient.motherEmail()));
    row.add(text(patient.motherLandline()));
    row.add(text(patient.motherCellphone()));
    row.add(upper(patient.motherAffiliationRegime()));
    row.add(upper(patient.motherEthnicity()));
    row.add(boolVal(patient.motherDisplaced()));
    row.add(upper(patient.motherInsurer()));

    // --- DATOS DEL CUIDADOR (14) ---
    row.add(IdTypeFormatter.toAbbreviation(patient.caregiverIdType()));
    row.add(text(patient.caregiverIdNumber()));
    row.add(upper(patient.caregiverFirstName()));
    row.add(upper(patient.caregiverSecondName()));
    row.add(upper(patient.caregiverLastName()));
    row.add(upper(patient.caregiverSecondLastName()));
    row.add(upper(patient.caregiverRelationship()));
    row.add(text(patient.caregiverEmail()));
    row.add(text(patient.caregiverLandline()));
    row.add(text(patient.caregiverCellphone()));
    row.add(upper(patient.caregiverAffiliationRegime()));
    row.add(upper(patient.caregiverInsurer()));
    row.add(upper(patient.caregiverEthnicity()));
    row.add(boolVal(patient.caregiverDisplaced()));

    // --- ESQUEMA DE VACUNACIÓN (4) ---
    row.add(CarnetTypeFormatter.format(patient.vaccinationCardType()));
    row.add(boolVal(dose.paiwebRegistered()));
    row.add(upper(dose.paiwebNotRegisteredReason()));
    row.add(upper(dose.attentionObservations()));
  }

  private void addNurseColumns(
      List<String> row,
      RegistroDiarioDoseData dose,
      Map<UUID, UserEntity> userMap,
      Map<UUID, InstitutionEntity> instMap) {
    UserEntity nurse = dose.vaccinatorId() != null ? userMap.get(dose.vaccinatorId()) : null;
    if (nurse != null) {
      InstitutionEntity inst =
          nurse.getInstitutionId() != null ? instMap.get(nurse.getInstitutionId()) : null;
      row.add(upper(nurse.getFullName()));
      row.add(text(nurse.getDocumentNumber()));
      row.add(text(nurse.getEmail()));
      row.add(text(nurse.getPhone()));
      row.add(inst != null ? upper(inst.getName()) : "");
      row.add(upper(nurse.getProfessionCode()));
      row.add(text(nurse.getProfessionalRegistrationNumber()));
    } else {
      row.add("");
      row.add("");
      row.add("");
      row.add("");
      row.add("");
      row.add("");
      row.add("");
    }
  }

  private List<String> getEnabledFields(VaccineEntity vaccine) {
    List<String> fields = new ArrayList<>();
    String code = vaccine.getCode() != null ? vaccine.getCode().toLowerCase(Locale.ROOT) : "";
    if (!NO_DOSE_VACCINES.contains(code)) {
      fields.add("dose");
    }
    if (vaccine.hasLot()) fields.add("lot_number");
    if (vaccine.hasLaboratory()) fields.add("laboratory");
    if (vaccine.hasSyringe()) fields.add("syringe");
    if (vaccine.hasSyringeLot()) fields.add("syringe_lot");
    if (vaccine.hasDiluent()) fields.add("diluent_lot");
    if (vaccine.hasDropper()) fields.add("dropper");
    if (vaccine.hasPneumococcalType()) fields.add("pneumococcal_type");
    if (vaccine.hasVialCount()) fields.add("vial_count");
    if (vaccine.hasObservation()) fields.add("observation");
    return fields;
  }

  private String getFieldLabel(String key) {
    return switch (key) {
      case "dose" -> "DOSIS";
      case "lot_number" -> "LOTE";
      case "laboratory" -> "LABORATORIO";
      case "syringe" -> "JERINGA";
      case "syringe_lot" -> "LOTE JERINGA";
      case "diluent_lot" -> "DILUYENTE";
      case "dropper" -> "GOTERO";
      case "pneumococcal_type" -> "TIPO NEUMOCOCO";
      case "vial_count" -> "CANTIDAD FRASCOS";
      case "observation" -> "OBSERVACIÓN";
      default -> key.toUpperCase(Locale.ROOT);
    };
  }

  private String getDoseFieldValue(RegistroDiarioDoseData dose, String fieldKey) {
    if (dose == null) return "";
    return switch (fieldKey) {
      case "dose" -> upper(dose.doseLabel());
      case "lot_number" -> text(dose.lotNumber());
      case "laboratory" -> upper(dose.laboratory());
      case "syringe" -> upper(dose.syringe());
      case "syringe_lot" -> text(dose.syringeLot());
      case "diluent_lot" -> text(dose.diluent());
      case "dropper" -> upper(dose.dropper());
      case "pneumococcal_type" -> upper(dose.pneumococcalType());
      case "vial_count" -> text(dose.vialCount());
      case "observation" -> upper(dose.observation());
      default -> "";
    };
  }

  private static String filename(UUID institutionId, Instant from, ReportFormat format) {
    return "registro-diario-" + institutionId + "-" + fileDate(from) + "." + format.extension();
  }

  private static String text(Object value) {
    return value == null ? "" : value.toString().trim();
  }

  private static String upper(String value) {
    return value == null ? "" : value.trim().toUpperCase(Locale.ROOT);
  }

  private static String boolVal(Boolean value) {
    return Boolean.TRUE.equals(value) ? "SÍ" : "NO";
  }

  private static String formatDate(LocalDate date) {
    return date == null ? "" : DATE_FORMAT.format(date);
  }

  private static String mapSex(String sex) {
    if (sex == null || sex.isBlank()) return "";
    String s = sex.trim().toUpperCase(Locale.ROOT);
    if ("MALE".equals(s) || "HOMBRE".equals(s) || "M".equals(s)) return "HOMBRE";
    if ("FEMALE".equals(s) || "MUJER".equals(s) || "F".equals(s)) return "MUJER";
    return s;
  }

  private static String defaultIfBlank(String val, String def) {
    return (val == null || val.isBlank()) ? def : val.trim();
  }

  private static String fileDate(Instant value) {
    return value == null
        ? "sin-fecha"
        : FILE_DATE_FORMAT.format(value.atZone(ZoneOffset.UTC).toLocalDate());
  }
}
