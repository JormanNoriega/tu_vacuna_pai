-- ============================================================
-- V15__reference_catalogs.sql
-- Catalogos de referencia (listas cerradas del legacy).
--
-- Tabla generica para listas de valores simples que no merecen una
-- tabla propia. El seed replica EXACTAMENTE las opciones hardcodeadas
-- del legacy (mi_vacuna) para Paso 1 y Paso 2 del wizard.
--
-- Uso: el cliente consulta GET /catalogs/reference (o /catalogs/effective)
-- y renderiza dropdowns/segmented por `catalog_code` + `sort_order`.
-- Idempotente (ON CONFLICT DO UPDATE), reejecutable por Flyway.
-- ============================================================

CREATE TABLE IF NOT EXISTS app.reference_catalogs (
    code       TEXT PRIMARY KEY,
    name       TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS app.reference_options (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    catalog_code TEXT NOT NULL,
    code         TEXT NOT NULL,
    label        TEXT NOT NULL,
    sort_order   INTEGER NOT NULL DEFAULT 0,
    is_active    BOOLEAN NOT NULL DEFAULT true,
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT fk_reference_options_catalog FOREIGN KEY (catalog_code)
        REFERENCES app.reference_catalogs (code) ON DELETE CASCADE,
    CONSTRAINT uq_reference_options UNIQUE (catalog_code, code)
);

CREATE INDEX IF NOT EXISTS idx_reference_options_catalog
    ON app.reference_options (catalog_code, sort_order);

-- ---------- Catalogos ----------
INSERT INTO app.reference_catalogs (code, name) VALUES
    ('document_type',        'Tipo de documento'),
    ('sex',                  'Sexo'),
    ('gender',               'Genero'),
    ('sexual_orientation',   'Orientacion sexual'),
    ('migration_status',     'Estatus migratorio'),
    ('affiliation_regime',   'Regimen de afiliacion'),
    ('ethnicity',            'Pertenencia etnica'),
    ('area',                 'Area'),
    ('user_condition',       'Condicion de la usuaria'),
    ('carnet_type',          'Tipo de carnet de vacunacion'),
    ('guardian_relationship','Parentesco del acompanante'),
    ('contraindication',     'Contraindicacion de vacunacion'),
    ('reaction',             'Reaccion adversa previa')
ON CONFLICT (code) DO UPDATE
    SET name = EXCLUDED.name, updated_at = now();

-- ---------- Opciones ----------
INSERT INTO app.reference_options (catalog_code, code, label, sort_order) VALUES
    -- Tipo de documento
    ('document_type', 'CN',  'Certificado de Nacido Vivo', 1),
    ('document_type', 'RC',  'Registro Civil', 2),
    ('document_type', 'TI',  'Tarjeta de Identidad', 3),
    ('document_type', 'CC',  'Cedula de Ciudadania', 4),
    ('document_type', 'AS',  'Adulto sin Identificacion', 5),
    ('document_type', 'MS',  'Menor sin Identificacion', 6),
    ('document_type', 'CE',  'Cedula de Extranjeria', 7),
    ('document_type', 'PA',  'Pasaporte', 8),
    ('document_type', 'CD',  'Carne Diplomatico', 9),
    ('document_type', 'SC',  'Salvoconducto', 10),
    ('document_type', 'PE',  'Permiso Especial de Permanencia', 11),
    ('document_type', 'PPT', 'Permiso por Proteccion Temporal', 12),
    ('document_type', 'DE',  'Documento Extranjero', 13),
    -- Sexo
    ('sex', 'MALE',          'Hombre', 1),
    ('sex', 'FEMALE',        'Mujer', 2),
    ('sex', 'INDETERMINATE', 'Indeterminado', 3),
    -- Genero
    ('gender', 'MASCULINO',    'Masculino', 1),
    ('gender', 'FEMENINO',     'Femenino', 2),
    ('gender', 'TRANSGENERO',  'Transgenero', 3),
    ('gender', 'INDETERMINADO','Indeterminado', 4),
    -- Orientacion sexual
    ('sexual_orientation', 'HETEROSEXUAL',      'Heterosexual', 1),
    ('sexual_orientation', 'HOMOSEXUAL',        'Homosexual', 2),
    ('sexual_orientation', 'BISEXUAL',          'Bisexual', 3),
    ('sexual_orientation', 'NO_SABE_NO_APLICA', 'No Sabe / No Aplica', 4),
    -- Estatus migratorio
    ('migration_status', 'REGULAR',   'Regular', 1),
    ('migration_status', 'IRREGULAR', 'Irregular', 2),
    -- Regimen de afiliacion
    ('affiliation_regime', 'CONTRIBUTIVO',                'Contributivo', 1),
    ('affiliation_regime', 'SUBSIDIADO',                  'Subsidiado', 2),
    ('affiliation_regime', 'POBLACION_POBRE_NO_ASEGURADA','Poblacion Pobre No Asegurada', 3),
    ('affiliation_regime', 'ESPECIAL',                    'Especial', 4),
    ('affiliation_regime', 'EXCEPCION',                   'Excepcion', 5),
    ('affiliation_regime', 'NO_ASEGURADO',                'No Asegurado', 6),
    -- Pertenencia etnica
    ('ethnicity', 'INDIGENA',                'Indigena', 1),
    ('ethnicity', 'ROM',                     'Rom', 2),
    ('ethnicity', 'RAIZAL',                  'Raizal', 3),
    ('ethnicity', 'PALENQUERO',              'Palenquero', 4),
    ('ethnicity', 'NEGRO_AFROCOLOMBIANO',    'Negro Afrocolombiano', 5),
    ('ethnicity', 'NINGUNO',                 'Ninguno', 6),
    -- Area
    ('area', 'URBANA', 'Urbana', 1),
    ('area', 'RURAL',  'Rural', 2),
    -- Condicion de la usuaria
    ('user_condition', 'MUJER_EDAD_FERTIL', 'Mujer En Edad Fertil', 1),
    ('user_condition', 'GESTANTE',          'Gestante', 2),
    ('user_condition', 'MUJER_MAYOR_50',    'Mujer Mayor De 50 Anos', 3),
    ('user_condition', 'NO_APLICA',         'No Aplica', 4),
    -- Tipo de carnet de vacunacion
    ('carnet_type', 'CARNE_VACUNACION_INFANTIL',                  'Carne de Vacunacion Infantil', 1),
    ('carnet_type', 'CARNE_VACUNACION_ADULTOS',                   'Carne/Certificado de Vacunacion de Adultos', 2),
    ('carnet_type', 'CARNE_VACUNACION_INTERNACIONAL',             'Carne/Certificado Internacional de Vacunacion', 3),
    ('carnet_type', 'TARJETAS_UNIFICADAS_VACUNACION_ADULTOS',     'Tarjetas Unificadas de Vacunacion - TUV Adultos', 4),
    ('carnet_type', 'TARJETAS_UNIFICADAS_VACUNACION_NINOS',       'Tarjetas Unificadas de Vacunacion - TUV Ninos', 5),
    -- Parentesco del acompanante
    ('guardian_relationship', 'MOTHER',    'Madre', 1),
    ('guardian_relationship', 'FATHER',    'Padre', 2),
    ('guardian_relationship', 'CAREGIVER', 'Cuidador', 3),
    ('guardian_relationship', 'OTHER',     'Otro', 4),
    -- Contraindicacion de vacunacion
    ('contraindication', 'CONTRA_01', 'Adultos', 1),
    ('contraindication', 'CONTRA_02', 'Anafilaxia o hipersensibilidad al huevo', 2),
    ('contraindication', 'CONTRA_03', 'Cancer', 3),
    ('contraindication', 'CONTRA_04', 'Encefalopatia', 4),
    ('contraindication', 'CONTRA_05', 'Enfermedad Autoinmune', 5),
    ('contraindication', 'CONTRA_06', 'Enfermedad congenita Inmunologica', 6),
    ('contraindication', 'CONTRA_07', 'Enfermedad neurologica degenerativa', 7),
    ('contraindication', 'CONTRA_08', 'Gestante', 8),
    ('contraindication', 'CONTRA_09', 'Hipersensibilidad a los Aminoglucosidos', 9),
    ('contraindication', 'CONTRA_10', 'Inmunocomprometido', 10),
    ('contraindication', 'CONTRA_11', 'Inmunodeficiencia Primaria o secundaria', 11),
    ('contraindication', 'CONTRA_12', 'Malformacion del aparato gastrointestinal', 12),
    ('contraindication', 'CONTRA_13', 'Menor de 6 meses', 13),
    ('contraindication', 'CONTRA_14', 'Neoplasias', 14),
    ('contraindication', 'CONTRA_15', 'Reaccion alergica a estreptomicina', 15),
    ('contraindication', 'CONTRA_16', 'Reaccion alergica a neomicina', 16),
    ('contraindication', 'CONTRA_17', 'Reaccion alergica polimixina B', 17),
    ('contraindication', 'CONTRA_18', 'Transfusiones de derivados sanguineos o inmunoglobulina', 18),
    ('contraindication', 'CONTRA_19', 'Tratamiento inmunosupresor', 19),
    ('contraindication', 'CONTRA_20', 'Varicela', 20),
    -- Reaccion adversa previa
    ('reaction', 'REACCION_01', 'Convulsiones', 1),
    ('reaction', 'REACCION_02', 'Diarrea', 2),
    ('reaction', 'REACCION_03', 'Dificultad respiratoria', 3),
    ('reaction', 'REACCION_04', 'Dolor de cabeza', 4),
    ('reaction', 'REACCION_05', 'Dolor local', 5),
    ('reaction', 'REACCION_06', 'Dolor muscular', 6),
    ('reaction', 'REACCION_07', 'Edema', 7),
    ('reaction', 'REACCION_08', 'Encefalitis', 8),
    ('reaction', 'REACCION_09', 'Enfermedad viscerotropica', 9),
    ('reaction', 'REACCION_10', 'Enrojecimiento', 10),
    ('reaction', 'REACCION_11', 'Eritema', 11),
    ('reaction', 'REACCION_12', 'Escalofrios', 12),
    ('reaction', 'REACCION_13', 'Hipotonia', 13),
    ('reaction', 'REACCION_14', 'Induracion', 14),
    ('reaction', 'REACCION_15', 'Irritabilidad', 15),
    ('reaction', 'REACCION_16', 'Linfadenitis', 16),
    ('reaction', 'REACCION_17', 'Llanto persistente', 17),
    ('reaction', 'REACCION_18', 'Paralisis flacida', 18),
    ('reaction', 'REACCION_19', 'Perdida de apetito', 19),
    ('reaction', 'REACCION_20', 'Shock anafilactico', 20),
    ('reaction', 'REACCION_21', 'Sindrome de Guillain Barre', 21),
    ('reaction', 'REACCION_22', 'Temperatura mayor 40 C', 22),
    ('reaction', 'REACCION_23', 'Trombocitopenia', 23),
    ('reaction', 'REACCION_24', 'Urticaria', 24),
    ('reaction', 'REACCION_25', 'Varicela', 25),
    ('reaction', 'REACCION_26', 'Vomito', 26)
ON CONFLICT (catalog_code, code) DO UPDATE
    SET label = EXCLUDED.label,
        sort_order = EXCLUDED.sort_order,
        is_active = true,
        updated_at = now();
