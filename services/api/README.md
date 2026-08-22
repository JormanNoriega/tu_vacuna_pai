# Tu Vacuna PAI — API (services/api)

Servicio REST backend de Tu Vacuna PAI. Monolito modular con arquitectura hexagonal.

## Requisitos

- **JDK 21+** (proyecto configurado para `java.version=21`). En esta máquina usar JDK 26:
  `C:\Program Files\Java\jdk-26.0.1`
- El `JAVA_HOME` global apunta a un JDK 11 (`C:\java`); por eso en cada comando se setea explícitamente.

## Compilar

```powershell
$env:JAVA_HOME = "C:\Program Files\Java\jdk-26.0.1"
& .\mvnw.cmd compile
```

## Configuración

Copia `.env.example` a `.env` y completa las variables (PostgreSQL de Supabase + issuer de Supabase Auth).

| Variable | Descripción |
|---|---|
| `DB_URL` | JDBC al PostgreSQL de Supabase (`jdbc:postgresql://db.<ref>.supabase.co:5432/postgres?sslmode=require`) |
| `DB_USERNAME` | Usuario de la BD Supabase (normalmente `postgres`) |
| `DB_PASSWORD` | Contraseña de la BD (la del cuadro Database, no la del panel) |
| `SUPABASE_AUTH_ISSUER` | `https://<ref>.supabase.co/auth/v1` |
| `SERVER_PORT` | Puerto del servidor (default `8080`) |

## Estructura modular

```text
src/main/java/com/pai/api/
├── shared/             # security, exceptions, pagination, auditing
├── identity/           # institutions, app.users, roles, permissions
├── patients/
├── attentions/
├── catalogs/           # vaccines, schedules, config, insurers, laboratories, geo
├── synchronization/    # push, pull, processed_operations, conflicts
├── audit/
└── reports/
```

Cada módulo: `domain/` + `application/` + `infrastructure/` + `presentation/`.

## Migraciones

Por Flyway en `src/main/resources/db/migration/` (pendiente de crear esquemas).