-- ============================================================
-- V18__add_length_and_range_checks.sql
-- Defensa en profundidad para los campos de entrada.
--
-- La validacion autoritativa vive en el backend (Bean Validation) y la
-- experiencia de entrada en el movil (maxLength/formatters). Estos CHECK
-- son la ultima barrera de integridad en PostgreSQL para datos que
-- pudieran entrar por una via que evite el backend.
--
--   * CHECK de longitud: length(col) <= n (NULL permitido si la columna
--     es opcional).
--   * CHECK de rango: cotas numericas de negocio.
--   * vaccines.max_doses reemplaza la cota previa (max_doses > 0) por
--     1..10; se conserva ck_vaccines_age (max_age_months >= min_age_months).
--
-- Idempotente (DROP CONSTRAINT IF EXISTS + ADD CONSTRAINT), reejecutable
-- por Flyway.
-- ============================================================

-- ---------- users ----------
ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_full_name_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_full_name_len
    CHECK (full_name IS NULL OR length(full_name) <= 200);

ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_email_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_email_len
    CHECK (email IS NULL OR length(email) <= 255);

ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_document_number_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_document_number_len
    CHECK (document_number IS NULL OR length(document_number) <= 40);

ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_phone_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_phone_len
    CHECK (phone IS NULL OR length(phone) <= 20);

ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_registration_number_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_registration_number_len
    CHECK (professional_registration_number IS NULL
        OR length(professional_registration_number) <= 60);

ALTER TABLE app.users DROP CONSTRAINT IF EXISTS ck_users_registration_type_len;
ALTER TABLE app.users ADD CONSTRAINT ck_users_registration_type_len
    CHECK (professional_registration_type IS NULL
        OR length(professional_registration_type) <= 60);

-- ---------- institutions ----------
ALTER TABLE app.institutions DROP CONSTRAINT IF EXISTS ck_institutions_code_len;
ALTER TABLE app.institutions ADD CONSTRAINT ck_institutions_code_len
    CHECK (code IS NULL OR length(code) <= 32);

ALTER TABLE app.institutions DROP CONSTRAINT IF EXISTS ck_institutions_name_len;
ALTER TABLE app.institutions ADD CONSTRAINT ck_institutions_name_len
    CHECK (name IS NULL OR length(name) <= 200);

-- ---------- patients ----------
ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_document_number_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_document_number_len
    CHECK (document_number IS NULL OR length(document_number) <= 20);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_first_name_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_first_name_len
    CHECK (first_name IS NULL OR length(first_name) <= 120);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_second_name_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_second_name_len
    CHECK (second_name IS NULL OR length(second_name) <= 120);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_last_name_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_last_name_len
    CHECK (last_name IS NULL OR length(last_name) <= 120);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_second_last_name_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_second_last_name_len
    CHECK (second_last_name IS NULL OR length(second_last_name) <= 120);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_birth_place_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_birth_place_len
    CHECK (birth_place IS NULL OR length(birth_place) <= 200);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_migration_status_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_migration_status_len
    CHECK (migration_status IS NULL OR length(migration_status) <= 20);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_card_type_len;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_card_type_len
    CHECK (vaccination_card_type IS NULL OR length(vaccination_card_type) <= 40);

ALTER TABLE app.patients DROP CONSTRAINT IF EXISTS ck_patients_gestational_age_range;
ALTER TABLE app.patients ADD CONSTRAINT ck_patients_gestational_age_range
    CHECK (gestational_age_at_birth IS NULL
        OR (gestational_age_at_birth BETWEEN 0 AND 45));

-- ---------- patient_contacts ----------
ALTER TABLE app.patient_contacts DROP CONSTRAINT IF EXISTS ck_patient_contacts_value_len;
ALTER TABLE app.patient_contacts ADD CONSTRAINT ck_patient_contacts_value_len
    CHECK (value IS NULL OR length(value) <= 120);

-- ---------- patient_demographics ----------
ALTER TABLE app.patient_demographics DROP CONSTRAINT IF EXISTS ck_patient_demographics_ethnicity_len;
ALTER TABLE app.patient_demographics ADD CONSTRAINT ck_patient_demographics_ethnicity_len
    CHECK (ethnicity IS NULL OR length(ethnicity) <= 80);

ALTER TABLE app.patient_demographics DROP CONSTRAINT IF EXISTS ck_patient_demographics_education_len;
ALTER TABLE app.patient_demographics ADD CONSTRAINT ck_patient_demographics_education_len
    CHECK (education_level IS NULL OR length(education_level) <= 120);

ALTER TABLE app.patient_demographics DROP CONSTRAINT IF EXISTS ck_patient_demographics_orientation_len;
ALTER TABLE app.patient_demographics ADD CONSTRAINT ck_patient_demographics_orientation_len
    CHECK (sexual_orientation IS NULL OR length(sexual_orientation) <= 40);

-- ---------- patient_addresses ----------
ALTER TABLE app.patient_addresses DROP CONSTRAINT IF EXISTS ck_patient_addresses_street_len;
ALTER TABLE app.patient_addresses ADD CONSTRAINT ck_patient_addresses_street_len
    CHECK (street IS NULL OR length(street) <= 200);

