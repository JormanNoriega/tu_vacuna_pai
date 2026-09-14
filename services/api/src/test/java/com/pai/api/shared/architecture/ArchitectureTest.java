package com.pai.api.shared.architecture;

import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.classes;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noClasses;
import static com.tngtech.archunit.lang.syntax.ArchRuleDefinition.noMethods;

import com.pai.api.attentions.service.VaccineCatalogPolicy;
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
            .haveRawReturnType(
                    DescribedPredicate.describe("a JPA @Entity", javaClass -> javaClass.isAnnotatedWith(Entity.class)))
            .as("ningun metodo de controller puede devolver una entidad @Entity; siempre un DTO (ADR-006)");

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
    static final ArchRule policy_implementations_live_in_catalog = classes()
            .that()
            .implement(VaccineCatalogPolicy.class)
            .should()
            .resideInAPackage("..catalog..")
            .as("las implementaciones del puerto VaccineCatalogPolicy viven en el modulo catalogo (DIP)");
}
