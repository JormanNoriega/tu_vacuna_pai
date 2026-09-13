# Wizard "Nueva atención" — Inventario de campos (insumo para el backend)

> Documento de alcance del nuevo wizard de 4 pasos (estilo legacy
> `vaccination_record`), pensado para que la Fase 2 del backend sepa
> exactamente qué columnas/tablas/enums crear.
>
> Fuente legacy: `mi_vacuna/lib/app/modules/vaccination_record/`,
> `mi_vacuna/lib/app/models/patient_model.dart`,
> `mi_vacuna/lib/app/controllers/patient_form_controller.dart`.
> Estado actual del backend nuevo: migraciones `V8__create_patients.sql` y
> `V9__create_attentions.sql`.

## Leyenda de soporte backend

| Marca | Significado |
| --- | --- |
| `OK` | Existe en el esquema/entidades actuales tal cual. |
| `PARCIAL` | Existe pero con diferencias (falta subcampo, tipo o enum distinto). |
| `FALTA` | No existe; requiere migración (Fase 2). |

Decisiones de arquitectura del wizard (fase 1 UI primero):

- Un componente por card/sección; un paso = composición de secciones.
- Un controlador por paso + shell delgado (ChangeNotifier, sin GetX).
- Búsqueda/registro de paciente en una sola acción dentro del paso 1.
- Paciente existente -> pasos 1 y 2 en resumen read-only; el guardado solo
  crea la atención y sus dosis.

---

## Paso 1 — Datos Básicos

Componente de paso: `Step1PatientStep`. Controlador: `Step1PatientController`.

| Campo (legacy) | Tipo | Oblig. | Valores | Componente | Backend |
| --- | --- | --- | --- | --- | --- |
| Fecha de atención (`attentionDate`) | fecha | Sí | default hoy | `AttentionDateField` | `OK` (`attentions.attention_date`) |
| Tipo de documento (`idType`) | dropdown | Sí | ver enums | `IdentitySection` | `PARCIAL` (`patients.document_type`, solo 4 de 13) |
| Número de identificación (`idNumber`) | texto | Sí | — | `IdentitySection` | `OK` (`patients.document_number`) |
| Primer nombre (`firstName`) | texto | Sí | — | `IdentitySection` | `OK` (`patients.first_name`) |
| Segundo nombre (`secondName`) | texto | No | — | `IdentitySection` | `FALTA` |
| Primer apellido (`lastName`) | texto | Sí | — | `IdentitySection` | `OK` (`patients.last_name`) |
| Segundo apellido (`secondLastName`) | texto | No | — | `IdentitySection` | `FALTA` |
| Fecha de nacimiento (`birthDate`) | fecha | Sí | — | `IdentitySection` | `OK` (`patients.birth_date`) |
| Edad calculada | derivado | — | años/meses/días + total meses | `AgeSummaryCard` | `FALTA` (se calcula en cliente) |
| ¿Esquema completo? (`completeScheme`) | segmented Sí/No | No | — | `SchemeToggle` | `FALTA` (o columna en `attentions`) |

Validación: `idNumber`, `firstName`, `lastName`, `birthDate` obligatorios.

---

## Paso 2 — Datos Adicionales

Componente de paso: `Step2AdditionalStep`. Controlador: `Step2AdditionalController`.

### Sección 1 — Datos Demográficos (`DemographicsSection`)

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| Sexo (`selectedSex`) | segmented | Sí | Mujer / Hombre / Indeterminado | `PARCIAL` (`patients.sex`, solo MALE/FEMALE) |
| Género (`selectedGender`) | dropdown | No | No Aplica / Masculino / Femenino / Transgénero / Indeterminado | `PARCIAL` (`patient_demographics.gender`, enum distinto) |
| Orientación sexual (`selectedSexualOrientation`) | dropdown | No | No Aplica / Heterosexual / Homosexual / Bisexual / No Sabe-No Aplica | `FALTA` |
| Pertenencia étnica (`selectedEthnicity`) | dropdown | No | Ninguno / Indígena / Rom / Raizal / Palenquero / Negro Afrocolombiano | `OK` (`patient_demographics.ethnicity`) |
| Lugar de nacimiento (`birthPlace`) | texto | No | — | `FALTA` |
| Semanas de gestación al nacer (`gestationalAge`) | número | No | — | `FALTA` |
| Tipo de carnet de vacunación (`selectedCarnetType`) | dropdown | No | ver enums | `FALTA` |