ALTER TABLE app.patient_addresses DROP CONSTRAINT IF EXISTS ck_patient_addresses_locality_len;
ALTER TABLE app.patient_addresses ADD CONSTRAINT ck_patient_addresses_locality_len
    CHECK (locality IS NULL OR length(locality) <= 120);

-- ---------- patient_guardians ----------
ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_full_name_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_full_name_len
    CHECK (full_name IS NULL OR length(full_name) <= 120);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_document_number_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_document_number_len
    CHECK (document_number IS NULL OR length(document_number) <= 20);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_phone_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_phone_len
    CHECK (phone IS NULL OR length(phone) <= 10);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_landline_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_landline_len
    CHECK (landline IS NULL OR length(landline) <= 10);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_cellphone_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_cellphone_len
    CHECK (cellphone IS NULL OR length(cellphone) <= 10);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_email_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_email_len
    CHECK (email IS NULL OR length(email) <= 120);

ALTER TABLE app.patient_guardians DROP CONSTRAINT IF EXISTS ck_patient_guardians_insurer_len;
ALTER TABLE app.patient_guardians ADD CONSTRAINT ck_patient_guardians_insurer_len
    CHECK (insurer IS NULL OR length(insurer) <= 120);

-- ---------- patient_medical_histories ----------
ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_condition_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_condition_len
    CHECK (condition IS NULL OR length(condition) <= 200);

ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_notes_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_notes_len
    CHECK (notes IS NULL OR length(notes) <= 500);

ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_contraindication_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_contraindication_len
    CHECK (contraindication_details IS NULL OR length(contraindication_details) <= 120);

ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_reaction_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_reaction_len
    CHECK (reaction_details IS NULL OR length(reaction_details) <= 120);

ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_history_type_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_history_type_len
    CHECK (history_type IS NULL OR length(history_type) <= 60);

ALTER TABLE app.patient_medical_histories DROP CONSTRAINT IF EXISTS ck_pmh_special_observations_len;
ALTER TABLE app.patient_medical_histories ADD CONSTRAINT ck_pmh_special_observations_len
    CHECK (special_observations IS NULL OR length(special_observations) <= 500);

-- ---------- patient_affiliation ----------
ALTER TABLE app.patient_affiliation DROP CONSTRAINT IF EXISTS ck_patient_affiliation_insurer_len;
ALTER TABLE app.patient_affiliation ADD CONSTRAINT ck_patient_affiliation_insurer_len
    CHECK (insurer IS NULL OR length(insurer) <= 120);

-- ---------- patient_user_condition ----------
ALTER TABLE app.patient_user_condition DROP CONSTRAINT IF EXISTS ck_puc_birth_place_delivery_len;
ALTER TABLE app.patient_user_condition ADD CONSTRAINT ck_puc_birth_place_delivery_len
    CHECK (birth_place_delivery IS NULL OR length(birth_place_delivery) <= 200);

ALTER TABLE app.patient_user_condition DROP CONSTRAINT IF EXISTS ck_puc_gestation_weeks_range;
ALTER TABLE app.patient_user_condition ADD CONSTRAINT ck_puc_gestation_weeks_range
    CHECK (gestation_weeks IS NULL OR (gestation_weeks BETWEEN 0 AND 45));

ALTER TABLE app.patient_user_condition DROP CONSTRAINT IF EXISTS ck_puc_previous_pregnancies_range;
ALTER TABLE app.patient_user_condition ADD CONSTRAINT ck_puc_previous_pregnancies_range
    CHECK (previous_pregnancies IS NULL OR (previous_pregnancies BETWEEN 0 AND 30));

-- ---------- vaccines ----------
ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_name_len;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_name_len
    CHECK (name IS NULL OR length(name) <= 120);

ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_code_len;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_code_len
    CHECK (code IS NULL OR length(code) <= 40);

ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_category_len;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_category_len
    CHECK (category IS NULL OR length(category) <= 60);

-- Reemplaza la cota previa (max_doses > 0) por el rango de negocio 1..100.
ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_doses;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_doses
    CHECK (max_doses BETWEEN 1 AND 100);

ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_min_age_range;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_min_age_range
    CHECK (min_age_months IS NULL OR (min_age_months BETWEEN 0 AND 240));

ALTER TABLE app.vaccines DROP CONSTRAINT IF EXISTS ck_vaccines_max_age_range;
ALTER TABLE app.vaccines ADD CONSTRAINT ck_vaccines_max_age_range
    CHECK (max_age_months IS NULL OR (max_age_months BETWEEN 0 AND 240));

-- ---------- vaccine_options ----------
ALTER TABLE app.vaccine_options DROP CONSTRAINT IF EXISTS ck_vaccine_options_value_len;
ALTER TABLE app.vaccine_options ADD CONSTRAINT ck_vaccine_options_value_len
    CHECK (value IS NULL OR length(value) <= 120);

ALTER TABLE app.vaccine_options DROP CONSTRAINT IF EXISTS ck_vaccine_options_display_len;
ALTER TABLE app.vaccine_options ADD CONSTRAINT ck_vaccine_options_display_len
    CHECK (display_name IS NULL OR length(display_name) <= 120);

