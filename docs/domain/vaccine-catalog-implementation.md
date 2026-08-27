# Implementacion del catalogo de vacunacion

> Especificacion definitiva para la implementacion del catalogo de vacunas,
> opciones clinicas, plantillas y configuracion institucional.
>
> Estado: aprobado para implementacion. La migracion inicial sera `V5`.

## 1. Objetivo y alcance

El catalogo separa la definicion clinica global de la configuracion operativa de
cada institucion.

```text
Vaccine (global)
  ├── VaccineOption (global: dose, pneumococcalType)
  └── VaccineOptionTemplate (global: laboratory, syringe, dropper, observation)
          |
          | enable: copia inicial
          v
InstitutionVaccine (institucional)
  └── InstitutionVaccineOption (copia editable local)
```

Este modulo cubre:

- Catalogo global administrado por `SUPER_ADMIN`.
- Plantillas globales de opciones operativas sugeridas.
- Habilitacion explicita de vacunas por institucion.
- Copia inicial idempotente de opciones del template.
- Edicion libre de opciones locales por `ADMIN_INSTITUTION`.
- Consulta del catalogo efectivo por `VACCINATOR` y `READ_ONLY`.
- Auditoria, control de concurrencia y soft-delete.

`AppliedDose` queda fuera de esta primera implementacion. Cuando se implemente,
guardara snapshots de texto de las opciones globales e institucionales.

## 2. Autoridad de cada dato

| Dato | Fuente de verdad | Alcance | Quien escribe |
|---|---|---|---|
| Definicion de vacuna | `vaccines` | Global | `SUPER_ADMIN` |
| Dosis | `vaccine_options` | Global | `SUPER_ADMIN` |
| Tipo de neumococo | `vaccine_options` | Global | `SUPER_ADMIN` |
| Sugerencias operativas | `vaccine_option_templates` | Global | `SUPER_ADMIN` |
| Vacuna habilitada | `institution_vaccines` | Institucion | `ADMIN_INSTITUTION` |
| Configuracion operativa | `institution_vaccine_options` | Institucion | `ADMIN_INSTITUTION` |
| Aplicacion historica | `applied_doses` | Atencion | Flujo clinico |

Las tablas globales no tienen `institution_id`. Las tablas institucionales
siempre se validan contra la institucion del usuario autenticado y su
`DataScope`.

## 3. Entidades

### 3.1 `Vaccine`

Campos:

- `id UUID PRIMARY KEY`.
- `name TEXT NOT NULL`.
- `code TEXT NOT NULL UNIQUE`.
- `category TEXT NOT NULL`.
- `max_doses SMALLINT NOT NULL`.
- `min_age_months INTEGER`.
- `max_age_months INTEGER`.
- Nueve flags booleanos provenientes del legacy.
- `is_active BOOLEAN NOT NULL DEFAULT true`.
- `version BIGINT NOT NULL DEFAULT 0`.
- `created_by UUID NOT NULL`.
- `updated_by UUID NOT NULL`.
- `created_at TIMESTAMPTZ NOT NULL`.
- `updated_at TIMESTAMPTZ NOT NULL`.

`code` es inmutable despues de la creacion. La desactivacion es logica; no se
permite DELETE fisico.

### 3.2 `VaccineOption`

Representa solamente opciones clinicas globales.

- `id UUID PRIMARY KEY`.
- `vaccine_id UUID NOT NULL REFERENCES vaccines(id)`.
- `field_type TEXT NOT NULL`.
- `value TEXT NOT NULL`.
- `value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED`.
- `display_name TEXT NOT NULL`.
- `sort_order INTEGER NOT NULL DEFAULT 0`.
- `is_default BOOLEAN NOT NULL DEFAULT false`.
- `is_active BOOLEAN NOT NULL DEFAULT true`.
- `version BIGINT NOT NULL DEFAULT 0`.
- `created_by UUID NOT NULL`.
- `updated_by UUID NOT NULL`.
- `created_at TIMESTAMPTZ NOT NULL`.
- `updated_at TIMESTAMPTZ NOT NULL`.

Valores permitidos para `field_type`:

```text
dose
pneumococcalType
```

Restricciones:

```sql
CHECK (field_type IN ('dose', 'pneumococcalType'))

CREATE UNIQUE INDEX uq_vaccine_option_value
ON vaccine_options (vaccine_id, field_type, value_normalized)
WHERE is_active = true;

CREATE UNIQUE INDEX uq_vaccine_option_default
ON vaccine_options (vaccine_id, field_type)
WHERE is_active = true AND is_default = true;
```

### 3.3 `VaccineOptionTemplate`

Representa opciones operativas sugeridas para nuevas instituciones o nuevas
importaciones.