### Sección 2 — Origen y Migración (`OriginMigrationSection`)

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| País de nacimiento (`birthCountry`) | selector país | Sí | default Colombia | `FALTA` |
| Estatus migratorio (`selectedMigratoryStatus`) | segmented | Sí | Regular / Irregular | `FALTA` |

### Sección 3 — Atención y Seguridad Social (`HealthcareSocialSecuritySection`)

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| Régimen de afiliación (`selectedHealthRegime`) | dropdown | Sí | ver enums | `FALTA` |
| Aseguradora / EPS (`insurerController`) | selector EPS | Sí | catálogo EPS | `FALTA` |

### Sección 4 — Información de Contacto y Residencia (`ContactResidenceSection`)

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| País de residencia (`residenceCountry`) | texto read-only | Sí | Colombia | `PARCIAL` (`patient_addresses.country_id`, sin catálogo) |
| Departamento (`residenceDepartment`) | selector geo | Sí | catálogo | `OK` (`patient_addresses.department_id`) |
| Municipio (`residenceMunicipality`) | selector geo | Sí | catálogo | `OK` (`patient_addresses.municipality_id`) |
| Comuna / Localidad (`commune`) | texto | No | — | `FALTA` |
| Área (`selectedArea`) | segmented | Sí | Urbana / Rural | `FALTA` |
| Dirección con nomenclatura (`addressController`) | texto | Sí | — | `OK` (`patient_addresses.street`) |
| Teléfono fijo (`landlineController`) | texto | No | mín. 7 dígitos | `PARCIAL` (`patient_contacts` tipo PHONE, sin distinguir fijo/celular) |
| Celular (`cellphoneController`) | texto | Sí | mín. 7 dígitos | `PARCIAL` (`patient_contacts` tipo PHONE) |
| Email (`emailController`) | texto | No | — | `OK` (`patient_contacts` tipo EMAIL) |
| Autoriza llamadas (`authorizeCalls`) | checkbox | No | — | `FALTA` |
| Autoriza email (`authorizeEmail`) | checkbox | No | — | `FALTA` |

### Sección 5 — Antecedentes Médicos (`MedicalHistorySection`)

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| ¿Contraindica la vacunación? (`hasContraindication`) | switch | No | — | `FALTA` |
| ¿Cuál? (`contraindicationDetails`) | dropdown | Cond. (si contraindicación) | 20 opciones | `FALTA` |
| ¿Reacción moderada/severa previa? (`hasPreviousReaction`) | switch | No | — | `FALTA` |
| ¿Cuál? (`reactionDetails`) | dropdown | Cond. (si reacción) | 26 opciones | `FALTA` |
| Fecha de registro del antecedente (`historyRecordDate`) | fecha | No | — | `PARCIAL` (`patient_medical_histories.diagnosed_at`) |
| Tipo (`historyType`) | texto | No | — | `PARCIAL` (`patient_medical_histories.condition`) |
| Descripción (`historyDescription`) | texto | No | — | `PARCIAL` (`patient_medical_histories.notes`) |
| Observaciones especiales (`specialObservations`) | texto | No | — | `FALTA` |

### Sección 6 — Condición Clínica Especial (`SpecialClinicalConditionSection`)

Visibilidad: solo si `sexo = mujer` y edad `>= 9` años.