ALTER TABLE app.vaccine_options DROP CONSTRAINT IF EXISTS ck_vaccine_options_sort_range;
ALTER TABLE app.vaccine_options ADD CONSTRAINT ck_vaccine_options_sort_range
    CHECK (sort_order BETWEEN 0 AND 9999);

-- ---------- vaccine_option_templates ----------
ALTER TABLE app.vaccine_option_templates DROP CONSTRAINT IF EXISTS ck_vaccine_templates_value_len;
ALTER TABLE app.vaccine_option_templates ADD CONSTRAINT ck_vaccine_templates_value_len
    CHECK (value IS NULL OR length(value) <= 120);

ALTER TABLE app.vaccine_option_templates DROP CONSTRAINT IF EXISTS ck_vaccine_templates_display_len;
ALTER TABLE app.vaccine_option_templates ADD CONSTRAINT ck_vaccine_templates_display_len
    CHECK (display_name IS NULL OR length(display_name) <= 120);

ALTER TABLE app.vaccine_option_templates DROP CONSTRAINT IF EXISTS ck_vaccine_templates_sort_range;
ALTER TABLE app.vaccine_option_templates ADD CONSTRAINT ck_vaccine_templates_sort_range
    CHECK (sort_order BETWEEN 0 AND 9999);

-- ---------- institution_vaccine_options ----------
ALTER TABLE app.institution_vaccine_options DROP CONSTRAINT IF EXISTS ck_ivo_value_len;
ALTER TABLE app.institution_vaccine_options ADD CONSTRAINT ck_ivo_value_len
    CHECK (value IS NULL OR length(value) <= 120);

ALTER TABLE app.institution_vaccine_options DROP CONSTRAINT IF EXISTS ck_ivo_display_len;
ALTER TABLE app.institution_vaccine_options ADD CONSTRAINT ck_ivo_display_len
    CHECK (display_name IS NULL OR length(display_name) <= 120);

ALTER TABLE app.institution_vaccine_options DROP CONSTRAINT IF EXISTS ck_ivo_sort_range;
ALTER TABLE app.institution_vaccine_options ADD CONSTRAINT ck_ivo_sort_range
    CHECK (sort_order BETWEEN 0 AND 9999);

-- ---------- attentions ----------
ALTER TABLE app.attentions DROP CONSTRAINT IF EXISTS ck_attentions_observations_len;
ALTER TABLE app.attentions ADD CONSTRAINT ck_attentions_observations_len
    CHECK (observations IS NULL OR length(observations) <= 2000);

ALTER TABLE app.attentions DROP CONSTRAINT IF EXISTS ck_attentions_paiweb_reason_len;
ALTER TABLE app.attentions ADD CONSTRAINT ck_attentions_paiweb_reason_len
    CHECK (paiweb_not_registered_reason IS NULL
        OR length(paiweb_not_registered_reason) <= 500);

-- ---------- applied_doses ----------
ALTER TABLE app.applied_doses DROP CONSTRAINT IF EXISTS ck_applied_doses_lot_number_len;
ALTER TABLE app.applied_doses ADD CONSTRAINT ck_applied_doses_lot_number_len
    CHECK (lot_number IS NULL OR length(lot_number) <= 60);

ALTER TABLE app.applied_doses DROP CONSTRAINT IF EXISTS ck_applied_doses_syringe_lot_len;
ALTER TABLE app.applied_doses ADD CONSTRAINT ck_applied_doses_syringe_lot_len
    CHECK (syringe_lot IS NULL OR length(syringe_lot) <= 60);

ALTER TABLE app.applied_doses DROP CONSTRAINT IF EXISTS ck_applied_doses_diluent_len;
ALTER TABLE app.applied_doses ADD CONSTRAINT ck_applied_doses_diluent_len
    CHECK (diluent IS NULL OR length(diluent) <= 120);

ALTER TABLE app.applied_doses DROP CONSTRAINT IF EXISTS ck_applied_doses_custom_observation_len;
ALTER TABLE app.applied_doses ADD CONSTRAINT ck_applied_doses_custom_observation_len
    CHECK (custom_observation IS NULL OR length(custom_observation) <= 500);

ALTER TABLE app.applied_doses DROP CONSTRAINT IF EXISTS ck_applied_doses_vial_count_range;
ALTER TABLE app.applied_doses ADD CONSTRAINT ck_applied_doses_vial_count_range
    CHECK (vial_count IS NULL OR (vial_count BETWEEN 0 AND 999));

-- ---------- health_insurers ----------
ALTER TABLE app.health_insurers DROP CONSTRAINT IF EXISTS ck_health_insurers_nit_len;
ALTER TABLE app.health_insurers ADD CONSTRAINT ck_health_insurers_nit_len
    CHECK (nit IS NULL OR length(nit) <= 40);

ALTER TABLE app.health_insurers DROP CONSTRAINT IF EXISTS ck_health_insurers_name_len;
ALTER TABLE app.health_insurers ADD CONSTRAINT ck_health_insurers_name_len
    CHECK (name IS NULL OR length(name) <= 200);
