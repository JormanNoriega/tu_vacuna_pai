# Wizard "Registrar paciente + vacuna" — Especificación implementada

> Estado: **implementado**. El flujo captura los campos del formato PAI en un
> wizard por secciones y termina en la aplicación de la vacuna. El modelo de
> paciente reutiliza `NewPatientInput` (extendido), no hay modelo paralelo.
>
> Fuente del formato: [`formato-registro-diario-pai.md`](../formato-xls-export/formato-registro-diario-pai.md).

## Flujo

Una sola sesión de nueva atención:

1. Buscar paciente por documento (o registrar uno nuevo).
2. Wizard de paciente (8 pasos; se valida el paso actual al avanzar; los campos
   obligatorios siguen el formato PAI).
3. Aplicar la vacuna (catálogo efectivo) y registrar dosis.
4. Cierre del registro (esquema completo + PAIWEB) y completar la atención.

## Paso a paso del paciente

| # | Paso | Campos | Backend |
| --- | --- | --- | --- |
| 1 | Datos basicos | tipo/nº doc, 1er/2do nombre, 1er/2do apellido, fecha nac, sexo | `patients` |
| 2 | Datos complementarios | genero, orientacion sexual, etnia, tipo carnet, pais nacimiento, estatus migratorio, lugar nacimiento, edad gestacional, escolaridad | `patient_demographics`, `patients` |
| 3 | Afiliacion | regimen, aseguradora/EPS (catalogo, filtrada por regimen) | `patient_affiliation`, `health_insurers` |
| 4 | Residencia y contacto | pais/depto/municipio, comuna, area, direccion, tel fijo, celular, correo, autoriza llamadas/correo | `patient_addresses`, `patient_contacts`, `patients` |
| 5 | Condiciones especiales | desplazado, discapacitado, fallecido, victima conflicto, estudia | `patient_special_conditions` |
| 6 | Antecedentes medicos | contraindica (+cual), reaccion previa (+cual), historicos (tipo, descripcion, fecha, notas) | `patient_medical_histories` |
| 7 | Condicion de la usuaria | condicion, fecha ultima menstruacion, embarazos previos, lugar atencion parto (condicional: mujer >= 9) | `patient_user_condition` |
| 8 | Madre / cuidador | parentesco, nombres/apellidos, tipo/nº doc, tel fijo, celular, correo, regimen, aseguradora/EPS, desplazado | `patient_guardians`, `health_insurers` |

> Aseguradora (EPS): se elige del catalogo `health_insurers`
> (`GET /api/v1/catalogs/insurers`), filtrado por regimen (contributivo incluye
> `AMBOS`; subsidiado incluye `AMBOS`; otros regimenes sin EPS). Se guarda el
> **nombre** en `insurer` y el **NIT** en `insurerCode` (snapshot, sin FK).


## Paso de la vacuna

Fecha de atencion (`attentionDate`): una por visita, **default hoy** (fecha local
del dispositivo) y editable si la aplicacion fue otro dia. Aplica a todas las
dosis de la atencion; distinto dia = nueva atencion. Se envia al crear la
atencion y tambien como `applicationDate` de cada dosis.

Por cada dosis activa (`RegisterDoseRequest`):

| Campo | Oblig. | Visibilidad |
| --- | --- | --- |
| Vacuna | Si | siempre |
| Dosis (`doseOptionId`) | Si | siempre |
| Tipo de neumococo | — | `hasPneumococcalType` |
| Laboratorio | — | `hasLaboratory` |
| Jeringa | — | `hasSyringe` |
| Lote de jeringa (`syringeLot`) | — | `hasSyringeLot` |
| Diluyente (`diluent`) | — | `hasDiluent` |
| Gotero | — | `hasDropper` |
| Cantidad de frascos (`vialCount`) | — | `hasVialCount` |
| Observacion | — | `hasObservation` |
| Lote (`lotNumber`) | — | siempre |
| Observacion personalizada (`customObservation`) | — | siempre |

## Cierre del registro

Antes de completar la atencion (`UpdateAttentionRequest`):