- `id UUID PRIMARY KEY`.
- `vaccine_id UUID NOT NULL REFERENCES vaccines(id)`.
- `field_type TEXT NOT NULL`.
- `value TEXT NOT NULL`.
- `value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED`.
- `display_name TEXT NOT NULL`.
- `sort_order INTEGER NOT NULL DEFAULT 0`.
- `is_default BOOLEAN NOT NULL DEFAULT false`.
- `is_active BOOLEAN NOT NULL DEFAULT true`.
- `created_by UUID NOT NULL`.
- `updated_by UUID NOT NULL`.
- `created_at TIMESTAMPTZ NOT NULL`.
- `updated_at TIMESTAMPTZ NOT NULL`.

Valores permitidos para `field_type`:

```text
laboratory
syringe
dropper
observation
```

Restricciones:

```sql
CHECK (field_type IN ('laboratory', 'syringe', 'dropper', 'observation'))

CREATE UNIQUE INDEX uq_vaccine_option_template_value
ON vaccine_option_templates (vaccine_id, field_type, value_normalized)
WHERE is_active = true;

CREATE UNIQUE INDEX uq_vaccine_option_template_default
ON vaccine_option_templates (vaccine_id, field_type)
WHERE is_active = true AND is_default = true;
```

El template nunca se consulta directamente para resolver el formulario del
vacunador.

### 3.4 `InstitutionVaccine`

- `id UUID PRIMARY KEY`.
- `institution_id UUID NOT NULL REFERENCES institutions(id)`.
- `vaccine_id UUID NOT NULL REFERENCES vaccines(id)`.
- `is_enabled BOOLEAN NOT NULL DEFAULT true`.
- `enabled_at TIMESTAMPTZ`.
- `enabled_by UUID`.
- `version BIGINT NOT NULL DEFAULT 0`.
- `created_at TIMESTAMPTZ NOT NULL`.
- `updated_at TIMESTAMPTZ NOT NULL`.

Restriccion:

```sql
UNIQUE (institution_id, vaccine_id)
```

No se elimina la relacion al deshabilitarla.

### 3.5 `InstitutionVaccineOption`

- `id UUID PRIMARY KEY`.
- `institution_id UUID NOT NULL REFERENCES institutions(id)`.
- `vaccine_id UUID NOT NULL REFERENCES vaccines(id)`.
- `field_type TEXT NOT NULL`.
- `value TEXT NOT NULL`.
- `value_normalized TEXT GENERATED ALWAYS AS (lower(btrim(value))) STORED`.
- `display_name TEXT NOT NULL`.
- `sort_order INTEGER NOT NULL DEFAULT 0`.
- `is_default BOOLEAN NOT NULL DEFAULT false`.
- `is_active BOOLEAN NOT NULL DEFAULT true`.
- `source_template_id UUID REFERENCES vaccine_option_templates(id) ON DELETE SET NULL`.
- `version BIGINT NOT NULL DEFAULT 0`.
- `created_by UUID`.
- `updated_by UUID`.
- `created_at TIMESTAMPTZ NOT NULL`.
- `updated_at TIMESTAMPTZ NOT NULL`.

`created_by` puede ser `NULL` unicamente cuando la fila fue creada por el seed
del sistema. Si el administrador la crea o importa, se guarda su UUID.

Restricciones:

```sql
CHECK (field_type IN ('laboratory', 'syringe', 'dropper', 'observation'))

CREATE UNIQUE INDEX uq_institution_vaccine_option_value
ON institution_vaccine_options (
  institution_id,
  vaccine_id,
  field_type,
  value_normalized
)
WHERE is_active = true;

CREATE UNIQUE INDEX uq_institution_vaccine_option_default
ON institution_vaccine_options (institution_id, vaccine_id, field_type)
WHERE is_active = true AND is_default = true;
```

## 4. Ciclo de vida

### 4.1 Crear una vacuna global

`SUPER_ADMIN` crea `Vaccine`, configura sus `VaccineOption` y registra las
opciones sugeridas en `VaccineOptionTemplate`.

Crear una vacuna no la habilita automaticamente en ninguna institucion.

### 4.2 Habilitar en una institucion

```http
POST /api/v1/institutions/{institutionId}/vaccines/{vaccineId}/enable
```

El servicio ejecuta una transaccion:

1. Obtiene el actor desde `JWT.sub`.
2. Valida permiso y `DataScope`.
3. Verifica que `Vaccine` exista y este activa.
4. Ejecuta `INSERT ... ON CONFLICT DO NOTHING` en `institution_vaccines`.
5. Solo la peticion que inserto la relacion ejecuta el copy-once.
6. Copia las opciones activas del template.
7. Guarda `source_template_id`.
8. Fuerza `is_default = false` en las copias si la institucion ya tiene un
   default para el campo.