| Campo | Tipo | Oblig. | Valores | Backend |
| --- | --- | --- | --- | --- |
| Condición de la usuaria (`selectedUserCondition`) | dropdown | No | No Aplica / Mujer Edad Fértil / Gestante / Mujer Mayor 50 | `FALTA` |

Subsección `ObstetricDataSection` (solo si `gestante`):

| Campo | Tipo | Oblig. | Backend |
| --- | --- | --- | --- |
| Fecha de última menstruación (`lastMenstrualDate`) | fecha | Sí (gestante) | `FALTA` |
| Semanas de gestación (`gestationWeeks`) | texto read-only (auto) | No | `FALTA` |
| Fecha probable de parto (`probableDeliveryDate`) | fecha read-only (auto) | No | `FALTA` |
| Cantidad de embarazos previos (`previousPregnancies`) | número | No | `FALTA` |

Subsección `BirthDataSection` (solo mujeres):

| Campo | Tipo | Oblig. | Backend |
| --- | --- | --- | --- |
| ¿Ha dado a luz? (`hasGivenBirth`) | switch | No | `FALTA` |
| Lugar de atención del parto (reusa `birthPlace`) | texto | Sí (si dado a luz) | `FALTA` |

> Nota: la legacy reutiliza `birthPlaceController` para "Lugar de nacimiento"
> (demografía) y "Lugar de atención del parto". Separar en dos campos.

Subsección `SpecialConditionsSection`:

| Campo | Tipo | Backend |
| --- | --- | --- |
| Desplazado (`displaced`) | checkbox | `FALTA` |
| Discapacitado (`disabled`) | checkbox | `FALTA` |
| Fallecido (`deceased`) | checkbox | `FALTA` |
| Víctima del conflicto armado (`armedConflictVictim`) | checkbox | `FALTA` |
| Estudia actualmente (`currentlyStudying`) | tristate | `FALTA` |

### Sección 7 — Datos de la Madre (`MotherSection`)

Visibilidad: automática si el paciente es menor de 18. Validación: para menores
se exige madre **o** cuidador (o ambos).

| Campo | Tipo | Oblig. | Backend |
| --- | --- | --- | --- |
| Tipo de documento (`motherIdType`) | dropdown | Cond. | `PARCIAL` (`patient_guardians.document_type`) |
| Número de documento (`motherIdNumber`) | texto | Sí (menor) | `OK` (`patient_guardians.document_number`) |
| Primer nombre (`motherFirstName`) | texto | Sí (menor) | `PARCIAL` (`patient_guardians.full_name` único) |
| Segundo nombre (`motherSecondName`) | texto | No | `FALTA` |
| Primer apellido (`motherLastName`) | texto | Sí (menor) | `PARCIAL` |
| Segundo apellido (`motherSecondLastName`) | texto | No | `FALTA` |
| Email (`motherEmail`) | texto | No | `FALTA` |
| Teléfono fijo (`motherLandline`) | texto | No | `FALTA` |
| Celular (`motherCellphone`) | texto | No | `PARCIAL` (`patient_guardians.phone`) |
| Régimen de afiliación (`motherAffiliationRegime`) | dropdown | No | `FALTA` |
| Aseguradora / EPS (`motherInsurance`) | selector | No | `FALTA` |
| Pertenencia étnica (`motherEthnicity`) | dropdown | No | `FALTA` |
| Desplazado (`motherDisplaced`) | checkbox | No | `FALTA` |

### Sección 8 — Datos del Cuidador (`CaregiverSection`)

