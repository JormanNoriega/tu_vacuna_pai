package com.pai.api.reports.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

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
import com.pai.api.reports.export.ExportedReport;
import com.pai.api.reports.export.ReportFactoryProvider;
import com.pai.api.reports.export.ReportFormat;
import java.io.ByteArrayInputStream;
import java.time.Instant;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.UUID;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

class RegistroDiarioExportServiceTest {

  private RegistroDiarioQuery registroDiarioQuery;
  private PatientIdentityQuery patientIdentityQuery;
  private ReportFactoryProvider factoryProvider;
  private DataScope dataScope;
  private VaccineRepository vaccineRepository;
  private UserRepository userRepository;
  private InstitutionRepository institutionRepository;
  private RegistroDiarioExportService exportService;

  @BeforeEach
  void setUp() {
    registroDiarioQuery = mock(RegistroDiarioQuery.class);
    patientIdentityQuery = mock(PatientIdentityQuery.class);
    factoryProvider = new ReportFactoryProvider();
    dataScope = mock(DataScope.class);
    vaccineRepository = mock(VaccineRepository.class);
    userRepository = mock(UserRepository.class);
    institutionRepository = mock(InstitutionRepository.class);

    exportService =
        new RegistroDiarioExportService(
            registroDiarioQuery,
            patientIdentityQuery,
            factoryProvider,
            dataScope,
            vaccineRepository,
            userRepository,
            institutionRepository);
  }