9. Registra auditoria.

Si la relacion ya existia:

- Si estaba activa, la operacion es `no-op`.
- Si estaba deshabilitada, se reactiva.
- No se vuelven a copiar opciones.
- No se sobrescriben ediciones locales.

El constraint de `institution_vaccines` es la garantia contra requests
concurrentes; un `if exists` en Java no es suficiente.

### 4.3 Deshabilitar una vacuna

```http
POST /api/v1/institutions/{institutionId}/vaccines/{vaccineId}/disable
```

Solo cambia `is_enabled`. No elimina la relacion ni sus opciones locales.

### 4.4 Clonar el catalogo a una institucion

```http
POST /api/v1/institutions/{institutionId}/vaccines/clone
Body: { "includeDefaultConfig": true }
```

Accion administrativa global (requiere `CATALOG_CONFIG_WRITE`) que habilita todas
las vacunas activas del catalogo global en la institucion:

- Por cada vacuna activa ejecuta `INSERT ... ON CONFLICT DO NOTHING` en
  `institution_vaccines` (misma garantia de concurrencia que el enable).
- Si la relacion no existia y `includeDefaultConfig = true`, copia las opciones
  activas del template como configuracion por defecto (laboratorio, jeringa,
  gotero y observacion), con `is_default = false`.
- Si `includeDefaultConfig = false`, solo crea las relaciones: la institucion
  configura sus opciones luego (o usa `import-suggested-options` por vacuna).
- Si la relacion ya existia deshabilitada, se reactiva sin volver a copiar
  opciones. Nunca sobrescribe ediciones locales.
- Responde un resumen: `{ vaccinesEnabled, optionsCopied, vaccinesTotal }`.

El clonado es idempotente: ejecutarlo dos veces no duplica relaciones ni
opciones.

### 4.5 Editar configuracion local

`ADMIN_INSTITUTION` puede editar, ordenar, activar, desactivar o crear opciones
locales. Las escrituras requieren conectividad y validan `version` mediante
optimistic locking.

Al marcar una opcion como default, el servicio:

1. Bloquea las opciones activas del mismo contexto.
2. Desmarca el default anterior.
3. Marca la nueva opcion.
4. Actualiza `updated_by`.
5. Confirma todo en una transaccion.

Si la version enviada no coincide, responde `409 CONFLICT` y no sobrescribe el
cambio de otro administrador.

### 4.6 Importar sugerencias posteriores

```http
GET  /api/v1/institutions/{institutionId}/vaccines/{vaccineId}/suggested-options
POST /api/v1/institutions/{institutionId}/vaccines/{vaccineId}/import-suggested-options
```

La comparacion usa `value_normalized`. La importacion:

- Agrega solo opciones faltantes.
- Usa `created_by` del administrador.
- Guarda `source_template_id`.
- Fuerza `is_default = false`.
- Conserva valores, orden, defaults y estados locales existentes.
- No elimina opciones locales.
- No desactiva opciones locales si se desactiva el template.

Si una opcion fue creada manualmente con el mismo valor normalizado, no se crea
una segunda fila ni se reemplaza su trazabilidad manual.

## 5. Comportamiento ante cambios globales

### Nueva vacuna

Una nueva vacuna queda visible para administracion global, pero no para ningun
vacunador hasta que una institucion la habilite. Al habilitarla, recibe las
opciones activas actuales del template y consulta sus dosis directamente desde
`vaccine_options`.

Las vacunas ya habilitadas no se tocan.

### Nueva dosis global

Una nueva dosis se agrega a `vaccine_options` y queda disponible inmediatamente
para todas las instituciones que tengan esa vacuna habilitada.

No se crean copias institucionales.

### Cambio de dosis global

El cambio se refleja para todas las instituciones. Las aplicaciones historicas
no cambian porque `AppliedDose` guardara el texto snapshot de la dosis usada.

### Nueva opcion del template

No se propaga automaticamente. Aparece como sugerencia y el administrador puede
importarla. La configuracion local existente nunca se sobrescribe.

### Template desactivado

Desactivar una opcion del template solo evita futuras copias o sugerencias. No
borra, desactiva ni modifica las filas institucionales existentes.

### Vacuna global desactivada

No puede habilitarse en nuevas instituciones ni seleccionarse para nuevas
aplicaciones. No se eliminan sus relaciones institucionales ni historicos.

## 6. Catalogo efectivo

El backend devuelve el catalogo efectivo combinando:

```text
Vaccine.is_active = true
AND InstitutionVaccine.institution_id = actor.institution_id
AND InstitutionVaccine.is_enabled = true
```

Dosis y neumococo:

```sql
SELECT *
FROM vaccine_options
WHERE vaccine_id = :vaccineId
  AND is_active = true
ORDER BY sort_order ASC, display_name ASC;
```

Opciones operativas:

```sql
SELECT *
FROM institution_vaccine_options
WHERE institution_id = :institutionId
  AND vaccine_id = :vaccineId
  AND is_active = true
ORDER BY sort_order ASC, display_name ASC;
```

El servidor no confia en un `institutionId` enviado por el cliente sin validar
identidad, permisos y scope.

## 7. API y permisos

Permisos:

```text
CATALOG_GLOBAL_READ
CATALOG_GLOBAL_WRITE
CATALOG_CONFIG_READ
CATALOG_CONFIG_WRITE
```

| Rol | Global | Institucional |
|---|---|---|
| `SUPER_ADMIN` | Lee y escribe vacunas, dosis y templates | Sin scope institucional operativo |
| `ADMIN_INSTITUTION` | Solo lectura | Lee y escribe su institucion |
| `VACCINATOR` | Solo lectura | Solo lectura |
| `READ_ONLY` | Solo lectura | Solo lectura dentro de su scope |

Las escrituras de catalogo son online-only. No generan outbox ni se confirman
localmente cuando no hay respuesta exitosa del servidor.

## 8. Backend

Modulo:

```text
services/api/src/main/java/com/pai/api/catalog/
├── controller/
├── service/
├── repository/
├── entity/
├── dto/
└── exception/
```

Servicios recomendados:

- `VaccineService`.
- `VaccineOptionService`.
- `VaccineOptionTemplateService`.
- `InstitutionVaccineService`.
- `InstitutionVaccineOptionService`.
- `EffectiveCatalogService`.

El limite transaccional vive en los servicios. Los controllers solo validan la
forma del request, delegan y devuelven DTOs.

La auditoria debe registrar actor, institucion efectiva, accion, entidad,
identificador, valores relevantes y timestamp.

## 9. Flutter y Drift

La cache local se separa por responsabilidad:

- `vaccines_cache`.
- `vaccine_options_cache`.
- `institution_vaccines_cache`.
- `institution_vaccine_options_cache`.

Las tablas institucionales siempre incluyen `institution_id` en sus claves y
consultas. Al cambiar de institucion o scope se purga la cache incompatible.

El flujo de lectura es:

```text
UI → Controller → Use Case → Repository → Remote / Drift cache
```

La cache puede mostrarse como `STALE`, pero no debe aparentar confirmacion
actual. El formulario clinico usa dosis globales y opciones locales segun las
consultas de la seccion 6.

## 10. Migracion y seed

La migracion `V5` debe:

1. Crear tablas y foreign keys.
2. Crear `value_normalized` como columna generada.
3. Crear indices parciales de valores y defaults.
4. Crear indices por institucion y vacuna.
5. Agregar auditoria y `version`.
6. Crear o migrar permisos de catalogo.
7. Cargar las 27 vacunas del legacy.
8. Convertir dosis y tipo neumococo a `vaccine_options`.
9. Convertir laboratorio, jeringa, gotero y observacion a templates.
10. Normalizar defaults duplicados del legacy antes de insertar.

El seed debe ejecutarse de forma controlada por backend o un mecanismo de
importacion versionado. No se deben escribir manualmente miles de inserts en la
migracion.

No se crean automaticamente relaciones institucionales para instituciones
existentes. La habilitacion explicita ejecuta el copy-once.

## 11. Pruebas de aceptacion

- `code` no puede editarse despues de crear una vacuna.
- No existen valores activos duplicados por vacuna y campo.
- No existen valores activos duplicados en templates.
- No existen valores activos duplicados por institucion, vacuna y campo.
- No existen dos defaults activos en el mismo contexto.
- Dos enables simultaneos producen una sola relacion y una sola copia.
- Rehabilitar no copia ni sobrescribe opciones.
- Importar dos veces es idempotente.
- Importar nunca cambia el default local.
- Desactivar un template no modifica opciones locales.
- Editar una opcion local no modifica el template.
- Crear una vacuna no la muestra automaticamente a instituciones.
- Habilitar una vacuna nueva copia solo su template actual.
- Cambiar una dosis global se refleja inmediatamente.
- `AppliedDose` conserva snapshots historicos.
- Un administrador no puede operar sobre otra institucion.
- Un conflicto de `version` devuelve `409`.
- Las escrituras administrativas offline devuelven `ONLINE_REQUIRED`.

## 12. Documentos relacionados

- `docs/architecture/architecture.md`.
- `docs/domain/invariants.md`.
- `docs/decisions/ADR-006-arquitectura-backend-por-capas.md`.
- `services/api/src/main/resources/db/migration/V5__create_vaccine_catalog.sql`.