| Campo | Tipo | Oblig. | Backend |
| --- | --- | --- | --- |
| Tipo de documento (`caregiverIdType`) | dropdown | Cond. | `PARCIAL` (`patient_guardians.document_type`) |
| Número de documento (`caregiverIdNumber`) | texto | Sí (si cuidador) | `OK` (`patient_guardians.document_number`) |
| Primer nombre (`caregiverFirstName`) | texto | Sí (si cuidador) | `PARCIAL` (`patient_guardians.full_name`) |
| Segundo nombre (`caregiverSecondName`) | texto | No | `FALTA` |
| Primer apellido (`caregiverLastName`) | texto | Sí (si cuidador) | `PARCIAL` |
| Segundo apellido (`caregiverSecondLastName`) | texto | No | `FALTA` |
| Parentesco (`caregiverRelationship`) | texto | No | `PARCIAL` (`patient_guardians.relationship` es enum) |
| Email (`caregiverEmail`) | texto | No | `FALTA` |
| Teléfono fijo (`caregiverLandline`) | texto | No | `FALTA` |
| Celular (`caregiverCellphone`) | texto | No | `PARCIAL` (`patient_guardians.phone`) |
| Aseguradora / EPS (`caregiverInsurance`) | selector | No | `FALTA` |

---

## Paso 3 — Vacunas

Componente de paso: `Step3VaccinesStep`. Controlador: `Step3VaccinesController`.
Reutiliza `RegisterDose` (no se reescribe el backend de dosis).

Por cada vacuna (`VaccineCard`): nombre, código, `maxDoses`, rango de edad,
selección (checkbox), botones de dosis activas/bloqueadas (`DoseSelector`).

Por cada dosis activa (`DoseForm`):

| Campo | Tipo | Oblig. | Condición de visibilidad | Backend |
| --- | --- | --- | --- | --- |
| Fecha de aplicación (`applicationDate`) | fecha | Sí | siempre | `OK` (`applied_doses.application_date`) |
| Laboratorio (`selectedLaboratoryId`) | dropdown | Sí | `vaccine.hasLaboratory` | `OK` (`applied_doses.selected_laboratory_id`) |
| Lote (`lotNumber`) | texto | Sí | siempre | `OK` (`applied_doses.lot_number`) |
| Jeringa (`selectedSyringeId`) | dropdown | Sí | `vaccine.hasSyringe` | `OK` (`applied_doses.selected_syringe_id`) |
| Lote de jeringa (`syringeLot`) | texto | Sí | `vaccine.hasSyringeLot` | `FALTA` |
| Diluyente (`diluent`) | texto | Sí | `vaccine.hasDiluent` | `FALTA` |
| Gotero (`selectedDropperId`) | dropdown | Sí | `vaccine.hasDropper` | `OK` (`applied_doses.selected_dropper_id`) |
| Tipo de neumococo (`selectedPneumococcalTypeId`) | dropdown | Sí | `vaccine.hasPneumococcalType` | `OK` (`applied_doses.pneumococcal_type_option_id`) |
| Cantidad de frascos (`vialCount`) | número | Sí | `vaccine.hasVialCount` | `FALTA` |
| Observaciones (`selectedObservationId`) | dropdown | Sí | `vaccine.hasObservation` | `OK` (`applied_doses.selected_observation_id`) |
| Observación personalizada (`customObservation`) | texto | No | siempre | `FALTA` |

> El catálogo efectivo ya expone los flags `hasSyringeLot`, `hasDiluent`,
> `hasVialCount`, `hasObservation` (`effective_catalog.dart`), pero
> `applied_doses` no persiste `syringe_lot`, `diluent`, `vial_count` ni
> `custom_observation`.

---

## Paso 4 — Revisar y Confirmar

Componente de paso: `Step4ReviewStep`. Solo lectura (sin campos nuevos).

Secciones: `BasicDataReview`, `AdditionalDataReview`, `VaccinesReview`,
`WarningCard`. Reutiliza `SectionCard` + `InfoRow`.

---

## Enums requeridos (valores exactos de la legacy)