| Campo | Tipo | Backend |
| --- | --- | --- |
| Esquema completo (`completeScheme`) | switch | `attentions.complete_scheme` |
| Registro ingresado a PAIWEB (`paiwebRegistered`) | switch | `attentions.paiweb_registered` |
| Motivo de no ingreso (`paiwebNotRegisteredReason`) | texto (si no ingresado) | `attentions.paiweb_not_registered_reason` |

## Catalogos de referencia

Los dropdowns se alimentan de `GET /catalogs/reference` (hoja `Validador`),
`GET /catalogs/geo/countries|departments|municipalities`, `GET /catalogs/insurers`
(EPS) y del catalogo efectivo de vacunas. Codigos: `document_type`, `sex`,
`gender`, `sexual_orientation`, `migration_status`, `affiliation_regime`,
`ethnicity`, `area`, `user_condition`, `carnet_type`, `guardian_relationship`,
`contraindication`, `reaction`. Las aseguradoras/EPS viven en la tabla dedicada
`health_insurers` (ya no como catalogo de referencia `insurer`).

- Los tipos de identificacion se muestran como `CODIGO - Nombre` (ej.
  `CC - Cedula de Ciudadania`) y se usan en el wizard, el buscador de Nueva
  atencion y el de Historial (mismos 13 del formato PAI).
- Pais de residencia: **fijo en Colombia** (campo visible y bloqueado).
- Pais de nacimiento: **seleccionable** (hoy solo Colombia; al sembrar mas
  paises el campo se amplia sin cambios de codigo).

## Reglas de validacion

- Se valida **el paso actual** al pulsar "Siguiente"; el paso 8 se valida al
  "Guardar paciente". Los mensajes de campo obligatorio salen inline.
- **Paso 1**: tipo de documento, numero de documento, primer nombre, primer
  apellido, fecha de nacimiento y sexo. El segundo nombre y segundo apellido son
  opcionales.
- **Menor de 18 anios** -> madre/cuidador obligatorio (tambien se valida en el
  backend, en `PatientService`).
- **Menor de 1 anio** -> edad gestacional al nacer obligatoria.
- **Contraindicacion/reaccion "Si"** -> el detalle "Cual" es obligatorio.
- **PAIWEB "No"** -> motivo (min. 5) al cerrar la atencion.
- Campos por flag de la vacuna en la dosis.
- Derivados auto: edad; semanas/fecha probable de parto (backend).

## Obligatoriedad por paso (formato PAI)

| Paso | Obligatorios |
| --- | --- |
| 1. Datos basicos | tipo doc, nº doc, primer nombre, primer apellido, fecha de nacimiento, sexo (2º nombre/apellido opcionales) |
| 2. Complementarios | etnia, pais de nacimiento, tipo de carnet; edad gestacional solo si es menor de 1 anio |
| 3. Afiliacion | regimen, aseguradora/EPS |
| 4. Residencia y contacto | departamento, municipio, area, direccion, autoriza llamadas, autoriza correo (telefono fijo, celular, comuna y correo opcionales) |
| 5. Condiciones especiales | los 5 Si/No |
| 6. Antecedentes | contraindicacion (Si/No) y reaccion previa (Si/No); el "Cual" si la respuesta es Si |
| 7. Condicion de la usuaria | opcional (solo visible para mujer >= 9 anios) |
| 8. Madre / cuidador | obligatorio si es menor de 18: documento, nombre y apellido; si el parentesco es Madre, ademas regimen, etnia y desplazado |

> Telefonos: **solo digitos, maximo 10** (indicativo + numero, Colombia). Se
> valida en la UI (formatters) y en el backend (contactos de tipo `PHONE` y
> `GuardianDto`).

> Backend reforzado: `CreatePatientRequest` exige afiliacion (regimen +
> aseguradora), las 5 condiciones especiales y la respuesta de
> contraindicacion/reaccion; `PatientService` exige tutor para menores de 18.

## Cambios de backend asociados

- Migracion `V16__paiweb_and_reference_gaps.sql`: PAIWEB en `attentions`,
  catalogo `insurer` (vacio) y alineacion del CHECK de `patient_demographics.gender`.
- `AttentionEntity`/`AttentionService` y DTOs de atencion: `completeScheme` y PAIWEB.
- `GeoCatalogController`: `GET /catalogs/geo/countries`.
- `PatientService.normalizeGender`: codigos `MASCULINO/FEMENINO/TRANSGENERO/INDETERMINADO`.
