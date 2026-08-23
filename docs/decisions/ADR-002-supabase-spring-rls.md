# ADR-002: Supabase, Spring Boot y RLS

- Estado: Aceptada
- Fecha: 2026-08-23
- Alcance: persistencia, autenticación y autorización

## Contexto

El sistema necesita PostgreSQL administrado, autenticación, backups y una operación sencilla, pero la autorización de negocio incluye roles, instituciones, scopes, conflictos y reglas clínicas.

## Decisión

Se utiliza Supabase como:

- PostgreSQL administrado.
- Proveedor de Supabase Auth.
- Plataforma operativa para desarrollo, backups y despliegue.

Spring Boot es la única puerta de acceso de la aplicación móvil. Flutter no utiliza PostgREST directamente.

RLS puede habilitarse como defensa en profundidad, pero Spring Boot mantiene la autoridad de autorización de la aplicación.

## Regla negativa explícita

Ningún endpoint de Spring debe delegar una validación de permiso o scope asumiendo que RLS ya la cubrió. Spring siempre debe validar usuario activo, permiso, institución, scope y regla de dominio.

RLS no reemplaza:

- `AuthorizationService`.
- `ScopeService`.
- Validaciones de transición de estados.
- Resolución de conflictos.
- Auditoría de operaciones.

## Flujo de acceso

```text
Flutter → Supabase Auth para autenticación
Flutter → Spring Boot por HTTPS
Spring → valida JWT y autorización
Spring → PostgreSQL mediante JPA/JDBC
PostgreSQL/RLS → defensa adicional si está habilitada
```

El cliente nunca envía un `institutionId` o scope para obtener acceso. Spring deriva esos valores del usuario autenticado y de sus asignaciones actuales.

## Consecuencias

### Positivas

- La lógica de negocio queda centralizada en Spring.
- Se conserva la facilidad operativa de Supabase.
- Se puede cambiar el proveedor de PostgreSQL sin cambiar el contrato de aplicación.
- RLS ofrece una barrera adicional ante accesos directos o errores de configuración.

### Negativas

- Se mantienen validaciones en Spring aunque RLS exista.
- Hay que configurar cuidadosamente el acceso de la aplicación a PostgreSQL.
- Se debe evitar que nuevos desarrolladores confundan RLS con autorización completa.