| Enum | Valores |
| --- | --- |
| Tipo de documento | CN, RC, TI, CC, AS, MS, CE, PA, CD, SC, PE, PPT, DE |
| Sexo | hombre, mujer, indeterminado |
| Género | masculino, femenino, transgenero, indeterminado |
| Orientación sexual | heterosexual, homosexual, bisexual, noSabeNoAplica |
| Estatus migratorio | regular, irregular |
| Régimen de afiliación | contributivo, subsidiado, poblacionPobreNoAsegurada, especial, excepcion, noAsegurado |
| Pertenencia étnica | indigena, rom, raizal, palenquero, negroAfrocolombiano, ninguno |
| Área | urbana, rural |
| Condición de la usuaria | mujerEdadFertil, gestante, mujerMayor50, noAplica |
| Tipo de carnet | carneVacunacionInfantil, carneVacunacionAdultos, carneVacunacionInternacional, tarjetasUnificadasVacunacionAdultos, tarjetasUnificadasVacunacionNinos |

---

## Impacto backend Fase 2 (resumen para migraciones)

### `app.patients`
- `second_name`, `second_last_name`.
- `sex`: ampliar CHECK a `MALE`, `FEMALE`, `INDETERMINATE`.
- `birth_country_id` / `birth_country`, `migration_status`.
- `complete_scheme` (o moverlo a `app.attentions`).
- `birth_place`, `gestational_age_at_birth`, `vaccination_card_type`.

### `app.patient_demographics`
- `sexual_orientation`; revisar enum `gender` (agregar transgénero/indeterminado).
- `ethnicity` ya soporta texto; alinear catálogo.

### `app.patient_addresses`
- `locality` (comuna), `area` (urbana/rural), catálogo de país.

### Nuevas / ampliadas
- `patient_affiliation` (o columnas): `affiliation_regime`, `insurer`.
- `patient_special_conditions`: `displaced`, `disabled`, `deceased`,
  `armed_conflict_victim`, `currently_studying`.
- `patient_user_condition`: `user_condition`, `last_menstrual_date`,
  `gestation_weeks`, `probable_delivery_date`, `previous_pregnancies`,
  `has_given_birth`, `birth_place_delivery`.
- `patient_contacts`: subtipo de teléfono (fijo/celular) + `authorize_calls`,
  `authorize_email`.
- `patient_medical_histories`: `has_contraindication`, `contraindication_details`,
  `has_previous_reaction`, `reaction_details`, `history_type`,
  `special_observations`.
- `patient_guardians`: `second_name`, `second_last_name`, `email`,
  `landline`, `cellphone`, `affiliation_regime`, `insurer`, `ethnicity`,
  `displaced` (o tablas `patient_mother` / `patient_caregiver` dedicadas).
- `app.applied_doses`: `syringe_lot`, `diluent`, `vial_count`,
  `custom_observation`.
- Ampliar enums: `document_type` (13), `sex` (+INDETERMINATE),
  `patient_guardians.relationship` (si se mantiene enum).

### DTOs a tocar
- `CreatePatientRequest`, `UpdatePatientDemographicsRequest`,
  `UpdatePatientContactRequest`, `UpdatePatientMedicalHistoriesRequest`,
  `PatientResponse`.
- `RegisterDoseRequest` (agregar `syringeLot`, `diluent`, `vialCount`,
  `customObservation`).

---

## Reglas de validación clave (a replicar en dominio)

- Paso 1: `idNumber`, `firstName`, `lastName`, `birthDate` obligatorios.
- Paso 2 obligatorios: país de nacimiento, estatus migratorio, régimen,
  EPS, departamento, municipio, área, dirección, celular.
- Paso 2 condicionales:
  - Menor de 18: madre o cuidador (al menos uno completo).
  - Gestante: fecha de última menstruación obligatoria.
  - Dio a luz: lugar de atención del parto obligatorio.
- Paso 3: cada dosis activa debe tener fecha de aplicación y lote; y los
  campos marcados por los flags de la vacuna.
- Guardado: si el paciente ya existía, solo se crea la atención y sus dosis.
