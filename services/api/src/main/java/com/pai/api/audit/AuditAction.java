package com.pai.api.audit;

/** Acciones auditables del dominio clinico. */
public enum AuditAction {
    PATIENT_CREATED,
    PATIENT_CONTACT_UPDATED,
    PATIENT_IDENTITY_UPDATED,
    ATTENTION_CREATED,
    ATTENTION_UPDATED,
    ATTENTION_COMPLETED,
    ATTENTION_CANCELLED,
    DOSE_REGISTERED,
    DOSE_CANCELLED,
    PATIENT_MERGED
}
