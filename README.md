# Tu Vacuna PAI

Sistema de registro y consulta de vacunación (Programa Ampliado de Inmunizaciones) con arquitectura offline-first.

## Estructura del monorepo

```text
apps/mobile/          # Flutter (offline-first)
services/api/         # Spring Boot (monolito modular, hexagonal) — pendiente de crear
infra/database/       # Migraciones SQL / esquemas
docs/                 # documentación (architecture, domain, api, database, synchronization)
```

## Documentación de referencia

- `docs/architecture/architecture.md` — plan de arquitectura y decisiones de diseño (D1–D11).

## Guía rápida

1. Inicializar el subproyecto móvil: `cd apps/mobile && flutter pub get`
2. (Próximamente) bootstrap del servicio API en `services/api`.

Estado: plan objetivo. Nada implementado todavía.