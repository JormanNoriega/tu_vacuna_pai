# Desglose Completo y Pedagógico de Patrones de Diseño (GoF) — Tu Vacuna PAI

Este documento presenta el desglose exhaustivo de los **8 patrones de diseño** (creacionales y estructurales) implementados y reconocidos en el backend del proyecto **Tu Vacuna PAI** (`services/api`, Spring Boot 3, Java 21).

Para cada patrón se sigue estrictamente la siguiente estructura:
1. **Función del patrón:** Explicación técnica y a la vez simple/coloquial para personas no técnicas, detallando por qué se implementó, qué problema o incumplimiento resolvía y qué mejora representa.
2. **Cuadro de clases:** Tabla con el rol GoF de cada clase creada o modificada, qué hace a nivel del proyecto y qué soluciona, mencionando brevemente las clases preexistentes que se conectan al patrón.
3. **Detalle clase por clase:** Nombre, ruta con enlace, **código fuente completo** y una explicación minuciosa, línea por línea o bloque por bloque, explicando el funcionamiento de manera clara para personas sin dominio avanzado de Java o Programación Orientada a Objetos.

---

# ÍNDICE GENERAL

- [1. Patrón Builder (Creacional)](#1-patrón-builder-creacional)
- [2. Patrón Prototype (Creacional)](#2-patrón-prototype-creacional)
- [3. Patrón Abstract Factory (Creacional)](#3-patrón-abstract-factory-creacional)
- [4. Patrón Factory Method (Creacional)](#4-patrón-factory-method-creacional)
- [5. Patrón Singleton (Creacional)](#5-patrón-singleton-creacional)
- [6. Patrón Proxy / Protection Proxy (Estructural)](#6-patrón-proxy--protection-proxy-estructural)
- [7. Patrón Decorator (Estructural)](#7-patrón-decorator-estructural)
- [8. Patrón Adapter (Estructural)](#8-patrón-adapter-estructural)

---

# 1. Patrón Builder (Creacional)

## 1.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina que vas a armar una hamburguesa con 25 ingredientes posibles. Si el cocinero te obliga a pedirla diciendo todos los 25 ingredientes de un solo golpe y en un orden exacto (por ejemplo: "pan, carne, queso, lechuga, tomate, pepinillo, salsa 1, salsa 2..."), es casi seguro que te vas a equivocar, olvidarás alguno o confundirás el orden de las salsas. 
El patrón **Builder** es como tener una hoja de pedido con casillas: puedes marcar paso a paso lo que quieres ("con queso", "con tomate"), omitir lo que no necesitas, y al final le dices al cocinero: "¡Ármala!" (`.build()`). En ese último segundo, el cocinero revisa que la hamburguesa tenga al menos el pan y la carne obligatoria antes de entregártela.

### En términos técnicos y en el proyecto:
El patrón Builder separa la construcción de un objeto complejo de su representación final, permitiendo que el mismo proceso de construcción cree objetos paso a paso y de manera controlada.
- **¿Por qué lo hicimos?** Antes del patrón, la entidad de una dosis aplicada (`AppliedDoseEntity`) se creaba mediante un **constructor telescópico monstruoso de 23 parámetros posicionales seguidos**, la mayoría de tipo `String` o `UUID`. Si el programador invertía sin querer la posición del `vaccineCode` con el `vaccineName`, Java no avisaba porque ambos eran cadenas de texto (`String`), provocando datos corruptos silenciosos. Además, los campos del wizard de la app móvil se agregaban en una segunda fase mediante un método mutable `applyOperationalFields(...)`, dejando el objeto temporalmente a medio armar.
- **¿Qué soluciona?** Reemplaza los 23 argumentos por llamadas nombradas y legibles (`.vaccine(...)`, `.dose(...)`, `.operational(...)`), centraliza las validaciones de campos obligatorios en el método final `.build()` y asigna automáticamente valores por defecto (como generar un identificador único si no venía uno, la fecha actual y el estado inicial `REGISTERED`).

---

## 1.2. Cuadro de clases del patrón Builder

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`AppliedDoseEntity.Builder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/attentions/entity/AppliedDoseEntity.java#L138-L293) | **Builder (Constructor Concreto)** | Es una clase estática interna que recopila uno a uno los atributos de la dosis clínica y ejecuta el ensamblado final validando reglas de negocio. | Elimina el constructor gigante de 23 argumentos confusos. Agrupa campos por afinidad y rechaza la creación si faltan campos obligatorios. |
| [`AppliedDoseEntity`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/attentions/entity/AppliedDoseEntity.java) | **Product (Producto)** | Entidad de base de datos JPA que almacena la dosis de vacuna aplicada a un paciente en una atención clínica. | Garantiza la integridad clínica: una vez construida, nace en estado válido y no permite modificaciones destructivas (es append-only). |

### Clases preexistentes que se conectan con el patrón:
- [`AttentionService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/attentions/service/AttentionService.java): Actúa en el rol de **Client / Director**. En su método `registerDose(...)` invoca `AppliedDoseEntity.builder()` para construir la dosis paso a paso a partir de los datos recibidos de la aplicación móvil y del catálogo de vacunas.

---

## 1.3. Detalle clase por clase

### Clase: [`AppliedDoseEntity.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/attentions/entity/AppliedDoseEntity.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/attentions/entity/AppliedDoseEntity.java`

#### Código fuente completo:
```java
package com.pai.api.attentions.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

/**
 * Dosis aplicada dentro de una atencion. Es append-only: no admite UPDATE ni
 * DELETE; una correccion se representa con una cancelacion (motivo, actor,
 * timestamp) y, si corresponde, una nueva dosis.
 *
 * <p>Guarda snapshot del catalogo vigente al momento del registro
 * (nombre/codigo de vacuna, etiqueta de dosis, tipo de neumococo y opciones
 * operativas elegidas) para que el historial no cambie si el catalogo se
 * modifica despues.
 */
@Entity
@Table(name = "applied_doses", schema = "app")
public class AppliedDoseEntity {

  public enum Status {
    REGISTERED,
    CANCELLED
  }

  @Id
  private UUID id;

  @Column(name = "attention_id", nullable = false)
  private UUID attentionId;

  @Column(name = "vaccine_id", nullable = false)
  private UUID vaccineId;

  @Column(name = "lot_id")
  private UUID lotId;

  @Column(name = "lot_number")
  private String lotNumber;

  @Column(name = "application_date", nullable = false)
  private Instant applicationDate;

  @Column(name = "dose_option_id")
  private UUID doseOptionId;

  @Column(name = "pneumococcal_type_option_id")
  private UUID pneumococcalTypeOptionId;

  @Column(name = "vaccine_name_snapshot", nullable = false)
  private String vaccineNameSnapshot;

  @Column(name = "vaccine_code_snapshot", nullable = false)
  private String vaccineCodeSnapshot;

  @Column(name = "dose_label_snapshot", nullable = false)
  private String doseLabelSnapshot;

  @Column(name = "dose_value_snapshot")
  private String doseValueSnapshot;

  @Column(name = "pneumococcal_type_snapshot")
  private String pneumococcalTypeSnapshot;

  @Column(name = "catalog_version", nullable = false)
  private long catalogVersion;

  @Column(name = "selected_laboratory_id")
  private UUID selectedLaboratoryId;

  @Column(name = "selected_laboratory_snapshot")
  private String selectedLaboratorySnapshot;

  @Column(name = "selected_syringe_id")
  private UUID selectedSyringeId;

  @Column(name = "selected_syringe_snapshot")
  private String selectedSyringeSnapshot;

  @Column(name = "selected_dropper_id")
  private UUID selectedDropperId;

  @Column(name = "selected_dropper_snapshot")
  private String selectedDropperSnapshot;

  @Column(name = "selected_observation_id")
  private UUID selectedObservationId;

  @Column(name = "selected_observation_snapshot")
  private String selectedObservationSnapshot;

  @Column(name = "syringe_lot")
  private String syringeLot;

  private String diluent;

  @Column(name = "vial_count")
  private Integer vialCount;

  @Column(name = "custom_observation")
  private String customObservation;

  @Enumerated(EnumType.STRING)
  @Column(nullable = false)
  private Status status;

  @Column(name = "cancelled_reason")
  private String cancelledReason;

  @Column(name = "cancelled_by")
  private UUID cancelledBy;

  @Column(name = "cancelled_at")
  private Instant cancelledAt;

  @Column(name = "created_at", nullable = false)
  private Instant createdAt;

  protected AppliedDoseEntity() {}

  public static Builder builder() {
    return new Builder();
  }

  /**
   * Construction por pasos de una dosis nueva. Centraliza los valores por
   * defecto (id autogenerado, estado {@code REGISTERED}, {@code createdAt}) y
   * valida los campos requeridos del agregado, reemplazando el constructor
   * telescopico de 23 argumentos y la inicializacion en dos fases
   * ({@code applyOperationalFields}). La entidad no depende de tipos de la capa
   * de servicio: el Builder recibe datos primitivos del dominio.
   */
  public static final class Builder {
    private UUID id;
    private UUID attentionId;
    private Instant applicationDate;
    private UUID vaccineId;
    private String vaccineNameSnapshot;
    private String vaccineCodeSnapshot;
    private long catalogVersion;
    private UUID doseOptionId;
    private String doseLabelSnapshot;
    private String doseValueSnapshot;
    private UUID pneumococcalTypeOptionId;
    private String pneumococcalTypeSnapshot;
    private UUID lotId;
    private String lotNumber;
    private UUID selectedLaboratoryId;
    private String selectedLaboratorySnapshot;
    private UUID selectedSyringeId;
    private String selectedSyringeSnapshot;
    private UUID selectedDropperId;
    private String selectedDropperSnapshot;
    private UUID selectedObservationId;
    private String selectedObservationSnapshot;
    private String syringeLot;
    private String diluent;
    private Integer vialCount;
    private String customObservation;

    private Builder() {}

    public Builder id(UUID id) {
      this.id = id;
      return this;
    }

    public Builder attentionId(UUID attentionId) {
      this.attentionId = attentionId;
      return this;
    }

    public Builder applicationDate(Instant applicationDate) {
      this.applicationDate = applicationDate;
      return this;
    }

    public Builder lot(UUID lotId, String lotNumber) {
      this.lotId = lotId;
      this.lotNumber = lotNumber;
      return this;
    }

    public Builder vaccine(UUID vaccineId, String name, String code, long catalogVersion) {
      this.vaccineId = vaccineId;
      this.vaccineNameSnapshot = name;
      this.vaccineCodeSnapshot = code;
      this.catalogVersion = catalogVersion;
      return this;
    }

    public Builder dose(UUID doseOptionId, String label, String value) {
      this.doseOptionId = doseOptionId;
      this.doseLabelSnapshot = label;
      this.doseValueSnapshot = value;
      return this;
    }

    public Builder pneumococcal(UUID optionId, String snapshot) {
      this.pneumococcalTypeOptionId = optionId;
      this.pneumococcalTypeSnapshot = snapshot;
      return this;
    }

    public Builder laboratory(UUID id, String snapshot) {
      this.selectedLaboratoryId = id;
      this.selectedLaboratorySnapshot = snapshot;
      return this;
    }

    public Builder syringe(UUID id, String snapshot) {
      this.selectedSyringeId = id;
      this.selectedSyringeSnapshot = snapshot;
      return this;
    }

    public Builder dropper(UUID id, String snapshot) {
      this.selectedDropperId = id;
      this.selectedDropperSnapshot = snapshot;
      return this;
    }

    public Builder observation(UUID id, String snapshot) {
      this.selectedObservationId = id;
      this.selectedObservationSnapshot = snapshot;
      return this;
    }

    /** Campos operativos opcionales capturados por el wizard (Paso 3). */
    public Builder operational(
        String syringeLot, String diluent, Integer vialCount, String customObservation) {
      this.syringeLot = syringeLot;
      this.diluent = diluent;
      this.vialCount = vialCount;
      this.customObservation = customObservation;
      return this;
    }

    public AppliedDoseEntity build() {
      if (attentionId == null) {
        throw new IllegalStateException("attentionId es obligatorio.");
      }
      if (vaccineId == null) {
        throw new IllegalStateException("vaccineId es obligatorio.");
      }
      if (vaccineNameSnapshot == null) {
        throw new IllegalStateException("vaccineNameSnapshot es obligatorio.");
      }
      if (vaccineCodeSnapshot == null) {
        throw new IllegalStateException("vaccineCodeSnapshot es obligatorio.");
      }
      if (doseLabelSnapshot == null) {
        throw new IllegalStateException("doseLabelSnapshot es obligatorio.");
      }

      Instant now = Instant.now();
      AppliedDoseEntity dose = new AppliedDoseEntity();
      dose.id = id != null ? id : UUID.randomUUID();
      dose.attentionId = attentionId;
      dose.vaccineId = vaccineId;
      dose.applicationDate = applicationDate != null ? applicationDate : now;
      dose.vaccineNameSnapshot = vaccineNameSnapshot;
      dose.vaccineCodeSnapshot = vaccineCodeSnapshot;
      dose.catalogVersion = catalogVersion;
      dose.doseOptionId = doseOptionId;
      dose.doseLabelSnapshot = doseLabelSnapshot;
      dose.doseValueSnapshot = doseValueSnapshot;
      dose.pneumococcalTypeOptionId = pneumococcalTypeOptionId;
      dose.pneumococcalTypeSnapshot = pneumococcalTypeSnapshot;
      dose.lotId = lotId;
      dose.lotNumber = lotNumber;
      dose.selectedLaboratoryId = selectedLaboratoryId;
      dose.selectedLaboratorySnapshot = selectedLaboratorySnapshot;
      dose.selectedSyringeId = selectedSyringeId;
      dose.selectedSyringeSnapshot = selectedSyringeSnapshot;
      dose.selectedDropperId = selectedDropperId;
      dose.selectedDropperSnapshot = selectedDropperSnapshot;
      dose.selectedObservationId = selectedObservationId;
      dose.selectedObservationSnapshot = selectedObservationSnapshot;
      dose.syringeLot = syringeLot;
      dose.diluent = diluent;
      dose.vialCount = vialCount;
      dose.customObservation = customObservation;
      dose.status = Status.REGISTERED;
      dose.createdAt = now;
      return dose;
    }
  }

  public void cancel(String reason, UUID actorId, Instant now) {
    this.status = Status.CANCELLED;
    this.cancelledReason = reason;
    this.cancelledBy = actorId;
    this.cancelledAt = now;
  }

  public String getSyringeLot() { return syringeLot; }
  public String getDiluent() { return diluent; }
  public Integer getVialCount() { return vialCount; }
  public String getCustomObservation() { return customObservation; }
  public UUID getId() { return id; }
  public UUID getAttentionId() { return attentionId; }
  public UUID getVaccineId() { return vaccineId; }
  public UUID getLotId() { return lotId; }
  public String getLotNumber() { return lotNumber; }
  public Instant getApplicationDate() { return applicationDate; }
  public UUID getDoseOptionId() { return doseOptionId; }
  public UUID getPneumococcalTypeOptionId() { return pneumococcalTypeOptionId; }
  public String getVaccineNameSnapshot() { return vaccineNameSnapshot; }
  public String getVaccineCodeSnapshot() { return vaccineCodeSnapshot; }
  public String getDoseLabelSnapshot() { return doseLabelSnapshot; }
  public String getDoseValueSnapshot() { return doseValueSnapshot; }
  public String getPneumococcalTypeSnapshot() { return pneumococcalTypeSnapshot; }
  public long getCatalogVersion() { return catalogVersion; }
  public UUID getSelectedLaboratoryId() { return selectedLaboratoryId; }
  public String getSelectedLaboratorySnapshot() { return selectedLaboratorySnapshot; }
  public UUID getSelectedSyringeId() { return selectedSyringeId; }
  public String getSelectedSyringeSnapshot() { return selectedSyringeSnapshot; }
  public UUID getSelectedDropperId() { return selectedDropperId; }
  public String getSelectedDropperSnapshot() { return selectedDropperSnapshot; }
  public UUID getSelectedObservationId() { return selectedObservationId; }
  public String getSelectedObservationSnapshot() { return selectedObservationSnapshot; }
  public Status getStatus() { return status; }
  public String getCancelledReason() { return cancelledReason; }
  public UUID getCancelledBy() { return cancelledBy; }
  public Instant getCancelledAt() { return cancelledAt; }
  public Instant getCreatedAt() { return createdAt; }
}
```

#### Explicación minuciosa a nivel de código:

1. **Anotaciones de la entidad (`@Entity`, `@Table`) [L22-L23]:**
   - `@Entity`: Le dice a Java y a la base de datos que esta clase representa una tabla real.
   - `@Table(name = "applied_doses", schema = "app")`: Especifica que se guardará en la tabla llamada `applied_doses` dentro del esquema `app` de PostgreSQL.
2. **Campos "Snapshot" (Foto fija del momento) [L55-L68]:**
   - Campos como `vaccineNameSnapshot` o `doseLabelSnapshot` guardan una copia en texto del nombre de la vacuna al momento de aplicarla. ¿Por qué? Porque si dentro de 5 años el Ministerio de Salud le cambia el nombre oficial a la vacuna, el historial del paciente debe seguir diciendo cómo se llamaba exactamente el día de la inyección.
3. **Constructor protegido vacío [L124]:**
   - `protected AppliedDoseEntity() {}`: Está protegido para que nadie desde afuera pueda hacer un `new AppliedDoseEntity()` sin pasar por las reglas del Builder. Solo las herramientas de base de datos (JPA) o el propio Builder pueden instanciarlo.
4. **Punto de entrada estático [L126-L128]:**
   - `public static Builder builder()`: Es una función fábrica conveniente que entrega una libreta en blanco (una nueva instancia de `Builder`) para empezar a configurar la dosis.
5. **Clase interna del constructor (`public static final class Builder`) [L138-L166]:**
   - Es una clase que vive dentro de la entidad y tiene copias temporales de los campos necesarios. Su constructor `private Builder() {}` asegura que solo se obtenga llamando a `AppliedDoseEntity.builder()`.
6. **Métodos de paso fluido (Fluent Interface) [L168-L242]:**
   - Métodos como `id(UUID id)`, `attentionId(UUID attentionId)` o `vaccine(...)`: Reciben un dato, lo guardan en su variable interna y devuelven `return this;`. Al devolver `this` (el mismo Builder), permiten encadenar llamadas con puntos: `.id(...).vaccine(...).dose(...)`.
   - `operational(...)` [L235-L242]: Agrupa en un solo método legible los 4 campos secundarios del paso 3 del wizard (lote de jeringa, diluyente, cantidad de frascos y observaciones), evitando crear 4 métodos sueltos para datos que siempre vienen juntos.
7. **El método maestro `build()` [L244-L292]:**
   - **Validación de invariantes [L245-L259]:** Antes de crear la entidad, verifica con `if (campo == null)` que los 5 campos vitales (atención, vacuna, nombre, código y dosis) existan. Si alguno falta, detiene el programa lanzando un error claro (`IllegalStateException`), impidiendo guardar registros médicos incompletos o corruptos.
   - **Valores por defecto inteligentes [L263-L266]:**
     - Si no se envió un `id`, genera uno nuevo aleatorio con `UUID.randomUUID()`.
     - Si no se envió una fecha de aplicación, toma el instante actual del reloj con `Instant.now()`.
     - Fija el estado inicial inalterable en `REGISTERED` y la fecha de creación en `now`.
   - **Transferencia segura [L262-L291]:** Crea la instancia definitiva de `AppliedDoseEntity`, le traspasa uno a uno los valores ya validados y la devuelve lista para ser persistida.

---

# 2. Patrón Prototype (Creacional)

## 2.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina una fotocopiadora. Si tienes un formulario modelo con 20 campos ya llenos (tipo de vacuna, orden de visualización, nombres técnicos) y necesitas entregárselo a una clínica nueva, tienes dos opciones: o vuelves a escribir a mano los 20 campos hoja por hoja para cada clínica, o metes el formulario original en la fotocopiadora, sacas una copia idéntica y solo le cambias el sello que dice "Propiedad de la Clínica San José".
El patrón **Prototype** hace exactamente eso: en lugar de obligar a que otra clase construya un objeto nuevo campo por campo desde cero, el objeto plantilla original se "fotocopia" o clona a sí mismo, cambiando únicamente los dos o tres datos que corresponden al nuevo destino.

### En términos técnicos y en el proyecto:
El patrón Prototype especifica las clases de objetos a crear mediante una instancia prototípica y crea nuevos objetos clonando este prototipo.
- **¿Por qué lo hicimos?** En el catálogo de vacunas existen plantillas globales (`VaccineOptionTemplateEntity`) que representan las dosis y opciones estándar de Colombia. Cuando una institución de salud (IPS) se da de alta en el sistema o activa una vacuna, esas opciones globales deben sembrarse en su catálogo local. Antes del patrón, el servicio `InstitutionVaccineService` hacía un `new InstitutionVaccineOptionEntity(...)` con 11 parámetros manuales repetido exactamente igual en dos métodos diferentes (`enable` y `doClone`). Violaba el principio DRY (Don't Repeat Yourself), y si la plantilla agregaba un nuevo campo, había que acordarse de modificar el código en ambos métodos.
- **¿Qué soluciona?** Define la interfaz `InstitutionOptionPrototype` con el método `copyToInstitution(institutionId, actorId)`. Ahora es la propia plantilla la que sabe cómo duplicarse hacia la institución, encapsulando la lógica de clonación, generando un nuevo identificador único para el clon y vinculando el campo `sourceTemplateId` para rastrear de qué plantilla original nació la copia. Además, evita deliberadamente la interfaz defectuosa `Cloneable` de Java, usando una clonación explícita segura para bases de datos (JPA).

---

## 2.2. Cuadro de clases del patrón Prototype

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`InstitutionOptionPrototype`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/entity/InstitutionOptionPrototype.java) | **Prototype (Interfaz Prototipo)** | Declara la operación abstracta de clonación hacia una institución de salud destinataria. | Desacopla al servicio de la implementación interna de los datos, estandarizando cómo cualquier opción de catálogo puede clonarse. |
| [`VaccineOptionTemplateEntity`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/entity/VaccineOptionTemplateEntity.java) | **ConcretePrototype (Prototipo Concreto)** | Es la plantilla de catálogo global en base de datos. Implementa el método de clonación copiando su propio estado. | Elimina la duplicación de código en el sembrado de catálogos (DRY). Asegura que el clon conserve todas las reglas originales y trace su origen (`sourceTemplateId`). |

### Clases preexistentes que se conectan con el patrón:
- [`InstitutionVaccineService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/InstitutionVaccineService.java): Es el **Client**. Cuando habilita una vacuna para un centro médico (`enable`) o clona el catálogo institucional (`doClone`), simplemente recorre las plantillas y ejecuta `template.copyToInstitution(institutionId, actorId)` en una sola línea limpia.
- [`InstitutionVaccineOptionEntity`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/entity/InstitutionVaccineOptionEntity.java): Es el objeto clon resultante que queda registrado en la base de datos para la clínica específica.

---

## 2.3. Detalle clase por clase

### Clase: [`InstitutionOptionPrototype.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/entity/InstitutionOptionPrototype.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/catalog/entity/InstitutionOptionPrototype.java`

#### Código fuente completo:
```java
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
```

#### Explicación minuciosa a nivel de código:
1. **Definición de Interfaz (`public interface`) [L14]:**
   - En Java, una interfaz es un contrato o compromiso: no escribe cómo hacer las cosas, sino qué cosas está obligado a saber hacer quien la implemente.
2. **Método de clonación (`copyToInstitution`) [L17]:**
   - Recibe dos únicos parámetros: `institutionId` (el código de la clínica u hospital al que le vamos a asignar la opción) y `actorId` (el usuario o enfermero responsable de la operación).
   - Retorna un `InstitutionVaccineOptionEntity`, que es el nuevo objeto clon adaptado para operar en esa institución.

---

### Clase: [`VaccineOptionTemplateEntity.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/entity/VaccineOptionTemplateEntity.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/catalog/entity/VaccineOptionTemplateEntity.java`

#### Código fuente completo:
```java
package com.pai.api.catalog.entity;

import jakarta.persistence.*;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "vaccine_option_templates", schema = "app")
public class VaccineOptionTemplateEntity implements CatalogOption, InstitutionOptionPrototype {
  @Id
  private UUID id;

  @Column(name = "vaccine_id", nullable = false)
  private UUID vaccineId;

  @Column(name = "field_type", nullable = false)
  private String fieldType;

  @Column(nullable = false)
  private String value;

  @Column(name = "value_normalized", insertable = false, updatable = false)
  private String valueNormalized;

  @Column(name = "display_name", nullable = false)
  private String displayName;

  @Column(name = "sort_order", nullable = false)
  private int sortOrder;

  @Column(name = "is_default", nullable = false)
  private boolean isDefault;

  @Column(name = "is_active", nullable = false)
  private boolean active;

  @Column(name = "created_by", nullable = false, updatable = false)
  private UUID createdBy;

  @Column(name = "updated_by", nullable = false)
  private UUID updatedBy;

  @Column(name = "created_at", nullable = false, updatable = false)
  private Instant createdAt;

  @Column(name = "updated_at", nullable = false)
  private Instant updatedAt;

  @Version
  private long version;

  protected VaccineOptionTemplateEntity() {}

  public VaccineOptionTemplateEntity(
      UUID id,
      UUID vaccineId,
      String type,
      String value,
      String display,
      int order,
      boolean def,
      UUID actor,
      Instant now) {
    this.id = id;
    this.vaccineId = vaccineId;
    fieldType = type;
    this.value = value;
    displayName = display;
    sortOrder = order;
    isDefault = def;
    active = true;
    createdBy = actor;
    updatedBy = actor;
    createdAt = now;
    updatedAt = now;
  }

  /**
   * Prototype: clona este template como opcion operativa de la institucion.
   * Cambia solo id (nuevo), institucion y actor; el resto de atributos se copian
   * y {@code sourceTemplateId} deja explicito el prototipo de origen.
   */
  @Override
  public InstitutionVaccineOptionEntity copyToInstitution(UUID institutionId, UUID actorId) {
    return new InstitutionVaccineOptionEntity(
        UUID.randomUUID(),
        institutionId,
        vaccineId,
        fieldType,
        value,
        displayName,
        sortOrder,
        false,
        id,
        actorId,
        Instant.now());
  }

  public UUID getId() { return id; }
  public UUID getVaccineId() { return vaccineId; }
  public String getFieldType() { return fieldType; }
  public String getValue() { return value; }
  public String getDisplayName() { return displayName; }
  public int getSortOrder() { return sortOrder; }
  public boolean isDefault() { return isDefault; }
  public boolean isActive() { return active; }
  public String getValueNormalized() { return valueNormalized; }
  public long getVersion() { return version; }

  public void update(
      String value, String display, int order, boolean def, boolean active, UUID actor) {
    this.value = value;
    displayName = display;
    sortOrder = order;
    isDefault = def;
    this.active = active;
    updatedBy = actor;
    updatedAt = Instant.now();
  }
}
```

#### Explicación minuciosa a nivel de código:
1. **Implementación de la interfaz prototipo [L9]:**
   - `implements CatalogOption, InstitutionOptionPrototype`: Indica que esta clase asume el contrato del patrón Prototype.
2. **Atributos de la plantilla [L10-L50]:**
   - Contiene la información oficial de la opción clínica: `fieldType` (por ejemplo: si es jeringa, diluyente, vía de administración), `value` (el valor técnico interno), `displayName` (el nombre legible para los médicos) y `sortOrder` (el orden en que debe aparecer en la pantalla de la app).
3. **El método de clonación `@Override copyToInstitution` [L83-L97]:**
   - `@Override`: Le indica al compilador que este método cumple exactamente con la promesa hecha en la interfaz `InstitutionOptionPrototype`.
   - **`UUID.randomUUID()` [L86]:** Genera un identificador completamente nuevo y único para la copia. La copia es una fila independiente en la base de datos, por lo que nunca debe compartir el mismo `id` que la plantilla padre.
   - **`institutionId` y `actorId` [L87, L95]:** Recibe la institución y el actor y los coloca en el clon. Esto es lo único que cambia de contexto.
   - **Copia idéntica de atributos [L88-L92]:** Traspasa directamente `vaccineId`, `fieldType`, `value`, `displayName` y `sortOrder` de sí misma (`this`) hacia el nuevo objeto sin que nadie externo tenga que saber qué atributos existen.
   - **Trazabilidad con `id` como `sourceTemplateId` [L94]:** Le pasa su propio identificador original (`id`) al clon para que quede guardado en el campo `sourceTemplateId`. Gracias a esto, si en el futuro se audita el sistema, se puede saber con total certeza de qué plantilla del Ministerio nació esa opción clínica.

---

# 3. Patrón Abstract Factory (Creacional)

## 3.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina una fábrica de muebles que diseña dos estilos de salas: **Estilo Rústico de Madera** y **Estilo Moderno de Cristal**. En ambos estilos necesitas tres cosas: una mesa de centro, un sofá y una lámpara. Si mezclas una mesa de madera rústica con un sofá futurista de metal y cristal, la sala se verá horrible y descoordinada.
El patrón **Abstract Factory** es una "fábrica de fábricas": tú solo dices: "Quiero una sala completa moderna" o "Quiero una sala completa rústica", y la fábrica elegida te entrega las tres piezas asegurándose de que todas pertenezcan a la misma familia y encajen a la perfección entre sí, sin que el comprador tenga que preocuparse por cómo se fabricó cada clavo o cada vidrio.

### En términos técnicos y en el proyecto:
Provee una interfaz para crear **familias de objetos relacionados o dependientes** sin especificar sus clases concretas.
- **¿Por qué lo hicimos?** El Ministerio de Salud y los administradores del PAI necesitan descargar el reporte del "Registro Diario de Vacunación" en dos formatos completamente diferentes: **Excel (.XLSX)** con celdas, estilos en negrita y hojas de cálculo binarias creadas con la librería Apache POI; y **CSV (.csv)** que es un archivo plano de texto separado por comas siguiendo el estándar RFC 4180.
- **¿Qué soluciona?** Antes se corría el riesgo de llenar el servicio de reportes con condicionales `if (formato == XLSX) { ... } else if (formato == CSV) { ... }`, acoplando la lógica de negocio a librerías técnicas externas. Con Abstract Factory, la interfaz `PaiReportFactory` define cómo crear la tríada coherente de productos: `headerBuilder()` (para el título y columnas), `rowWriter()` (para vaciar cada paciente y dosis) y `exporter()` (para empaquetar los bytes finales). Si es Excel, `XlsxPaiReportFactory` crea los 3 productos sobre el mismo libro de cálculo (`Workbook`); si es CSV, `CsvPaiReportFactory` crea los 3 productos sobre el mismo buffer de texto (`StringBuilder`). El servicio de negocio solo conoce las abstracciones, cumpliendo con OCP: agregar un formato PDF en el futuro solo requiere una nueva fábrica y sus productos, sin tocar una sola línea de código existente.

---

## 3.2. Cuadro de clases del patrón Abstract Factory

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`PaiReportFactory`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/PaiReportFactory.java) | **AbstractFactory (Fábrica Abstracta)** | Define los métodos para fabricar la familia de 3 productos de reporte: encabezado, filas y exportador binario. | Desacopla la lógica de exportación de los formatos concretos de archivo. |
| [`ReportHeaderBuilder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportHeaderBuilder.java) | **AbstractProduct A (Producto Abstracto)** | Contrato para construir el encabezado con los títulos de las columnas del reporte. | Estandariza la escritura de encabezados sin importar el formato de salida. |
| [`ReportRowWriter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportRowWriter.java) | **AbstractProduct B (Producto Abstracto)** | Contrato para plasmar una fila de datos clínicos de vacunación en el documento. | Permite escribir registros fila por fila sin saber si son celdas de Excel o líneas de texto. |
| [`ReportExporter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportExporter.java) | **AbstractProduct C (Producto Abstracto)** | Contrato para finalizar la construcción y entregar el arreglo de bytes (`byte[]`) del archivo listo para descargar. | Oculta la complejidad de serialización binaria o codificación de caracteres. |
| [`ReportFormat`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportFormat.java) | **Configuración / Enumeración** | Define los formatos soportados (`XLSX`, `CSV`), su tipo MIME HTTP y su extensión de archivo. | Valida parámetros de la URL y evita valores mágicos en el sistema. |
| [`ReportFactoryProvider`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportFactoryProvider.java) | **Selector de Fábrica / Client Helper** | Componente Spring que entrega una instancia nueva de la fábrica según el formato pedido. | Garantiza que cada exportación tenga su propio buffer en memoria y no mezcle datos entre usuarios. |
| [`XlsxPaiReportFactory`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxPaiReportFactory.java) | **ConcreteFactory (Fábrica Concreta XLSX)** | Fabrica la familia de objetos especializada en hojas de cálculo Microsoft Excel. | Garantiza que los 3 componentes de Excel escriban sobre el mismo libro (`XlsxReportSurface`). |
| [`XlsxReportSurface`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportSurface.java) | **Shared Sink (Soporte Interno)** | Encapsula el libro Apache POI (`XSSFWorkbook`), hoja, estilos en negrita y cursor de filas. | Evita exponer las librerías complejas de POI al resto del sistema. |
| [`XlsxReportHeaderBuilder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportHeaderBuilder.java) | **ConcreteProduct A (Encabezado XLSX)** | Escribe los títulos en la fila 0 del Excel aplicando estilo en negrita. | Maneja la creación física de celdas de título en la hoja de cálculo. |
| [`XlsxReportRowWriter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportRowWriter.java) | **ConcreteProduct B (Fila XLSX)** | Escribe una fila de datos en la siguiente posición libre de la hoja de cálculo. | Traduce listas de strings en celdas de POI manejando valores nulos. |
| [`XlsxReportExporter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportExporter.java) | **ConcreteProduct C (Exportador XLSX)** | Convierte el libro POI en memoria a un flujo de bytes descargable. | Cierra los streams y previene fugas de memoria en el servidor. |
| [`CsvPaiReportFactory`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvPaiReportFactory.java) | **ConcreteFactory (Fábrica Concreta CSV)** | Fabrica la familia de objetos especializada en texto plano delimitado por comas. | Asegura que los componentes de CSV compartan el mismo `StringBuilder`. |
| [`CsvEncoder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvEncoder.java) | **Helper de Formato (RFC 4180)** | Escapa comillas dobles y envuelve valores con comas o saltos de línea. | Evita que el archivo CSV se rompa o se desalinee si un paciente tiene una coma en su dirección. |
| [`CsvReportHeaderBuilder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportHeaderBuilder.java) | **ConcreteProduct A (Encabezado CSV)** | Une los títulos con comas y agrega el salto de línea `\r\n`. | Escribe la primera línea del archivo plano. |
| [`CsvReportRowWriter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportRowWriter.java) | **ConcreteProduct B (Fila CSV)** | Codifica y concatena los datos de la dosis en una línea de texto. | Agrega cada registro de vacunación al buffer de texto. |
| [`CsvReportExporter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportExporter.java) | **ConcreteProduct C (Exportador CSV)** | Convierte el texto acumulado a un arreglo de bytes en formato UTF-8. | Garantiza la correcta visualización de tildes y caracteres en español. |

### Clases preexistentes que se conectan con el patrón:
- [`RegistroDiarioExportService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/service/RegistroDiarioExportService.java): Es el **Client**. Solicita una fábrica a `ReportFactoryProvider`, escribe el encabezado con `headerBuilder()`, recorre la base de datos escribiendo registros con `rowWriter()` y obtiene los bytes con `exporter()`, sin conocer ninguna clase de Excel o CSV.
- [`ReportController`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/controller/ReportController.java): Endpoint HTTP REST que recibe el parámetro `?format=xlsx` o `?format=csv` y entrega el archivo al navegador.

---

## 3.3. Detalle clase por clase

### 1. Interfaz: [`PaiReportFactory.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/PaiReportFactory.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/PaiReportFactory.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

/**
 * AbstractFactory del patron: crea la familia de productos de salida de un
 * reporte —encabezado, filas y exportador— para un formato concreto. Las
 * fabricas concretas ({@code XlsxPaiReportFactory}, {@code CsvPaiReportFactory})
 * comparten un mismo buffer de salida entre los tres productos.
 */
public interface PaiReportFactory {

  ReportHeaderBuilder headerBuilder();

  ReportRowWriter rowWriter();

  ReportExporter exporter();
}
```

#### Explicación minuciosa a nivel de código:
- Declara los tres métodos de fábrica (Factory Methods) obligatorios que cualquier familia de exportación debe implementar: uno para el constructor de cabecera (`headerBuilder()`), uno para escribir filas (`rowWriter()`) y uno para generar el binario descargable (`exporter()`).

---

### 2. Interfaz: [`ReportHeaderBuilder.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportHeaderBuilder.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/ReportHeaderBuilder.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

import java.util.List;

/** AbstractProduct: escribe el encabezado del reporte (especifico del formato). */
public interface ReportHeaderBuilder {

  void writeHeader(List<String> titles);
}
```

#### Explicación minuciosa a nivel de código:
- Define el contrato para el producto de encabezado: recibe una lista de textos (`List<String> titles`) que representan los nombres oficiales de las columnas del PAI y las plasma en la primera sección del archivo.

---

### 3. Interfaz: [`ReportRowWriter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportRowWriter.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/ReportRowWriter.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

import java.util.List;

/** AbstractProduct: escribe una fila del reporte (especifico del formato). */
public interface ReportRowWriter {

  void writeRow(List<String> cells);
}
```

#### Explicación minuciosa a nivel de código:
- Define el método `writeRow(List<String> cells)`: recibe los valores de una fila (identificación del paciente, vacuna, lote, fecha, dosis) y los agrega al cuerpo del reporte.

---

### 4. Interfaz: [`ReportExporter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportExporter.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/ReportExporter.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

/** AbstractProduct: serializa el reporte a bytes (especifico del formato). */
public interface ReportExporter {

  byte[] export();
}
```

#### Explicación minuciosa a nivel de código:
- Define `byte[] export()`: no recibe parámetros porque el documento ya fue llenado previamente. Simplemente empaqueta todo el contenido y lo devuelve como una secuencia de bytes lista para ser enviada por internet como archivo descargable.

---

### 5. Enumeración: [`ReportFormat.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportFormat.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/ReportFormat.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

/**
 * Formatos de salida soportados por el exportador de reportes PAI. Cada valor
 * aporta su content-type HTTP y la extension del archivo generado.
 */
public enum ReportFormat {
  XLSX("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", "xlsx"),
  CSV("text/csv; charset=UTF-8", "csv");

  private final String contentType;
  private final String extension;

  ReportFormat(String contentType, String extension) {
    this.contentType = contentType;
    this.extension = extension;
  }

  public String contentType() {
    return contentType;
  }

  public String extension() {
    return extension;
  }

  /** Convierte el parametro de request (p. ej. "xlsx"/"csv") al enum. */
  public static ReportFormat from(String value) {
    if (value == null || value.isBlank()) {
      return XLSX;
    }
    try {
      return ReportFormat.valueOf(value.trim().toUpperCase());
    } catch (IllegalArgumentException ex) {
      throw new IllegalArgumentException("Formato no soportado: " + value + ". Usa xlsx o csv.");
    }
  }
}
```

#### Explicación minuciosa a nivel de código:
- **Constantes del enum [L8-L9]:** Define los dos tipos válidos con sus propiedades HTTP oficiales (cabecera `Content-Type` para que el navegador reconozca el archivo y extensión del archivo).
- **Método de fábrica seguro `from(String value)` [L28-L37]:** Convierte de manera tolerante a mayúsculas/minúsculas la palabra enviada por el usuario (por ejemplo `"csv "` a `ReportFormat.CSV`). Si viene vacío, por defecto asume `XLSX`. Si escriben algo inválido como `"pdf"`, lanza una excepción amigable avisando las opciones soportadas.

---

### 6. Proveedor de Fábricas: [`ReportFactoryProvider.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/ReportFactoryProvider.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/ReportFactoryProvider.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export;

import com.pai.api.reports.export.csv.CsvPaiReportFactory;
import com.pai.api.reports.export.xlsx.XlsxPaiReportFactory;
import java.util.Map;
import java.util.function.Supplier;
import org.springframework.stereotype.Component;

/**
 * Selecciona la {@link PaiReportFactory} concreta segun el formato pedido.
 *
 * <p>Crea una fabrica nueva por exportacion: las fabricas concretas mantienen el
 * buffer de salida (workbook de POI o StringBuilder de CSV) y no deben
 * compartirse entre peticiones.
 */
@Component
public class ReportFactoryProvider {

  private final Map<ReportFormat, Supplier<PaiReportFactory>> factories =
      Map.of(
          ReportFormat.XLSX, XlsxPaiReportFactory::new,
          ReportFormat.CSV, CsvPaiReportFactory::new);

  public PaiReportFactory create(ReportFormat format) {
    Supplier<PaiReportFactory> factory = factories.get(format);
    if (factory == null) {
      throw new IllegalArgumentException("Formato no soportado: " + format);
    }
    return factory.get();
  }
}
```

#### Explicación minuciosa a nivel de código:
- `@Component` [L16]: Spring se encarga de crear este proveedor como un Singleton.
- `Map<ReportFormat, Supplier<PaiReportFactory>> factories` [L19-L22]: Registra una asociación entre cada formato y su constructor (`XlsxPaiReportFactory::new`). El uso de `Supplier` (proveedor perezoso) es vital: **no crea la fábrica de antemano**, sino que cada vez que alguien llama a `create(format)`, ejecuta `factory.get()` fabricando una instancia 100% limpia y nueva, evitando que las descargas de dos médicos simultáneos se mezclen en memoria.

---

### 7. Fábrica Concreta XLSX: [`XlsxPaiReportFactory.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxPaiReportFactory.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxPaiReportFactory.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportExporter;
import com.pai.api.reports.export.ReportHeaderBuilder;
import com.pai.api.reports.export.ReportRowWriter;

/**
 * ConcreteFactory: familia de productos XLSX (Office Open XML). Los tres
 * productos comparten el mismo {@link XlsxReportSurface} (workbook + hoja).
 */
public final class XlsxPaiReportFactory implements PaiReportFactory {

  private final XlsxReportSurface surface = new XlsxReportSurface();

  @Override
  public ReportHeaderBuilder headerBuilder() {
    return new XlsxReportHeaderBuilder(surface);
  }

  @Override
  public ReportRowWriter rowWriter() {
    return new XlsxReportRowWriter(surface);
  }

  @Override
  public ReportExporter exporter() {
    return new XlsxReportExporter(surface);
  }
}
```

#### Explicación minuciosa a nivel de código:
- Crea una única variable interna `surface = new XlsxReportSurface()` [L14]. Esta es la clave del patrón: cuando el cliente pide el constructor de cabecera (`headerBuilder()`), el de filas (`rowWriter()`) o el exportador (`exporter()`), la fábrica instancia cada producto pasándole **la misma superficie (`surface`)**. Así, los tres objetos escriben en el mismo archivo Excel sin estorbarse.

---

### 8. Superficie de Soporte XLSX: [`XlsxReportSurface.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportSurface.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportSurface.java`

#### Código fuente completo:
```java
package com.pai.api.reports.export.xlsx;

import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.List;
import org.apache.poi.ss.usermodel.Cell;
import org.apache.poi.ss.usermodel.CellStyle;
import org.apache.poi.ss.usermodel.Font;
import org.apache.poi.ss.usermodel.Row;
import org.apache.poi.ss.usermodel.Sheet;
import org.apache.poi.ss.usermodel.Workbook;
import org.apache.poi.xssf.usermodel.XSSFWorkbook;

/**
 * Sink compartido de la familia XLSX: workbook + hoja + estilo de encabezado +
 * cursor de fila. Los tres productos concretos escriben sobre esta misma
 * superficie.
 */
final class XlsxReportSurface {

  private static final String SHEET_NAME = "Registro Diario";

  private final Workbook workbook = new XSSFWorkbook();
  private final Sheet sheet = workbook.createSheet(SHEET_NAME);
  private final CellStyle headerStyle;
  private int rowCursor = 0;

  XlsxReportSurface() {
    this.headerStyle = workbook.createCellStyle();
    Font font = workbook.createFont();
    font.setBold(true);
    headerStyle.setFont(font);
  }

  void writeHeaderRow(List<String> titles) {
    Row row = sheet.createRow(rowCursor++);
    for (int column = 0; column < titles.size(); column++) {
      Cell cell = row.createCell(column);
      cell.setCellValue(titles.get(column));
      cell.setCellStyle(headerStyle);
    }
  }

  void writeDataRow(List<String> cells) {
    Row row = sheet.createRow(rowCursor++);
    for (int column = 0; column < cells.size(); column++) {
      Cell cell = row.createCell(column);
      String value = cells.get(column);
      cell.setCellValue(value == null ? "" : value);
    }
  }

  byte[] toBytes() {
    try (ByteArrayOutputStream out = new ByteArrayOutputStream();
        Workbook wb = this.workbook) {
      wb.write(out);
      return out.toByteArray();
    } catch (IOException ex) {
      throw new IllegalStateException("No se pudo generar el archivo XLSX.", ex);
    }
  }
}
```

#### Explicación minuciosa a nivel de código:
- Inicializa un libro en blanco moderno (`new XSSFWorkbook()`) y una pestaña llamada "Registro Diario" [L23-L24].
- Crea un estilo de fuente en negrita (`font.setBold(true)`) para que las cabeceras resalten visualmente [L30-L32].
- Lleva un contador llamado `rowCursor` [L26]: cada vez que se escribe una fila (sea cabecera o dato), incrementa el cursor (`rowCursor++`), asegurando que cada nueva dosis se escriba debajo de la anterior sin sobreescribir celdas.
- `toBytes()` [L53-L61]: Transforma el libro binario de Apache POI en un flujo de bytes en memoria (`ByteArrayOutputStream`) y lo cierra limpiamente mediante un bloque `try-with-resources`.

---

### 9. Productos Concretos XLSX: [`XlsxReportHeaderBuilder.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportHeaderBuilder.java), [`XlsxReportRowWriter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportRowWriter.java), [`XlsxReportExporter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/xlsx/XlsxReportExporter.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/xlsx/`

#### Código fuente completo (Header, Row y Exporter):
```java
// XlsxReportHeaderBuilder.java
package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportHeaderBuilder;
import java.util.List;

final class XlsxReportHeaderBuilder implements ReportHeaderBuilder {
  private final XlsxReportSurface surface;

  XlsxReportHeaderBuilder(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public void writeHeader(List<String> titles) {
    surface.writeHeaderRow(titles);
  }
}
```

```java
// XlsxReportRowWriter.java
package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportRowWriter;
import java.util.List;

final class XlsxReportRowWriter implements ReportRowWriter {
  private final XlsxReportSurface surface;

  XlsxReportRowWriter(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public void writeRow(List<String> cells) {
    surface.writeDataRow(cells);
  }
}
```

```java
// XlsxReportExporter.java
package com.pai.api.reports.export.xlsx;

import com.pai.api.reports.export.ReportExporter;

final class XlsxReportExporter implements ReportExporter {
  private final XlsxReportSurface surface;

  XlsxReportExporter(XlsxReportSurface surface) {
    this.surface = surface;
  }

  @Override
  public byte[] export() {
    return surface.toBytes();
  }
}
```

#### Explicación minuciosa a nivel de código:
- Cada clase implementa su interfaz correspondiente (`ReportHeaderBuilder`, `ReportRowWriter`, `ReportExporter`).
- Tienen visibilidad de paquete (`final class`, sin `public`), lo que significa que están protegidas: nadie fuera del paquete `xlsx` puede verlas ni instanciarlas directamente. La única forma de usarlas es a través de la fábrica abstracta.

---

### 10. Fábrica Concreta CSV y Productos: [`CsvPaiReportFactory.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvPaiReportFactory.java), [`CsvEncoder.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvEncoder.java), [`CsvReportHeaderBuilder.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportHeaderBuilder.java), [`CsvReportRowWriter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportRowWriter.java), [`CsvReportExporter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/reports/export/csv/CsvReportExporter.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/reports/export/csv/`

#### Código fuente completo de la familia CSV:
```java
// CsvPaiReportFactory.java
package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.PaiReportFactory;
import com.pai.api.reports.export.ReportExporter;
import com.pai.api.reports.export.ReportHeaderBuilder;
import com.pai.api.reports.export.ReportRowWriter;

public final class CsvPaiReportFactory implements PaiReportFactory {
  private final StringBuilder out = new StringBuilder();

  @Override
  public ReportHeaderBuilder headerBuilder() {
    return new CsvReportHeaderBuilder(out);
  }

  @Override
  public ReportRowWriter rowWriter() {
    return new CsvReportRowWriter(out);
  }

  @Override
  public ReportExporter exporter() {
    return new CsvReportExporter(out);
  }
}
```

```java
// CsvEncoder.java
package com.pai.api.reports.export.csv;

final class CsvEncoder {
  private CsvEncoder() {}

  static String field(String value) {
    if (value == null) {
      return "";
    }
    boolean needsQuotes =
        value.indexOf(',') >= 0
            || value.indexOf('"') >= 0
            || value.indexOf('\n') >= 0
            || value.indexOf('\r') >= 0;
    if (!needsQuotes) {
      return value;
    }
    return "\"" + value.replace("\"", "\"\"") + "\"";
  }
}
```

```java
// CsvReportHeaderBuilder.java
package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportHeaderBuilder;
import java.util.List;
import java.util.stream.Collectors;

final class CsvReportHeaderBuilder implements ReportHeaderBuilder {
  private static final String LINE_SEPARATOR = "\r\n";
  private final StringBuilder out;

  CsvReportHeaderBuilder(StringBuilder out) {
    this.out = out;
  }

  @Override
  public void writeHeader(List<String> titles) {
    out.append(titles.stream().map(CsvEncoder::field).collect(Collectors.joining(",")))
        .append(LINE_SEPARATOR);
  }
}
```

```java
// CsvReportRowWriter.java
package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportRowWriter;
import java.util.List;
import java.util.stream.Collectors;

final class CsvReportRowWriter implements ReportRowWriter {
  private static final String LINE_SEPARATOR = "\r\n";
  private final StringBuilder out;

  CsvReportRowWriter(StringBuilder out) {
    this.out = out;
  }

  @Override
  public void writeRow(List<String> cells) {
    out.append(cells.stream().map(CsvEncoder::field).collect(Collectors.joining(",")))
        .append(LINE_SEPARATOR);
  }
}
```

```java
// CsvReportExporter.java
package com.pai.api.reports.export.csv;

import com.pai.api.reports.export.ReportExporter;
import java.nio.charset.StandardCharsets;

final class CsvReportExporter implements ReportExporter {
  private final StringBuilder out;

  CsvReportExporter(StringBuilder out) {
    this.out = out;
  }

  @Override
  public byte[] export() {
    return out.toString().getBytes(StandardCharsets.UTF_8);
  }
}
```

#### Explicación minuciosa a nivel de código:
- En lugar de un libro de Excel, la familia CSV comparte un `StringBuilder out` (un acumulador de texto en memoria eficiente).
- **`CsvEncoder`:** Es un sanitizador de texto esencial. Si el nombre de un paciente o la observación contiene una coma (ejemplo: `"Lote 1, frasco 2"`), un CSV normal creería que la coma divide otra columna y rompería la estructura. `CsvEncoder` detecta comas o saltos de línea y envuelve el texto entre comillas dobles (`"Lote 1, frasco 2"`), escapando comillas internas según el estándar RFC 4180.
- **`CsvReportExporter`:** Llama a `.getBytes(StandardCharsets.UTF_8)` asegurando que las letras con tildes, la letra 'ñ' y caracteres latinos no salgan ilegibles ni con símbolos extraños al abrirse en computadores con Windows o Mac.

---

# 4. Patrón Factory Method (Creacional)

## 4.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina una empresa de encomiendas que recibe paquetes en su ventanilla. La recepcionista no sabe si el paquete viajará en moto, en furgón o en avión. Ella solo sabe que el paquete tiene un código que dice "URGENTE_AEREO". La recepcionista busca en su catálogo al encargado de esa categoría y le dice: "Aquí tienes, procesa este paquete". El encargado de envíos aéreos sabe exactamente qué avión usar y qué trámites hacer, sin que la recepcionista tenga que saber pilotar un avión ni conducir una moto.
El patrón **Factory Method** define una forma general de pedir un objeto o una acción, pero deja que una clase especialista decida exactamente qué objeto concreto crear y cómo atenderlo.

### En términos técnicos y en el proyecto:
Define una interfaz para crear un objeto, pero deja que las clases que la implementan decidan qué clase concreta instanciar.
- **¿Por qué lo hicimos y dónde existe?**
  1. **En exportación de reportes:** Cada método de la interfaz `PaiReportFactory` (`headerBuilder()`, `rowWriter()`, `exporter()`) es formalmente un Factory Method que deja la decisión del producto concreto en manos de `XlsxPaiReportFactory` o `CsvPaiReportFactory`.
  2. **En sincronización móvil (Offline-First):** Cuando la aplicación móvil de las brigadas de vacunación no tiene internet en zonas rurales, guarda las acciones en la tablet. Al recuperar señal, envía un lote de comandos a `/api/v1/sync/push`. Antes del patrón, procesar estos comandos hubiera requerido un gigantesco `switch (commandType)` con 20 `case` dentro del servicio `SyncPushService`. Cada nuevo comando obligaba a editar y arriesgar el servicio central.
- **¿Qué soluciona?** Desacopla la selección y despacho de comandos. Cada tipo de acción se aísla en su propio handler que implementa `SyncCommandHandler` (ej. `CreatePatientCommandHandler`). `SyncPushService` recopila automáticamente todos los handlers registrados en Spring en un `Map<String, SyncCommandHandler>` y los ejecuta por su clave (`commandType()`). Si se agrega un nuevo comando en el futuro, solo se crea una clase nueva, cumpliendo el principio Open/Closed (OCP).

---

## 4.2. Cuadro de clases del patrón Factory Method (Sincronización)

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`SyncCommandHandler`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/synchronization/service/command/SyncCommandHandler.java) | **Creator / Product Interface** | Contrato que define el identificador del comando (`commandType`), el permiso requerido y el método `apply(...)` para ejecutarlo. | Estandariza la ejecución polimórfica de cualquier comando offline que llegue desde los dispositivos móviles. |
| [`CreatePatientCommandHandler`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/synchronization/service/command/CreatePatientCommandHandler.java) | **ConcreteCreator / ConcreteHandler** | Procesa el comando específico de creación de pacientes proveniente de la sincronización móvil. | Convierte el payload JSON en un DTO válido y delega la lógica en `PatientService` de forma aislada. |

### Clases preexistentes que se conectan con el patrón:
- [`SyncPushService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/synchronization/service/SyncPushService.java): Es el despachador central. Inyecta una lista de `SyncCommandHandler`, construye un mapa indexado por `commandType` y ejecuta `handlers.get(operation.commandType()).apply(...)`.
- Otros handlers existentes: `CreateAttentionCommandHandler`, `RegisterDoseCommandHandler`, `CompleteAttentionCommandHandler`.

---

## 4.3. Detalle clase por clase

### Clase: [`SyncCommandHandler.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/synchronization/service/command/SyncCommandHandler.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/synchronization/service/command/SyncCommandHandler.java`

#### Código fuente completo:
```java
package com.pai.api.synchronization.service.command;

import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;

/**
 * Handler de un comando de sincronizacion (Strategy). Cada comando implementa
 * su tipo, el permiso que exige y como aplicarlo en el servicio de dominio.
 *
 * <p>Agregar un comando nuevo es una clase nueva (OCP): {@link
 * com.pai.api.synchronization.service.SyncPushService} no cambia.
 */
public interface SyncCommandHandler {

  /** {@code commandType} del comando que atiende. */
  String commandType();

  /** Permiso requerido, o {@code null} si el comando no exige permiso. */
  String permission();

  /** Aplica el comando. Las excepciones de dominio las clasifica el orquestador. */
  void apply(UUID actorId, String operationId, SyncOperation operation);
}
```

#### Explicación minuciosa a nivel de código:
1. `commandType()` [L16]: Devuelve la cadena que identifica al comando (por ejemplo `"CREATE_PATIENT"`). Se usa como clave única para registrar y buscar el handler en el mapa de despacho.
2. `permission()` [L19]: Declara qué privilegio de seguridad necesita el enfermero o brigadista para ejecutarlo (por ejemplo `"PATIENT_WRITE"`). Si devuelve `null`, el comando es de acceso libre.
3. `apply(...)` [L22]: Recibe el identificador del usuario (`actorId`), el identificador de la operación para control de duplicados (`operationId`) y el objeto con los datos crudos (`operation`).

---

### Clase: [`CreatePatientCommandHandler.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/synchronization/service/command/CreatePatientCommandHandler.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/synchronization/service/command/CreatePatientCommandHandler.java`

#### Código fuente completo:
```java
package com.pai.api.synchronization.service.command;

import com.pai.api.patients.dto.CreatePatientRequest;
import com.pai.api.patients.service.PatientService;
import com.pai.api.synchronization.dto.SyncOperation;
import java.util.UUID;
import org.springframework.stereotype.Component;

/** Aplica {@code CREATE_PATIENT} delegando en {@link PatientService}. */
@Component
public class CreatePatientCommandHandler implements SyncCommandHandler {

  public static final String COMMAND = "CREATE_PATIENT";

  private final PatientService patients;
  private final SyncPayloadConverter payload;

  public CreatePatientCommandHandler(PatientService patients, SyncPayloadConverter payload) {
    this.patients = patients;
    this.payload = payload;
  }

  @Override
  public String commandType() {
    return COMMAND;
  }

  @Override
  public String permission() {
    return "PATIENT_WRITE";
  }

  @Override
  public void apply(UUID actorId, String operationId, SyncOperation operation) {
    patients.create(
        actorId,
        operationId,
        operation.aggregateId(),
        payload.convert(operation, CreatePatientRequest.class));
  }
}
```

#### Explicación minuciosa a nivel de código:
1. `@Component` [L10]: Anotación que le indica a Spring: "Crea automáticamente una instancia de esta clase al iniciar el servidor y tenla lista para inyectarla donde se necesite".
2. `public static final String COMMAND = "CREATE_PATIENT"` [L13]: Define una constante inmutable que sirve como firma oficial del comando.
3. **Inyección por constructor [L18-L21]:** Recibe `PatientService` (el servicio de base de datos de pacientes) y `SyncPayloadConverter` (el traductor de JSON a objetos Java).
4. `apply(...)` [L34-L40]:
   - Usa `payload.convert(...)` para transformar los datos en formato JSON recibidos del celular en un objeto Java tipado y validado (`CreatePatientRequest`).
   - Invoca `patients.create(...)` para guardar al paciente en PostgreSQL respetando el `aggregateId` y el `operationId` para evitar duplicar pacientes si la red falla y la app móvil reintenta el envío.

---

# 5. Patrón Singleton (Creacional)

## 5.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina un edificio de oficinas con 100 empleados. En lugar de comprarle una fotocopiadora personal gigante a cada uno de los 100 empleados para que la tengan sobre su escritorio (lo que costaría una fortuna y gastaría espacio innecesario), la empresa coloca una única fotocopiadora central en el pasillo, y todos los empleados comparten esa misma máquina cuando necesitan imprimir.
El patrón **Singleton** garantiza que en todo el programa exista una única instancia de una clase y que todas las demás partes del sistema utilicen siempre esa misma instancia compartida.

### En términos técnicos y en el proyecto:
Garantiza que una clase tenga **una única instancia** en la memoria del proceso y ofrece un punto de acceso global a ella.
- **¿Cómo se aplica en Tu Vacuna PAI?** En el backend de Tu Vacuna PAI **no escribimos ningún Singleton tradicional a mano con `private static Instance` y `getInstance()`**. ¿Por qué? Porque el Singleton clásico crea un estado global invisible y fuertemente acoplado que hace imposible realizar pruebas unitarias con dobles de prueba (mocks). En su lugar, el patrón lo gestiona de forma nativa el **contenedor de Inversión de Control (IoC) de Spring Boot**. Por defecto, en Spring, cada clase anotada con `@Service`, `@Component`, `@Repository` o `@Configuration` es gestionada como un **Singleton** dentro del contexto de la aplicación.
- **¿Qué soluciona?** Garantiza que los servicios no consuman memoria innecesaria creando objetos repetidos para cada petición web entrante. Al ser servicios **sin estado (stateless)** que solo contienen referencias a repositorios inmutables (`final`), son totalmente seguros frente a accesos concurrentes de cientos de usuarios a la vez (thread-safe) y permiten la inyección de dependencias por constructor limpia.

---

## 5.2. Cuadro de clases del patrón Singleton

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`SecurityConfig`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/shared/security/SecurityConfig.java) | **Singleton Configuration / Provider** | Clase de configuración que declara el bean singleton de la cadena de filtros de seguridad HTTP (`SecurityFilterChain`). | Centraliza en una única instancia compartida las reglas de autenticación JWT y CORS para todas las peticiones web. |
| [`CatalogSelectionService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/CatalogSelectionService.java) | **Singleton Service (`@Service`)** | Servicio sin estado que resuelve la selección efectiva de opciones de vacunas para las instituciones. | Evita crear instancias repetidas en cada consulta de catálogo, ahorrando memoria y tiempo de CPU. |

---

## 5.3. Detalle clase por clase

### Clase: [`SecurityConfig.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/shared/security/SecurityConfig.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/shared/security/SecurityConfig.java`

#### Código fuente completo:
```java
package com.pai.api.shared.security;

import com.pai.api.identity.service.ActiveUserAuthenticationConverter;
import com.pai.api.shared.exceptions.ErrorResponse;
import com.pai.api.shared.json.JsonSerializer;
import jakarta.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.HttpStatusEntryPoint;

@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

  private final JwtDecoder jwtDecoder;
  private final ActiveUserAuthenticationConverter authenticationConverter;
  private final JsonSerializer json;

  public SecurityConfig(
      JwtDecoder jwtDecoder,
      ActiveUserAuthenticationConverter authenticationConverter,
      JsonSerializer json) {
    this.jwtDecoder = jwtDecoder;
    this.authenticationConverter = authenticationConverter;
    this.json = json;
  }

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    http.csrf(csrf -> csrf.disable())
        .sessionManagement(
            session -> session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
        .oauth2ResourceServer(oauth2 -> oauth2
            .jwt(jwt -> jwt.decoder(jwtDecoder).jwtAuthenticationConverter(authenticationConverter))
            .authenticationEntryPoint(new HttpStatusEntryPoint(HttpStatus.UNAUTHORIZED)))
        .exceptionHandling(exceptions -> exceptions
            .authenticationEntryPoint((request, response, authException) -> write(
                response,
                HttpStatus.UNAUTHORIZED,
                errorBody(
                    "UNAUTHORIZED",
                    authException.getMessage() == null
                            || authException.getMessage().isBlank()
                        ? "Token de acceso invalido o ausente."
                        : authException.getMessage())))
            .accessDeniedHandler((request, response, accessDeniedException) -> write(
                response,
                HttpStatus.FORBIDDEN,
                errorBody("FORBIDDEN", "No tienes permisos para acceder a este recurso."))))
        .authorizeHttpRequests(auth -> auth
            .requestMatchers(HttpMethod.OPTIONS, "/**").permitAll()
            .requestMatchers("/api/v1/health", "/api/v1/health/**").permitAll()
            .requestMatchers("/api/v1/sync/pull").hasAuthority("SYNC_READ")
            .requestMatchers("/api/v1/sync/push").hasAuthority("SYNC_WRITE")
            .anyRequest().authenticated());
    return http.build();
  }

  private void write(HttpServletResponse response, HttpStatus status, ErrorResponse body)
      throws IOException {
    response.setStatus(status.value());
    response.setContentType(MediaType.APPLICATION_JSON_VALUE);
    response.setCharacterEncoding(StandardCharsets.UTF_8.name());
    response.getWriter().write(json.writeOrEmpty(body));
  }

  private ErrorResponse errorBody(String code, String message) {
    return new ErrorResponse(code, message, null);
  }
}
```

#### Explicación minuciosa a nivel de código:
1. `@Configuration` [L22]: Informa a Spring que esta clase contiene definiciones de infraestructura que deben cargarse al arrancar el servidor.
2. Inyección de dependencias `final` [L27-L38]: Todas sus dependencias (`jwtDecoder`, `authenticationConverter`, `json`) son `final`, lo que garantiza que después de construida la clase, nada pueda alterar sus referencias internas.
3. `@Bean public SecurityFilterChain securityFilterChain(...)` [L40-L72]:
   - `@Bean`: Hace que el objeto retornado por `http.build()` sea administrado por Spring como un Singleton en el contenedor.
   - Configura la seguridad en modo `STATELESS` (sin sesiones de servidor tradicionales, basado exclusivamente en tokens JWT de Supabase).
   - Define las rutas públicas (`/api/v1/health`) y las que exigen permisos estrictos (`/api/v1/sync/push` con `SYNC_WRITE`).
   - Todos los hilos y peticiones HTTP concurrentes que llegan a la API atraviesan esta misma y única cadena de filtros de seguridad.

---

# 6. Patrón Proxy / Protection Proxy (Estructural)

## 6.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina un club exclusivo o un archivo confidencial. Tú no puedes entrar directamente a la bodega a revisar o sacar documentos; en la puerta hay un **guardia de seguridad (el portero)**. Cuando llegas y pides un documento, tú interactúas con el guardia como si fuera el encargado del archivo. El guardia te pide tu carnet y revisa si tienes permiso. Si no estás autorizado, te frena en seco en la entrada y no te deja dar un solo paso más. Solo si tu carnet es válido, el guardia se da la vuelta, va a la bodega real, saca el documento y te lo entrega.
El patrón **Proxy (Proxy de Protección)** coloca un sustituto o intermediario delante de un objeto real para controlar y validar quién tiene derecho a usarlo.

### En términos técnicos y en el proyecto:
Proporciona un sustituto o intermediario de otro objeto para controlar el acceso al mismo.
- **¿Por qué lo hicimos?** Antes de aplicar el patrón, `VaccineService` era una clase concreta monolítica. Cada uno de sus métodos mezclaba la lógica pura de vacunación (consultar tablas, crear lotes, calcular dosis) con verificaciones manuales de seguridad (`guard.require(...)`). Esto violaba el Principio de Responsabilidad Única (SRP) y el de Inversión de Dependencias (DIP), acoplando el controlador REST a una implementación concreta. Además, si el usuario no tenía permisos, muchas veces ya se habían abierto conexiones de base de datos o transacciones innecesarias antes de rechazarlo.
- **¿Qué soluciona?** Separamos el servicio en tres piezas limpias:
  1. `VaccineService` se convirtió en una **interfaz pura (Subject)**.
  2. `DefaultVaccineService` se convirtió en el **Sujeto Real (RealSubject)**, encargado exclusivamente de la lógica médica y persistencia en base de datos sin saber nada de seguridad.
  3. `VaccineSecurityProxy` se creó como el **Protection Proxy con `@Primary`**: intercepta cada llamada, invoca a `PermissionGuard` para verificar si el actor tiene `CATALOG_GLOBAL_READ` o `CATALOG_GLOBAL_WRITE`, y si no tiene permisos, lanza una excepción cortocircuitando la petición de inmediato sin que la base de datos se entere ni gaste recursos.

---

## 6.2. Cuadro de clases del patrón Proxy

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`VaccineService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/VaccineService.java) | **Subject (Sujeto / Interfaz común)** | Define las operaciones públicas de gestión de vacunas y opciones del catálogo nacional. | Permite que los controladores interactúen con el catálogo sin saber si están hablando con el proxy o con el servicio real (DIP). |
| [`VaccineSecurityProxy`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/VaccineSecurityProxy.java) | **Proxy (Protection Proxy / `@Primary`)** | Intercepta cada método, valida los privilegios del actor mediante `PermissionGuard` y delega al servicio real. | Frena accesos no autorizados antes de tocar la base de datos y separa completamente la seguridad de la lógica clínica (SRP). |
| [`DefaultVaccineService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/DefaultVaccineService.java) | **RealSubject (Sujeto Real)** | Implementación con lógica pura de negocio, control de concurrencia optimista (`@Version`) y persistencia JPA. | Queda 100% limpia de código de seguridad, facilitando su mantenimiento y pruebas unitarias aisladas. |

### Clases preexistentes que se conectan con el patrón:
- [`CatalogController`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/controller/CatalogController.java): Es el **Client**. Inyecta `VaccineService` y, gracias a la anotación `@Primary` del Proxy, Spring le entrega automáticamente el proxy de seguridad sin que el controlador sospeche nada.
- [`PermissionGuard`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/shared/security/PermissionGuard.java): Colaborador de seguridad que comprueba si el usuario autenticado tiene el rol necesario.

---

## 6.3. Detalle clase por clase

### 1. Interfaz: [`VaccineService.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/VaccineService.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/catalog/service/VaccineService.java`

#### Código fuente completo:
```java
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
```

#### Explicación minuciosa a nivel de código:
- Contiene la firma de todos los métodos que el sistema ofrece para interactuar con el catálogo de vacunas: listar vacunas, crear, actualizar, borrar y administrar las opciones operativas y plantillas. Ambos, tanto el guardia (`VaccineSecurityProxy`) como el ejecutor real (`DefaultVaccineService`), firman este mismo contrato.

---

### 2. Clase Proxy: [`VaccineSecurityProxy.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/VaccineSecurityProxy.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/catalog/service/VaccineSecurityProxy.java`

#### Código fuente completo:
```java
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
```

#### Explicación minuciosa a nivel de código:
1. `@Primary` [L27]: Es una instrucción crucial para Spring. Como ahora existen **dos** clases que implementan `VaccineService` (`VaccineSecurityProxy` y `DefaultVaccineService`), `@Primary` le dice a Spring: *"Siempre que alguien pida inyectar un `VaccineService`, dale por defecto este Proxy"*.
2. Constructor e inyección con `@Qualifier` [L33-L38]:
   - `@Qualifier("defaultVaccineService")`: Le indica con precisión de cirujano al Proxy cuál es el sujeto real que debe esconder tras de sí.
   - Recibe también `PermissionGuard guard` para consultar la autorización de los usuarios.
3. Intercepción y cortocircuito [L41-L44]:
   - En `list(UUID actor)`: Ejecuta primero `guard.require(actor, "CATALOG_GLOBAL_READ")`. Si el usuario carece de ese permiso, `guard` detiene el programa disparando una excepción (`PermissionDeniedException`). La siguiente línea (`return realService.list(actor)`) jamás se ejecuta, protegiendo al sujeto real y a la base de datos de llamadas no autorizadas.
   - En operaciones que alteran datos (`create`, `update`, `delete`) [L48, L54, L60]: Exige estrictamente el permiso de escritura `"CATALOG_GLOBAL_WRITE"`.

---

### 3. Clase Sujeto Real: [`DefaultVaccineService.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/catalog/service/DefaultVaccineService.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/catalog/service/DefaultVaccineService.java`

#### Código fuente representativo:
```java
package com.pai.api.catalog.service;

import com.pai.api.catalog.dto.*;
import com.pai.api.catalog.entity.*;
import com.pai.api.catalog.exception.OptimisticCatalogException;
import com.pai.api.catalog.repository.*;
import java.time.Instant;
import java.util.*;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service("defaultVaccineService")
public class DefaultVaccineService implements VaccineService {

  private final VaccineRepository vaccines;
  private final VaccineOptionRepository options;
  private final VaccineOptionTemplateRepository templates;
  private final CatalogMapper mapper;

  public DefaultVaccineService(
      VaccineRepository v,
      VaccineOptionRepository o,
      VaccineOptionTemplateRepository t,
      CatalogMapper m) {
    this.vaccines = v;
    this.options = o;
    this.templates = t;
    this.mapper = m;
  }

  @Override
  @Transactional(readOnly = true)
  public List<VaccineResponse> list(UUID actor) {
    return vaccines.findByActiveTrueOrderByNameAsc().stream()
        .map(mapper::toVaccine)
        .toList();
  }

  @Override
  @Transactional
  public VaccineResponse create(UUID actor, VaccineRequest r) {
    VaccineEntity x = new VaccineEntity(
        UUID.randomUUID(), r.name(), r.code().trim(), r.category(),
        r.maxDoses(), r.minAgeMonths(), r.maxAgeMonths(), actor, Instant.now());
    return mapper.toVaccine(vaccines.save(x));
  }

  @Override
  @Transactional
  public VaccineResponse update(UUID actor, UUID id, VaccineRequest r, long version) {
    VaccineEntity x = vaccines.findById(id)
        .orElseThrow(() -> new IllegalArgumentException("Vacuna no existe."));
    if (x.getVersion() != version) {
      throw new OptimisticCatalogException("La vacuna fue modificada por otro usuario.");
    }
    x.update(r.name(), r.category(), r.maxDoses(), r.minAgeMonths(), r.maxAgeMonths(), true, actor);
    return mapper.toVaccine(vaccines.save(x));
  }
}
```

#### Explicación minuciosa a nivel de código:
- `@Service("defaultVaccineService")`: Registra el bean con ese nombre específico para que el Proxy pueda llamarlo usando `@Qualifier`.
- No contiene ninguna llamada a `PermissionGuard`. Su único trabajo es gestionar la lógica de negocio, mapear entidades a DTOs y comunicarse con PostgreSQL mediante `VaccineRepository`.

---

# 7. Patrón Decorator (Estructural)

## 7.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina que vas a enviar un paquete por correo que contiene un celular nuevo. El servicio postal estándar solo sabe tomar la caja y llevarla en el camión a su destino. Si de repente te dicen que por ley no se pueden enviar cosas de valor sin una envoltura acolchada con plástico de burbujas, tú no rompes ni rediseñas la caja original del celular; simplemente tomas plástico de burbujas y envuelves la caja. El paquete sigue siendo un paquete de correo por fuera, pero ahora tiene una capa extra que lo protege antes de entregárselo al camión.
El patrón **Decorator (Decorador)** te permite añadirle nuevas responsabilidades o filtros a un objeto de forma dinámica envolviéndolo dentro de otro objeto que habla el mismo idioma (misma interfaz), sin tocar una sola línea del código original.

### En términos técnicos y en el proyecto:
Añade responsabilidades adicionales a un objeto de forma dinámica. Proporciona una alternativa flexible a la herencia para extender la funcionalidad.
- **¿Por qué lo hicimos?** En el sistema médico de Tu Vacuna PAI existe un puerto de auditoría (`AuditRecorder`) que registra cada evento clínico relevante (creación de pacientes, atenciones, dosis). La clase original `AuditService` persistía el payload JSON directamente en PostgreSQL. Sin embargo, por normativas legales y de privacidad en salud (Habeas Data), **está terminantemente prohibido almacenar contraseñas, tokens de autenticación o secretos en texto claro en las bases de datos**. Si modificábamos directamente el método `record()` de `AuditService` para ponerle filtros de texto, violábamos el Principio Abierto/Cerrado (OCP) y el de Responsabilidad Única (SRP), contaminando la lógica de persistencia JPA con parsing y limpieza de strings.
- **¿Qué soluciona?** Creamos un decorador (`MaskingAuditRecorderDecorator`) que envuelve a `AuditService`. Cuando un servicio del sistema envía un evento de auditoría, el decorador intercepta el paquete en memoria de forma transparente, inspecciona recursivamente los mapas JSON y, si detecta campos sensibles como `password`, `token`, `secret` o `contrasena`, los reemplaza automáticamente por `******`. Luego, le pasa el registro limpio al `AuditService` original para que lo guarde en la base de datos. Si el día de mañana queremos añadir otro decorador (por ejemplo, para medir tiempos o enviar alertas a Slack), simplemente creamos otro envoltorio sin tocar lo existente.

---

## 7.2. Cuadro de clases del patrón Decorator

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`AuditRecorder`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditRecorder.java) | **Component (Componente / Interfaz común)** | Define el contrato abstracto para registrar eventos de auditoría clínica en el sistema. | Permite que los servicios dependan de la abstracción sin saber cuántas capas de decoradores envuelven la llamada (DIP). |
| [`AuditRecorderDecorator`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditRecorderDecorator.java) | **Decorator (Decorador Base Abstracto)** | Clase base abstracta que mantiene una referencia protegida (`delegate`) al siguiente eslabón de auditoría. | Estandariza la cadena de delegación para que cualquier futuro decorador solo sobreescriba lo que necesita. |
| [`MaskingAuditRecorderDecorator`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/MaskingAuditRecorderDecorator.java) | **ConcreteDecorator (Decorador Concreto / `@Primary`)** | Intercepta el evento, sanitiza campos sensibles anidados reemplazándolos por `******` y delega la llamada. | Cumple leyes de protección de datos (Habeas Data) evitando guardar credenciales en claro en la base de datos (OCP y SRP). |
| [`AuditService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditService.java) | **ConcreteComponent (Componente Concreto)** | Implementación de persistencia que mapea y guarda el evento de auditoría en la tabla `audit_events`. | Se enfoca únicamente en la persistencia en base de datos PostgreSQL dentro de la transacción activa. |

### Clases preexistentes que se conectan con el patrón:
- [`IdempotencyCoordinator`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/shared/application/IdempotencyCoordinator.java): Es el **Client**. Cuando finaliza una operación clínica exitosa, inyecta `AuditRecorder` y llama a `.record(...)`. Gracias al decorador, los datos se sanitizan de forma totalmente invisible para él.

---

## 7.3. Detalle clase por clase

### 1. Interfaz: [`AuditRecorder.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditRecorder.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/audit/service/AuditRecorder.java`

#### Código fuente completo:
```java
package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;

/**
 * Puerto de auditoria (DIP). Los servicios de negocio y
 * {@link com.pai.api.shared.application.IdempotencyCoordinator} dependen de esta
 * abstraccion y no de la implementacion de persistencia, de forma coherente con
 * los puertos {@code VaccineCatalogPolicy} y {@code PatientScopePolicy}.
 */
public interface AuditRecorder {

  /** Registra el evento dentro de la transaccion de negocio en curso. */
  void record(AuditRecord record);
}
```

#### Explicación minuciosa a nivel de código:
- Define la operación única `record(AuditRecord record)`: todo aquel que quiera dejar constancia de una acción médica o administrativa en el sistema llama a este método pasando el registro `record`.

---

### 2. Clase Abstracta: [`AuditRecorderDecorator.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditRecorderDecorator.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/audit/service/AuditRecorderDecorator.java`

#### Código fuente completo:
```java
package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;

/**
 * Decorador Base (Decorator) del patron estructural Decorator para el puerto de auditoria.
 *
 * <p>Mantiene una referencia al componente envuelto ({@link AuditRecorder}) y
 * conforma la misma interfaz, delegando la ejecucion basica. Las subclases
 * (decoradores concretos) extienden o modifican el comportamiento antes o
 * despues de delegar la grabacion del evento.
 */
public abstract class AuditRecorderDecorator implements AuditRecorder {

  protected final AuditRecorder delegate;

  protected AuditRecorderDecorator(AuditRecorder delegate) {
    this.delegate = delegate;
  }

  @Override
  public void record(AuditRecord record) {
    delegate.record(record);
  }
}
```

#### Explicación minuciosa a nivel de código:
1. `protected final AuditRecorder delegate` [L15]: La palabra `delegate` significa "delegado" o "el que viene después". Guarda una referencia hacia el siguiente objeto que está envuelto.
2. `protected AuditRecorderDecorator(...)` [L17-L19]: Obliga a que cualquier decorador que herede de esta clase le entregue el objeto al que está envolviendo.
3. `record(AuditRecord record)` [L22-L24]: Su comportamiento por defecto es simplemente pasarle la bola al delegado (`delegate.record(record)`).

---

### 3. Decorador Concreto: [`MaskingAuditRecorderDecorator.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/MaskingAuditRecorderDecorator.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/audit/service/MaskingAuditRecorderDecorator.java`

#### Código fuente completo:
```java
package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;
import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.Set;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Qualifier;
import org.springframework.context.annotation.Primary;
import org.springframework.stereotype.Component;

/**
 * Decorador Concreto (ConcreteDecorator) del patron estructural Decorator.
 *
 * <p>Intercepta el evento de auditoria y enmascara campos sensibles
 * (credenciales, tokens de acceso o datos confidenciales) en el {@code payload}
 * antes de delegar la persistencia al {@link AuditService} subyacente.
 *
 * <p>Se anota con {@link Primary} para que los clientes del puerto
 * {@link AuditRecorder} (como {@code IdempotencyCoordinator}) reciban la cadena
 * decorada sin alterar su codigo consumidor.
 */
@Component
@Primary
public class MaskingAuditRecorderDecorator extends AuditRecorderDecorator {

  private static final Logger log = LoggerFactory.getLogger(MaskingAuditRecorderDecorator.class);

  private static final String MASKED_VALUE = "******";
  private static final Set<String> SENSITIVE_KEYS = Set.of(
      "password",
      "contrasena",
      "token",
      "accesstoken",
      "access_token",
      "refreshtoken",
      "refresh_token",
      "secret",
      "authorization");

  public MaskingAuditRecorderDecorator(@Qualifier("auditService") AuditRecorder delegate) {
    super(delegate);
  }

  @Override
  public void record(AuditRecord record) {
    AuditRecord sanitized = maskSensitiveData(record);
    log.debug("Evento de auditoria procesado por MaskingAuditRecorderDecorator para recurso {}", record.resourceType());
    delegate.record(sanitized);
  }

  private AuditRecord maskSensitiveData(AuditRecord record) {
    if (record == null || record.payload() == null) {
      return record;
    }

    if (record.payload() instanceof Map<?, ?> map) {
      Map<String, Object> sanitizedMap = new LinkedHashMap<>();
      for (Map.Entry<?, ?> entry : map.entrySet()) {
        String key = String.valueOf(entry.getKey());
        Object value = entry.getValue();

        if (isSensitiveKey(key)) {
          sanitizedMap.put(key, MASKED_VALUE);
        } else if (value instanceof Map<?, ?> nestedMap) {
          sanitizedMap.put(key, maskNestedMap(nestedMap));
        } else {
          sanitizedMap.put(key, value);
        }
      }
      return new AuditRecord(
          record.actorId(),
          record.institutionId(),
          record.action(),
          record.resourceType(),
          record.resourceId(),
          record.clientOperationId(),
          Collections.unmodifiableMap(sanitizedMap));
    }

    return record;
  }

  private Map<String, Object> maskNestedMap(Map<?, ?> map) {
    Map<String, Object> sanitized = new LinkedHashMap<>();
    for (Map.Entry<?, ?> entry : map.entrySet()) {
      String key = String.valueOf(entry.getKey());
      Object value = entry.getValue();
      if (isSensitiveKey(key)) {
        sanitized.put(key, MASKED_VALUE);
      } else if (value instanceof Map<?, ?> nested) {
        sanitized.put(key, maskNestedMap(nested));
      } else {
        sanitized.put(key, value);
      }
    }
    return sanitized;
  }

  private boolean isSensitiveKey(String key) {
    if (key == null) {
      return false;
    }
    String normalized = key.toLowerCase().replace("-", "").replace("_", "");
    return SENSITIVE_KEYS.contains(normalized);
  }
}
```

#### Explicación minuciosa a nivel de código:
1. `@Primary` [L26]: Le dice a Spring que cuando cualquier servicio del sistema solicite inyectar un `AuditRecorder`, le entregue primero este decorador.
2. Diccionario de palabras sensibles (`SENSITIVE_KEYS`) [L32-L41]: Lista inmutable con las claves prohibidas: contraseñas, tokens de acceso o llaves secretas.
3. Enlace con el servicio de base de datos (`@Qualifier("auditService")`) [L43-L45]: Envuelve al servicio real de persistencia pasándoselo al constructor de la clase padre con `super(delegate)`.
4. El método interceptor `record(AuditRecord record)` [L48-L52]:
   - Toma el registro entrante y lo pasa por la función de limpieza `maskSensitiveData(record)`.
   - Una vez obtenido el nuevo registro con los datos confidenciales protegidos (`sanitized`), se lo pasa al delegado real: `delegate.record(sanitized)`.
5. Limpieza recursiva de mapas (`maskSensitiveData` y `maskNestedMap`) [L54-L100]:
   - Si los datos son un mapa o diccionario, revisa clave por clave.
   - `isSensitiveKey(key)` [L102-L108]: Normaliza el texto a minúsculas y le quita guiones para que detecte por igual `password`, `Password`, `access_token` o `access-token`. Si coincide, en lugar de guardar la clave real, coloca `"******"`.
   - Si el valor dentro de una clave es otro mapa anidado (un JSON dentro de otro JSON), se llama a sí misma recursivamente para limpiar hasta el fondo cualquier objeto complejo.
   - Retorna una nueva copia inmutable del `AuditRecord` con los datos ya censurados.

---

### 4. Componente Concreto: [`AuditService.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/audit/service/AuditService.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/audit/service/AuditService.java`

#### Código fuente completo:
```java
package com.pai.api.audit.service;

import com.pai.api.audit.AuditRecord;
import com.pai.api.audit.repository.AuditEventRepository;
import com.pai.api.shared.json.JsonSerializer;
import org.springframework.stereotype.Service;

/**
 * Implementacion de {@link AuditRecorder}: persiste el evento de auditoria en la
 * misma transaccion que la operacion de negocio, de modo que un fallo de la
 * operacion revierte tambien su evento.
 *
 * <p>El payload se serializa con {@link JsonSerializer#writeOrEmpty(Object)}:
 * un fallo de serializacion no aborta la operacion de negocio.
 */
@Service("auditService")
public class AuditService implements AuditRecorder {

  private final AuditEventRepository repository;
  private final AuditEventMapper mapper;
  private final JsonSerializer json;

  public AuditService(
      AuditEventRepository repository, AuditEventMapper mapper, JsonSerializer json) {
    this.repository = repository;
    this.mapper = mapper;
    this.json = json;
  }

  @Override
  public void record(AuditRecord record) {
    repository.save(mapper.toEntity(record, json.writeOrEmpty(record.payload())));
  }
}
```

#### Explicación minuciosa a nivel de código:
- `@Service("auditService")` [L16]: Se identifica con ese nombre para ser envuelta por el decorador.
- `record(AuditRecord record)` [L31-L33]: Su responsabilidad es única y directa: convierte el objeto recibido en una entidad de base de datos usando `mapper.toEntity(...)`, convierte el payload a texto JSON con `json.writeOrEmpty(...)` y ejecuta `repository.save(...)` en PostgreSQL. Ya no se preocupa por censurar claves porque el decorador ya hizo ese trabajo antes de llamarla.

---

# 8. Patrón Adapter (Estructural)

## 8.1. Función del patrón

### En lenguaje simple y cotidiano:
Imagina que viajas de Colombia a Londres con tu secador de pelo. Tu secador tiene una clavija con dos patas planas (enchufe tipo americano), pero en la pared del hotel en Londres los tomacorrientes tienen tres ranuras rectangulares británicas enormes (enchufe tipo G). Si intentas meter la clavija a la fuerza, romperás la pared o quemarás el secador. Lo que haces es comprar en el aeropuerto un **adaptador de corriente**: conectas tu secador al adaptador, y el adaptador se enchufa en la pared. Tu secador no sabe cómo funciona el sistema eléctrico británico, y el tomacorriente británico no sabe de dónde salió tu secador; el adaptador se encarga de traducir la forma física.
El patrón **Adapter (Adaptador)** permite que dos clases o sistemas que tienen interfaces incompatibles trabajen juntos traduciendo el lenguaje, los datos y las excepciones de uno al formato que el otro espera.

### En términos técnicos y en el proyecto:
Convierte la interfaz de una clase en otra interfaz que los clientes esperan. Permite que clases con interfaces incompatibles cooperen entre sí.
- **¿Por qué lo hicimos?** Cuando se crea un nuevo usuario o enfermero en Tu Vacuna PAI, la cuenta debe darse de alta tanto en la base de datos local como en el servicio de nube de **Supabase Auth** a través de sus funciones en la nube (Edge Functions). Antes de aplicar el patrón, la clase `SupabaseAuthUserClient` era un código desordenado que mezclaba de todo en un solo archivo: construía peticiones HTTP de bajo nivel con `RestClient`, armaba cabeceras de autorización `Bearer`, conocía URLs duras de Supabase y, al mismo tiempo, intentaba atender las llamadas de negocio de la aplicación. Si Supabase cambiaba un endpoint o si el día de mañana se decidía cambiar Supabase por otro proveedor como Keycloak o Auth0, había que reescribir la lógica del sistema.
- **¿Qué soluciona?** Separamos limpiamente el problema en dos piezas:
  1. `SupabaseAuthRestClient` (el **Adaptee** o componente técnico adaptable): se encarga exclusivamente de las llamadas HTTP por internet, códigos de red y URLs de Supabase.
  2. `SupabaseAuthAdapter` (el **Adapter**): implementa la interfaz de dominio `AuthUserProvisioningClient` (el **Target**). Toma los objetos clínicos del sistema (como `AuthUserProfile`), los traduce a los mapas JSON que Supabase entiende, llama al cliente HTTP y, si ocurre un error de red (como un error HTTP 409 Conflict o un timeout), lo atrapa y lo traduce a excepciones semánticas propias del negocio de salud (`EmailAlreadyExistsException`, `UncertainProvisioningException`).

---

## 8.2. Cuadro de clases del patrón Adapter

| Clase | Rol GoF | ¿Qué hace a nivel del proyecto? | ¿Qué soluciona? (Técnico pero simple) |
| :--- | :--- | :--- | :--- |
| [`AuthUserProvisioningClient`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/AuthUserProvisioningClient.java) | **Target (Interfaz Objetivo)** | Contrato oficial que la lógica de negocio de usuarios necesita para crear o eliminar identidades de autenticación. | Desacopla la lógica de negocio de cualquier proveedor de nube específico. |
| [`SupabaseAuthRestClient`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthRestClient.java) | **Adaptee (Componente Técnico Adaptable)** | Cliente HTTP de bajo nivel que se comunica vía REST con las Edge Functions de Supabase. | Aísla la infraestructura de red, headers `Authorization: Bearer` y URLs externas. |
| [`SupabaseAuthAdapter`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthAdapter.java) | **Adapter (Adaptador Concreto / `@Primary`)** | Conecta el Target con el Adaptee: traduce objetos del dominio PAI al formato JSON de Supabase y convierte errores HTTP en excepciones médicas. | Evita que errores técnicos de red (409, 500) contaminen el negocio; si se cambia de proveedor, solo se crea otro adaptador. |

### Clases preexistentes que se conectan con el patrón:
- [`UserProvisioningService`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/UserProvisioningService.java): Es el **Client**. Cuando un administrador crea un nuevo vacunador, invoca a `AuthUserProvisioningClient` confiando en que el adaptador resolverá la comunicación con la nube.
- `SupabaseAuthUserClient`: Clase monolítica previa que fue refactorizada y reemplazada por el adaptador.

---

## 8.3. Detalle clase por clase

### 1. Interfaz Objetivo: [`AuthUserProvisioningClient.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/AuthUserProvisioningClient.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/identity/service/AuthUserProvisioningClient.java`

#### Código fuente completo:
```java
package com.pai.api.identity.service;

import java.util.UUID;

/**
 * Cliente del aprovisionamiento de identidad en Supabase Auth (Edge Functions).
 *
 * <p>Estas operaciones son invocadas con el access token del {@code SUPER_ADMIN}
 * autenticado; la Edge Function valida el JWT y el rol en la base de datos
 * antes de actuar. El service role nunca llega a Spring ni a Flutter.
 */
public interface AuthUserProvisioningClient {

  /**
   * Crea un usuario en {@code auth.users} y devuelve su id.
   *
   * <p>El {@code operationId} se escribe en el {@code app_metadata} del
   * usuario en la misma llamada, para que la correlacion exista aunque la
   * respuesta HTTP se pierda. El perfil ampliado (documento, contacto,
   * registro profesional) viaja en el {@code user_metadata}; puede ser
   * {@code null} para perfiles sin campos extra (p. ej. administradores).
   *
   * @throws EmailAlreadyExistsException si el correo ya esta registrado
   * @throws AuthUserProvisioningException si el servicio rechaza la creacion
   *         (4xx distinto de 409): nada se creo
   * @throws UncertainProvisioningException si el resultado es incierto
   *         (timeout, 5xx o sin id): el usuario puede existir
   */
  UUID createAuthUser(
      String accessToken,
      UUID operationId,
      String email,
      String password,
      String fullName,
      AuthUserProfile profile);

  /**
   * Elimina un usuario de {@code auth.users} (compensacion cuando falla la
   * creacion del espejo en {@code app.users}). Idempotente: si el usuario ya
   * no existe se trata como exito.
   */
  void deleteAuthUser(String accessToken, UUID userId);
}
```

#### Explicación minuciosa a nivel de código:
- Define exactamente lo que el negocio médico espera: `createAuthUser(...)` recibe el token del administrador, el correo, la clave, el nombre y el perfil médico (`AuthUserProfile` con documento de identidad y registro profesional de enfermería), devolviendo el `UUID` del usuario creado. No menciona HTTP, ni URLs, ni JSON.

---

### 2. Componente Técnico Adaptable: [`SupabaseAuthRestClient.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthRestClient.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthRestClient.java`

#### Código fuente completo:
```java
package com.pai.api.identity.service;

import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Component;
import org.springframework.web.client.RestClient;

/**
 * Componente Adaptable (Adaptee) del patron estructural Adapter.
 *
 * <p>Encapsula las llamadas HTTP de bajo nivel y los endpoints crudos de las
 * Edge Functions de Supabase (protocolo de transporte REST, headers JWT y
 * payloads JSON genéricos {@code Map<String, Object>}). Desacoplado de las reglas
 * de negocio y de las excepciones de dominio del sistema PAI.
 */
@Component
public class SupabaseAuthRestClient {

  private final RestClient restClient;
  private final String baseUrl;

  public SupabaseAuthRestClient(
      @Value("${app.auth-functions-url}") String baseUrl, RestClient.Builder restClientBuilder) {
    this.baseUrl = baseUrl;
    this.restClient = restClientBuilder.build();
  }

  /**
   * Ejecuta la peticion HTTP POST cruda contra la Edge Function de creacion.
   */
  public ResponseEntity<Map> postCreateAuthUser(String accessToken, Map<String, Object> payload) {
    return restClient
        .post()
        .uri(baseUrl + "/create-auth-user")
        .header("Authorization", "Bearer " + accessToken)
        .body(payload)
        .retrieve()
        .toEntity(Map.class);
  }

  /**
   * Ejecuta la peticion HTTP DELETE cruda contra la Edge Function de eliminacion.
   */
  public void deleteAuthUser(String accessToken, UUID userId) {
    restClient
        .delete()
        .uri(baseUrl + "/delete-auth-user/{id}", userId)
        .header("Authorization", "Bearer " + accessToken)
        .retrieve()
        .toBodilessEntity();
  }
}
```

#### Explicación minuciosa a nivel de código:
1. Inyección de configuración `@Value("${app.auth-functions-url}")` [L25]: Lee de las variables de entorno la dirección web base de las Edge Functions de Supabase en la nube.
2. `postCreateAuthUser(...)` [L33-L41]:
   - Ejecuta una petición HTTP con verbo `POST` contra la ruta `/create-auth-user`.
   - Coloca la cabecera HTTP de autorización con el token de seguridad: `"Authorization", "Bearer " + accessToken`.
   - Envía el cuerpo genérico `payload` y espera un mapa JSON crudo como respuesta (`ResponseEntity<Map>`). Si la red se cae, este método simplemente deja salir las excepciones de red sin atraparlas.

---

### 3. Adaptador Concreto: [`SupabaseAuthAdapter.java`](file:///c:/Users/braya/Documents/tu_vacuna_pai/services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthAdapter.java)
- **Dirección física:** `services/api/src/main/java/com/pai/api/identity/service/SupabaseAuthAdapter.java`

#### Código fuente completo:
```java
package com.pai.api.identity.service;

import com.pai.api.identity.exception.AuthUserProvisioningException;
import com.pai.api.identity.exception.EmailAlreadyExistsException;
import com.pai.api.identity.exception.UncertainProvisioningException;
import java.util.HashMap;
import java.util.Map;
import java.util.UUID;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Component;
import org.springframework.web.client.HttpStatusCodeException;
import org.springframework.web.client.ResourceAccessException;

/**
 * Adaptador (Adapter) del patron estructural Adapter.
 *
 * <p>Adapta la interfaz tecnica de bajo nivel de Supabase Auth
 * ({@link SupabaseAuthRestClient}, Adaptee) al contrato de dominio esperado por
 * el sistema PAI ({@link AuthUserProvisioningClient}, Target).
 *
 * <p>Responsabilidades de adaptacion:
 * <ul>
 *   <li>Transforma objetos de dominio tipados ({@link AuthUserProfile},
 *       {@code operationId}, credenciales) a la estructura JSON esperada por
 *       las Edge Functions de Supabase.</li>
 *   <li>Traduce codigos de estado HTTP y fallos de transporte
 *       ({@link HttpStatusCodeException}, {@link ResourceAccessException}) a
 *       excepciones de negocio ({@link EmailAlreadyExistsException},
 *       {@link UncertainProvisioningException},
 *       {@link AuthUserProvisioningException}).</li>
 * </ul>
 */
@Component
@Primary
public class SupabaseAuthAdapter implements AuthUserProvisioningClient {

  private final SupabaseAuthRestClient restClient;

  public SupabaseAuthAdapter(SupabaseAuthRestClient restClient) {
    this.restClient = restClient;
  }

  @Override
  public UUID createAuthUser(
      String accessToken,
      UUID operationId,
      String email,
      String password,
      String fullName,
      AuthUserProfile profile) {
    Map<String, Object> body = new HashMap<>();
    body.put("email", email);
    body.put("password", password);
    body.put("fullName", fullName);
    body.put("operationId", operationId);
    if (profile != null) {
      putIfPresent(body, "documentType", profile.documentType());
      putIfPresent(body, "documentNumber", profile.documentNumber());
      putIfPresent(body, "phone", profile.phone());
      putIfPresent(
          body,
          "birthDate",
          profile.birthDate() == null ? null : profile.birthDate().toString());
      putIfPresent(body, "gender", profile.gender());
      putIfPresent(body, "professionCode", profile.professionCode());
      putIfPresent(
          body, "professionalRegistrationNumber", profile.professionalRegistrationNumber());
      putIfPresent(body, "professionalRegistrationType", profile.professionalRegistrationType());
    }

    try {
      var response = restClient.postCreateAuthUser(accessToken, body);
      Object rawId = response.getBody() == null ? null : response.getBody().get("id");
      if (rawId == null) {
        throw new UncertainProvisioningException(
            "La Edge Function no devolvio el id del usuario creado.");
      }
      return UUID.fromString(rawId.toString());
    } catch (HttpStatusCodeException ex) {
      if (ex.getStatusCode() == HttpStatus.CONFLICT) {
        throw new EmailAlreadyExistsException("Ya existe un usuario con ese correo.");
      }
      if (ex.getStatusCode().is5xxServerError()) {
        throw new UncertainProvisioningException(
            "No se pudo confirmar la creacion del usuario.", ex);
      }
      throw new AuthUserProvisioningException(
          "El servicio de identidad rechazo la creacion del usuario.", ex);
    } catch (ResourceAccessException ex) {
      throw new UncertainProvisioningException("Sin respuesta del servicio de identidad.", ex);
    }
  }

  @Override
  public void deleteAuthUser(String accessToken, UUID userId) {
    restClient.deleteAuthUser(accessToken, userId);
  }

  private static void putIfPresent(Map<String, Object> body, String key, String value) {
    if (value != null && !value.isBlank()) {
      body.put(key, value);
    }
  }
}
```

#### Explicación minuciosa a nivel de código:
1. `implements AuthUserProvisioningClient` y `@Primary` [L35-L36]: El adaptador asume la identidad del Target y se declara como la opción preferida por defecto en Spring.
2. Composición con el Adaptee [L38-L42]: Guarda en su variable privada `restClient` la referencia al cliente HTTP de bajo nivel.
3. Traducción de objetos a formato JSON (`Map<String, Object> body`) [L52-L70]:
   - Empaqueta los datos simples: correo, clave, nombre completo y el identificador de operación (`operationId`).
   - Revisa si viene un `AuthUserProfile` médico y traslada uno a uno sus atributos (cédula, teléfono, registro médico profesional) utilizando el helper seguro `putIfPresent`, que ignora campos vacíos para no enviar basura a la nube.
4. Adaptación y traducción de excepciones técnicas a excepciones de negocio [L80-L92]:
   - **Error 409 Conflict [L81-L83]:** Si Supabase responde con el código HTTP 409 (Conflicto), el adaptador sabe que significa que el correo ya está registrado en el sistema. Lanza una excepción médica clara: `new EmailAlreadyExistsException(...)`.
   - **Errores 5xx del servidor [L84-L87]:** Si los servidores de Supabase fallan con error 500 o 502, el adaptador no rompe el programa con un error HTTP incomprensible; lanza `UncertainProvisioningException`, avisando que el resultado es incierto para que el orquestador no duplique registros ni asuma cosas equivocadas.
   - **Timeout o caída de conexión (`ResourceAccessException`) [L90-L92]:** Si no hay internet o la llamada expira por timeout, lanza `UncertainProvisioningException("Sin respuesta...")`.

---

# Resumen de verificación y pruebas

Todos los patrones documentados en esta guía cuentan con soporte de pruebas unitarias automáticas y reglas de arquitectura en el proyecto:
- **Pruebas de patrones:**
  - `AppliedDoseEntityBuilderTest`: Valida creación correcta, defaults e invariantes del Builder.
  - `VaccineOptionTemplateEntityPrototypeTest`: Valida duplicación de estado y nuevo UUID del Prototype.
  - `ReportFactoryProviderTest`, `XlsxReportExporterTest`, `CsvReportExporterTest`: Validan las familias de Abstract Factory.
  - `VaccineSecurityProxyTest`: Valida intercepción de permisos y delegación en el Sujeto Real del Proxy.
  - `MaskingAuditRecorderDecoratorTest`: Valida enmascaramiento con `******` y preservación de otros datos del Decorator.
  - `SupabaseAuthAdapterTest`: Valida traducción de DTOs y conversión de estados HTTP a excepciones de dominio del Adapter.
- **Validación arquitectónica:** `ArchitectureTest` corre 17 reglas de ArchUnit verificando que los patrones no violen capas ni introduzcan acoplamientos prohibidos.
