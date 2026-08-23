# ADR-004: Versionado del API

- Estado: Aceptada
- Fecha: 2026-08-23
- Alcance: contrato HTTP entre Flutter y Spring Boot

## Contexto

Flutter y Spring Boot evolucionarán durante el desarrollo. El contrato debe ser identificable en logs y permitir cambios incompatibles sin depender de negociación mediante headers.

## Decisión

El API se versiona mediante el path:

```text
/api/v1/patients
/api/v1/attentions
/api/v1/sync/push
/api/v1/sync/pull
```

Las reglas son:

- Los cambios aditivos y compatibles permanecen en `v1`.
- Un cambio incompatible crea `v2`.
- No se implementa compatibilidad indefinida entre versiones.
- Springdoc genera el contrato OpenAPI desde el backend.
- CI valida que el contrato no tenga cambios incompatibles no declarados.
- Los DTOs o clientes generados para Flutter no se editan manualmente.

## Consecuencias

### Positivas

- Las versiones son visibles en URLs, logs y métricas.
- El comportamiento es fácil de razonar y probar.
- No se introduce negociación de versiones innecesaria para el MVP.

### Negativas

- Algunas rutas existirán duplicadas mientras se migra a una versión nueva.
- Un cambio incompatible requiere mantener temporalmente dos contratos.
