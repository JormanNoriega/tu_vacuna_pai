# Tu Vacuna PAI

Sistema de registro y consulta de vacunación (Programa Ampliado de Inmunizaciones) con arquitectura offline-first.

## Estructura del monorepo

```text
apps/mobile/          # Flutter (offline-first)
services/api/         # Spring Boot (monolito modular por capas)
infra/database/       # Migraciones SQL / esquemas
docs/                 # documentación (architecture, domain, api, database, synchronization)
```

## Documentación de referencia

- `docs/architecture/architecture.md` — plan de arquitectura y decisiones de diseño (D1–D14).
- `docs/architecture/spring-data-repositories.md` — cómo funcionan los repositorios (interfaces + implementación generada por Spring Data JPA).
- `docs/architecture/flutter-frontend.md` — estado actual del frontend Flutter (capas, offline-first, features, deudas técnicas).
- `docs/decisions/ADR-005-autenticacion-y-autorizacion-offline.md` — flujo de autenticación y autorización offline.
- `docs/decisions/ADR-006-arquitectura-backend-por-capas.md` — arquitectura backend Controller → Service → Repository.

## Guía rápida

1. Inicializar el subproyecto móvil: `cd apps/mobile && flutter pub get`
2. (Próximamente) bootstrap del servicio API en `services/api`.
