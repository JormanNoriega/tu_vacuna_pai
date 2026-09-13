# Wizard "Registrar paciente + vacuna" — Especificación implementada

> Estado: **implementado**. El flujo captura los campos del formato PAI en un
> wizard por secciones y termina en la aplicación de la vacuna. El modelo de
> paciente reutiliza `NewPatientInput` (extendido), no hay modelo paralelo.
>
> Fuente del formato: [`formato-registro-diario-pai.md`](../formato-xls-export/formato-registro-diario-pai.md).

## Flujo

Una sola sesión de nueva atención:

1. Buscar paciente por documento (o registrar uno nuevo).
2. Wizard de paciente (8 pasos; solo el paso 1 es obligatorio).
3. Aplicar la vacuna (catálogo efectivo) y registrar dosis.
4. Cierre del registro (esquema completo + PAIWEB) y completar la atención.

## Paso a paso del paciente

| # | Paso | Campos | Backend |
| --- | --- | --- | --- |
| 1 | Datos basicos | tipo/nº doc, 1er/2do nombre, 1er/2do apellido, fecha nac, sexo | `patients` |
| 2 | Datos complementarios | genero, orientacion sexual, etnia, tipo carnet, pais nacimiento, estatus migratorio, lugar nacimiento, edad gestacional, escolaridad | `patient_demographics`, `patients` |
| 3 | Afiliacion | regimen, aseguradora/EPS | `patient_affiliation` |
| 4 | Residencia y contacto | pais/depto/municipio, comuna, area, direccion, tel fijo, celular, correo, autoriza llamadas/correo | `patient_addresses`, `patient_contacts`, `patients` |
| 5 | Condiciones especiales | desplazado, discapacitado, fallecido, victima conflicto, estudia | `patient_special_conditions` |
| 6 | Antecedentes medicos | contraindica (+cual), reaccion previa (+cual), historicos (tipo, descripcion, fecha, notas) | `patient_medical_histories` |
| 7 | Condicion de la usuaria | condicion, fecha ultima menstruacion, embarazos previos, lugar atencion parto (condicional: mujer >= 9) | `patient_user_condition` |
| 8 | Madre / cuidador | parentesco, nombres/apellidos, tipo/nº doc, tel fijo, celular, correo, desplazado | `patient_guardians` |

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
`GET /catalogs/geo/countries|departments|municipalities` y del catalogo efectivo
de vacunas. Codigos: `document_type`, `sex`, `gender`, `sexual_orientation`,
`migration_status`, `affiliation_regime`, `ethnicity`, `area`,
`user_condition`, `carnet_type`, `guardian_relationship`, `contraindication`,
`reaction`, `insurer`.

- Los tipos de identificacion se muestran como `CODIGO - Nombre` (ej.
  `CC - Cedula de Ciudadania`) y se usan en el wizard, el buscador de Nueva
  atencion y el de Historial (mismos 13 del formato PAI).
- Pais de residencia: **fijo en Colombia** (campo visible y bloqueado).
- Pais de nacimiento: **seleccionable** (hoy solo Colombia; al sembrar mas
  paises el campo se amplia sin cambios de codigo).

## Reglas de validacion

- Paso 1: nº documento, primer nombre, primer apellido y fecha de nacimiento.
- Condicionales: menor de 18 -> madre o cuidador; gestante -> fecha de ultima
  menstruacion; parto -> lugar de atencion; PAIWEB "No" -> motivo (min. 5).
- Campos por flag de la vacuna en la dosis.
- Derivados auto: edad; semanas/fecha probable de parto (backend).

## Cambios de backend asociados

- Migracion `V16__paiweb_and_reference_gaps.sql`: PAIWEB en `attentions`,
  catalogo `insurer` (vacio) y alineacion del CHECK de `patient_demographics.gender`.
- `AttentionEntity`/`AttentionService` y DTOs de atencion: `completeScheme` y PAIWEB.
- `GeoCatalogController`: `GET /catalogs/geo/countries`.
- `PatientService.normalizeGender`: codigos `MASCULINO/FEMENINO/TRANSGENERO/INDETERMINADO`.
