# ADR-007: Alcance institucional obligatorio (RLS en la capa de datos)

- Estado: Aceptada
- Fecha: 2026-08-26
- Alcance: autorización, persistencia, arquitectura

## Contexto

Los datos de negocio dependen de la institución: usuarios, y en el futuro
pacientes, dosis, inventario y sincronización. Ningún actor debe poder leer ni
modificar recursos de otra institución, y la gestión de usuarios de un
ADMIN_INSTITUTION solo debe exponer a los usuarios que administra
(VACCINATOR y READ_ONLY), nunca a otros administradores ni a su propio perfil.

La validación de scope existía en el servicio (`UserService`), pero después de
cargar el recurso por id global (`findById`): si un futuro camino olvidara la
validación Java, el recurso quedaría expuesto. Se necesita una garantía en la
propia consulta, equivalente a RLS, que no dependa de la memoria del
desarrollador.

RLS nativo de PostgreSQL no aplica hoy: la aplicación conecta con el rol
`postgres` de Supabase (`BYPASSRLS`). Migrar a un rol dedicado no superusuario
con `SET app.institution_id` por transacción y políticas choca con Flyway
(que hace DDL con el mismo rol) y con el modelo de permisos de la aplicación.

## Decisión

Se implementa un mecanismo de alcance explícito y obligatorio en la capa de
datos Java, con dos piezas:

1. **`InstitutionScope`** (record): `{ unrestricted, institutionId }`. Dos
   estados: `restricted` (atado a una institución) y `global`
   (`unrestricted`, sin institución fija).

2. **`DataScope`** (servicio): deriva el alcance efectivo del actor
   (`AuthorizedUser`) y expone operaciones semánticas:
   - `currentScope(actor)` → `restricted(actor.institution.id)` salvo que el
     actor tenga `INSTITUTION_WRITE`, que produce `global()`.
   - `resolveInstitutionId(actor, requested)` → para actores restringidos
     devuelve la institución del actor y lanza `ScopeViolationException` si el
     cliente pide otra; para actores globales acepta la solicitada.
   - `requireSameInstitution(actor, target)` → valida un recurso ya cargado.

El flujo queda:

```text
Controller -> actor -> Service -> DataScope -> Repository(institutionId obligatorio)
                                                          -> WHERE institution_id = :institutionId
```

## Regla arquitectónica

Ningún repositorio que acceda a recursos institucionales expone operaciones
individuales por id sin criterio de institución en rutas administrativas o
clínicas. Se usan métodos scopeados:

- Lectura: `findByIdAndInstitutionId(id, institutionId)` (un recurso de otra
  institución se materializa como "no existe" en la propia query).
- Escritura: `@Modifying` con la institución en el `WHERE`
  (`updateStatusScoped`, `touchUpdatedAtScoped`,
  `deleteByUserIdScoped`): si el recurso está fuera del alcance devuelven 0 y
  no modifican nada.

Las operaciones globales por id (`findById`, `save`, `deleteByUserId`) quedan
reservadas a actores con `INSTITUTION_WRITE`, cuyo alcance es global por
diseño.

## Alcance de `INSTITUTION_WRITE`

`INSTITUTION_WRITE` produce `unrestricted = true` dentro del mecanismo de
scope, pero eso no significa acceso global ilimitado en todos los módulos.
Cada caso de uso futuro decide qué institución puede solicitar y qué permiso
adicional exige, y debe conservar su propia validación de permiso y de regla de
dominio (ADR-002).

## Consecuencias

### Positivas

- El alcance vive en la consulta: un recurso de otra institución nunca se
  materializa ni se modifica, aunque un servicio olvide validar en Java.
- Se elimina el patrón frágil "cargar global → validar después".
- El mecanismo es explícito y testeable (unidad + servicio), sin estado
  implícito de Hibernate (`@Filter`).
- No depende de un rol PostgreSQL con `BYPASSRLS`; si en el futuro se migra a
  un rol con RLS nativo, este diseño sigue siendo la primera barrera (RLS como
  segunda, ver ADR-002).
- Patrón reutilizable para pacientes, dosis, inventario y sincronización.

### Negativas

- Cada entidad institucional nueva debe declarar sus métodos scopeados; no hay
  filtro automático de Hibernate.
- Queries "globales" legitimas (p. ej. unicidad de correo por email), si se
  exponen, deben ir sin scope y con su unicidad global intacta.