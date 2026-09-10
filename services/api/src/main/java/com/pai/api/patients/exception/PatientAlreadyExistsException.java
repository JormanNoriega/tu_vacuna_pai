package com.pai.api.patients.exception;

/**
 * El paciente ya existe en la institucion para el tipo y numero de documento
 * indicados. La identidad de negocio es {@code (institution, documentType,
 * documentNumber)}; un duplicado no se fusiona automaticamente (invariante
 * {@code does_not_auto_merge_patient_identity}).
 */
public class PatientAlreadyExistsException extends RuntimeException {

    public PatientAlreadyExistsException(String message) {
        super(message);
    }
}
