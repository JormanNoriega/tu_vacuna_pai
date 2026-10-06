package com.pai.api.shared.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noMethods;

import com.pai.api.attentions.service.VaccineCatalogPolicy;
import com.pai.api.audit.service.AuditRecorder;
import com.pai.api.identity.service.InstitutionCatalogSeeder;
import com.pai.api.reports.service.ClinicalMetricsQuery;
import com.pai.api.shared.application.ProcessedOperationsPort;
import com.pai.api.synchronization.service.command.SyncCommandHandler;
import com.tngtech.archunit.base.DescribedPredicate;
import com.tngtech.archunit.core.importer.ImportOption;
import com.tngtech.archunit.junit.AnalyzeClasses;
import com.tngtech.archunit.junit.ArchTest;
import com.tngtech.archunit.lang.ArchRule;
import jakarta.persistence.Entity;

/**
 * Reglas de la arquitectura por capas (ADR-006). Sustituyen por verificación
 * automatica la garantia estructural que daba hexagonal: un controller no
 * consulta repositorios ni expone entidades JPA; el service concentra la
 * logica de negocio; la seguridad se mantiene separada.
 */
@AnalyzeClasses(packages = "com.pai.api", importOptions = ImportOption.DoNotIncludeTests.class)
public class ArchitectureTest {

  @ArchTest
  static final ArchRule controllers_must_not_depend_on_repositories = noClasses()
      .that()
      .resideInAPackage("..controller..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..repository..")
      .as("los controllers no deben consultar repositorios (ADR-006)");

  @ArchTest
  static final ArchRule controllers_must_not_depend_on_entities = noClasses()
      .that()
      .resideInAPackage("..controller..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..entity..")
      .as("los controllers no deben depender de entidades JPA (ADR-006)");

  @ArchTest
  static final ArchRule controllers_depend_on_services = classes()
      .that()
      .resideInAPackage("..controller..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..service..")
      .as("los controllers deben delegar en los servicios (ADR-006)");

  @ArchTest
  static final ArchRule controllers_must_return_dtos_not_entities = noMethods()
      .that()
      .arePublic()
      .and()
      .areDeclaredInClassesThat()
      .resideInAPackage("..controller..")
      .should()
      .haveRawReturnType(DescribedPredicate.describe(
          "a JPA @Entity", javaClass -> javaClass.isAnnotatedWith(Entity.class)))
      .as("ningun metodo de controller puede devolver una entidad @Entity; siempre un DTO"
          + " (ADR-006)");

  @ArchTest
  static final ArchRule services_must_not_depend_on_controllers = noClasses()
      .that()
      .resideInAPackage("..service..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..controller..")
      .as("los services no deben depender de controllers (ADR-006)");

  @ArchTest
  static final ArchRule repositories_may_depend_on_entities = classes()
      .that()
      .resideInAPackage("..repository..")
      .and()
      .areTopLevelClasses()
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..entity..")
      .as("los repositories acceden a las entidades JPA (ADR-006)");

  @ArchTest
  static final ArchRule security_must_not_depend_on_controllers_or_repositories = noClasses()
      .that()
      .resideInAPackage("..shared.security..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..controller..")
      .andShould()
      .dependOnClassesThat()
      .resideInAPackage("..repository..")
      .as("la seguridad se mantiene separada de controllers y repositories (ADR-006)");

  @ArchTest
  static final ArchRule attentions_must_not_depend_on_catalog_repositories_or_entities = noClasses()
      .that()
      .resideInAPackage("..attentions..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..catalog.repository..")
      .orShould()
      .dependOnClassesThat()
      .resideInAPackage("..catalog.entity..")
      .as("el modulo clinico no depende de la persistencia del catalogo;"
          + " consulta el catalogo via VaccineCatalogPolicy (DIP)");

  @ArchTest
  static final ArchRule attentions_must_not_depend_on_patients_repositories_or_entities =
      noClasses()
          .that()
          .resideInAPackage("..attentions..")
          .should()
          .dependOnClassesThat()
          .resideInAPackage("..patients.repository..")
          .orShould()
          .dependOnClassesThat()
          .resideInAPackage("..patients.entity..")
          .as("el modulo clinico no depende de la persistencia de pacientes;"
              + " consulta el paciente via PatientScopePolicy (DIP)");

  @ArchTest
  static final ArchRule policy_implementations_live_in_catalog = classes()
      .that()
      .implement(VaccineCatalogPolicy.class)
      .should()
      .resideInAPackage("..catalog..")
      .as("las implementaciones del puerto VaccineCatalogPolicy viven en el modulo catalogo (DIP)");

  @ArchTest
  static final ArchRule audit_persistence_is_encapsulated = noClasses()
      .that()
      .resideOutsideOfPackage("..audit..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..audit.repository..")
      .orShould()
      .dependOnClassesThat()
      .resideInAPackage("..audit.entity..")
      .as("la persistencia de auditoria queda encapsulada en el modulo audit;"
          + " el resto depende del puerto AuditRecorder (DIP)");

  @ArchTest
  static final ArchRule audit_recorder_implementations_live_in_audit = classes()
      .that()
      .implement(AuditRecorder.class)
      .should()
      .resideInAPackage("..audit..")
      .as("las implementaciones del puerto AuditRecorder viven en el modulo audit (DIP)");

  @ArchTest
  static final ArchRule institution_catalog_seeder_implementations_live_in_catalog = classes()
      .that()
      .implement(InstitutionCatalogSeeder.class)
      .should()
      .resideInAPackage("..catalog..")
      .as("las implementaciones del puerto InstitutionCatalogSeeder viven en el modulo catalogo"
          + " (DIP)");

  @ArchTest
  static final ArchRule reports_must_not_depend_on_attentions_persistence = noClasses()
      .that()
      .resideInAPackage("..reports..")
      .should()
      .dependOnClassesThat()
      .resideInAPackage("..attentions.repository..")
      .orShould()
      .dependOnClassesThat()
      .resideInAPackage("..attentions.entity..")
      .as("reportes no depende de la persistencia del modulo clinico;"
          + " consulta las metricas via ClinicalMetricsQuery (DIP)");

  @ArchTest
  static final ArchRule clinical_metrics_query_implementations_live_in_attentions = classes()
      .that()
      .implement(ClinicalMetricsQuery.class)
      .should()
      .resideInAPackage("..attentions..")
      .as("las implementaciones del puerto ClinicalMetricsQuery viven en el modulo attentions"
          + " (DIP)");

  @ArchTest
  static final ArchRule processed_operations_port_implementations_live_in_synchronization =
      classes()
          .that()
          .implement(ProcessedOperationsPort.class)
          .should()
          .resideInAPackage("..synchronization..")
          .as("las implementaciones del puerto ProcessedOperationsPort viven en el modulo"
              + " synchronization (DIP)");

  @ArchTest
  static final ArchRule sync_command_handlers_live_in_synchronization_command = classes()
      .that()
      .implement(SyncCommandHandler.class)
      .should()
      .resideInAPackage("..synchronization.service.command..")
      .as("los handlers de comando de sincronizacion viven en synchronization.service.command"
          + " (OCP)");
}