  @Test
  void exportsRegistroDiarioWithDualLevelHeadersAndPivotedVaccines() throws Exception {
    UUID institutionId = UUID.randomUUID();
    UUID patientId = UUID.randomUUID();
    UUID vaccineId = UUID.randomUUID();
    UUID vaccinatorId = UUID.randomUUID();

    AuthorizedUser actor = mock(AuthorizedUser.class);
    InstitutionEntity inst = mock(InstitutionEntity.class);
    when(inst.getId()).thenReturn(institutionId);
    when(inst.getName()).thenReturn("HOSPITAL CENTRAL");
    when(actor.getInstitution()).thenReturn(inst);
    when(dataScope.resolveInstitutionId(any(), any())).thenReturn(institutionId);

    VaccineEntity bcg =
        new VaccineEntity(
            vaccineId, "BCG (TUBERCULOSIS)", "bcg", "INFANTIL", (short) 1, 0, 12, UUID.randomUUID(), Instant.now());
    bcg.setLegacyFlags(true, true, true, false, false, false, false, false, false);
    when(vaccineRepository.findByActiveTrueOrderByNameAsc()).thenReturn(List.of(bcg));

    Instant now = Instant.parse("2026-03-15T10:00:00Z");
    RegistroDiarioDoseData dose =
        new RegistroDiarioDoseData(
            1L,
            now,
            patientId,
            "BCG",
            "bcg",
            "ÚNICA",
            "LOTE123",
            "LAB PAI",
            "JERINGA 22G",
            "",
            "",
            now,
            "REGISTERED",
            UUID.randomUUID(),
            vaccineId,
            vaccinatorId,
            false,
            "",
            "",
            "",
            1);

    when(registroDiarioQuery.doses(any(), any(), any())).thenReturn(List.of(dose));

    PatientIdentity patient =
        new PatientIdentity(
            patientId,
            "RC",
            "1098765432",
            "JUAN",
            "CARLOS",
            "PÉREZ",
            "GÓMEZ",
            LocalDate.of(2026, 1, 10),
            "MALE");
    when(patientIdentityQuery.byIds(Set.of(patientId))).thenReturn(List.of(patient));

    UserEntity nurse = mock(UserEntity.class);
    when(nurse.getId()).thenReturn(vaccinatorId);
    when(nurse.getFullName()).thenReturn("ANA LÓPEZ");
    when(nurse.getDocumentNumber()).thenReturn("52987123");
    when(nurse.getEmail()).thenReturn("ana@hospital.gov.co");
    when(nurse.getPhone()).thenReturn("3187654321");
    when(nurse.getInstitutionId()).thenReturn(institutionId);
    when(userRepository.findAllById(Set.of(vaccinatorId))).thenReturn(List.of(nurse));

    when(institutionRepository.findAllById(Set.of(institutionId))).thenReturn(List.of(inst));

    ExportedReport report =
        exportService.export(actor, now.minusSeconds(86400), now, ReportFormat.XLSX);

    assertThat(report).isNotNull();
    assertThat(report.content()).isNotEmpty();
    assertThat(report.contentType())
        .isEqualTo("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet");

    try (Workbook workbook = new XSSFWorkbook(new ByteArrayInputStream(report.content()))) {
      Sheet sheet = workbook.getSheetAt(0);

      // Fila 0: Bloques combinados
      assertThat(sheet.getRow(0).getCell(0).getStringCellValue()).isEqualTo("DATOS BÁSICOS");
      assertThat(sheet.getRow(0).getCell(18).getStringCellValue()).isEqualTo("DATOS COMPLEMENTARIOS");

      // BCG esta despues de los 88 campos fijos del paciente (18 de datos basicos)
      assertThat(sheet.getRow(0).getCell(88).getStringCellValue()).isEqualTo("BCG (TUBERCULOSIS)");
      // Categoria Enfermera al final
      int lastCatIndex = 88 + 4; // 88 fijos + 4 campos de BCG (dose, lot, lab, syringe)
      assertThat(sheet.getRow(0).getCell(lastCatIndex).getStringCellValue())
          .isEqualTo("DATOS ENFERMERA");

      // Fila 1: Subencabezados
      assertThat(sheet.getRow(1).getCell(0).getStringCellValue()).isEqualTo("CONSECUTIVO");
      assertThat(sheet.getRow(1).getCell(1).getStringCellValue()).isEqualTo("FECHA DE ATENCIÓN");
      assertThat(sheet.getRow(1).getCell(4).getStringCellValue()).isEqualTo("PRIMER NOMBRE");

      // Fila 2: Datos del paciente y dosis
      assertThat(sheet.getRow(2).getCell(0).getStringCellValue()).isEqualTo("1");
      assertThat(sheet.getRow(2).getCell(3).getStringCellValue()).isEqualTo("1098765432");
      assertThat(sheet.getRow(2).getCell(4).getStringCellValue()).isEqualTo("JUAN");
      assertThat(sheet.getRow(2).getCell(6).getStringCellValue()).isEqualTo("PÉREZ");

      // Subcampo de BCG: Dosis y Lote (columna 88 y 89)
      assertThat(sheet.getRow(2).getCell(88).getStringCellValue()).isEqualTo("ÚNICA");
      assertThat(sheet.getRow(2).getCell(89).getStringCellValue()).isEqualTo("LOTE123");

      // Subcampo de Enfermera
      assertThat(sheet.getRow(2).getCell(lastCatIndex).getStringCellValue()).isEqualTo("ANA LÓPEZ");
      assertThat(sheet.getRow(2).getCell(lastCatIndex + 4).getStringCellValue())
          .isEqualTo("HOSPITAL CENTRAL");
    }

    // Verificar que la exportacion en CSV tambien funcione correctamente con los mismos datos
    ExportedReport csvReport =
        exportService.export(actor, now.minusSeconds(86400), now, ReportFormat.CSV);

    assertThat(csvReport).isNotNull();
    assertThat(csvReport.contentType()).isEqualTo("text/csv; charset=UTF-8");
    assertThat(csvReport.filename()).endsWith(".csv");
    String csvText = new String(csvReport.content(), java.nio.charset.StandardCharsets.UTF_8);
    assertThat(csvText).contains("CONSECUTIVO,FECHA DE ATENCIÓN");
    assertThat(csvText).contains("JUAN");
    assertThat(csvText).contains("1098765432");
    assertThat(csvText).contains("ANA LÓPEZ");
  }
}
