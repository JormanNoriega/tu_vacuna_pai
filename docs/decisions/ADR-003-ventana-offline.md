# ADR-003: Ventana de autorización offline

- Estado: Provisional para pruebas; pendiente de aprobación para producción
- Fecha: 2026-08-23
- Alcance: Flutter offline-first y datos clínicos

## Contexto

El vacunador puede trabajar sin conectividad, pero la aplicación almacena datos clínicos localmente y permite crear operaciones que se sincronizarán después. La ventana offline es una decisión de riesgo operativo y de protección de datos, no solo una configuración técnica.

## Decisión provisional

El valor inicial de pruebas será:

```text
offline_window_hours = 72
```

El valor será configurable por institución y no se considerará aprobado para producción hasta completar la revisión funcional, de seguridad, protección de datos y clínica.

## Comportamiento

```text
Ahora - last_online_validation <= offline_window_hours
  → se permiten las operaciones offline autorizadas

Ahora - last_online_validation > offline_window_hours
  → OFFLINE_LOCKED
  → solo lectura local
  → no se crean nuevas operaciones
```

Al recuperar conexión:

```text
refresh token
→ validar usuario activo
→ validar roles y permisos actuales
→ validar institución y scope
→ desbloquear y sincronizar, o purgar/bloquear según política
```

## Aprobación requerida para producción

La ventana debe ser aprobada por:

- Responsable funcional del PAI.
- Responsable de seguridad de la información.
- Responsable de protección de datos.
- Responsable clínico o sanitario.

El registro de aprobación debe incluir:

```text
valor aprobado
responsable
fecha
justificación operativa
fecha de revisión
```

## Mitigaciones obligatorias

- Base local cifrada.
- Clave de base local en secure storage.
- PIN o biometría para abrir la aplicación.
- Auditoría de todas las operaciones offline.
- Cuarentena de operaciones de usuarios desactivados o sin permiso.
- Purga al cambiar de institución o scope.
- Bloqueo de nuevas operaciones después de vencer la ventana.
