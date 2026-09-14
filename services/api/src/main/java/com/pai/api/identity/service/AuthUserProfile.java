package com.pai.api.identity.service;

import java.time.LocalDate;

/**
 * Perfil ampliado de un usuario que se aprovisiona (documento, contacto y
 * registro profesional). Los valores de documento llegan ya normalizados por
 * la autoridad final (Spring). Es un objeto opcional: los administradores de
 * institucion se crean con {@code null}.
 */
public record AuthUserProfile(
    String documentType,
    String documentNumber,
    String phone,
    LocalDate birthDate,
    String gender,
    String professionCode,
    String professionalRegistrationNumber,
    String professionalRegistrationType) {}
