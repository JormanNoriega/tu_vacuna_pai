# ADR-006: Arquitectura backend por capas (Controller → Service → Repository)

- Estado: Aceptada
- Fecha: 2026-08-24
- Alcance: estructura de código del backend Spring Boot

## Contexto

El backend comenzó con una arquitectura hexagonal por módulo:

```text
domain/ + application/ + infrastructure/ + presentation/
```

En la práctica eso duplicaba modelos: una entidad de dominio (`User`,
`Institution`, `Role`, `Permission`) y una entidad JPA equivalente
(`UserJpa`, `InstitutionJpa`, `RoleJpa`, `PermissionJpa`), más un adaptador
(`JpaUserRepository`) y conversiones manuales entre ambos. Cada concepto
nuevo costaba tres clases y dos mapeos.

Hexagonal se justifica cuando existe una necesidad concreta de desacoplar el
dominio de la infraestructura: múltiples adaptadores de persistencia, un
dominio con reglas tan ricas que requieran vivir aisladas del framework, o
tests de reglas de negocio sin levantar Spring. Ninguno de esos casos aplica
a este proyecto:

- La persistencia es única y definitiva: PostgreSQL administrado por Supabase.
- Las reglas de negocio (estados de `Attention`, dosis append-only) viven
  igual de bien en las entidades JPA y en los servicios.
- El proyecto es pequeño y los módulos tienen pocas clases.
- La complejidad real del sistema está en sincronización, conflictos y
  política offline, que se resuelve principalmente en Flutter y en el diseño
  del outbox, no en la presencia de ports/adapters en el backend.

La testabilidad no se pierde: un servicio que depende de la interfaz Spring
Data `UserRepository` se mockea en tests unitarios igual que con un puerto de
dominio. Solo se elimina un nivel de indirección que no compraba nada aquí.

## Decisión

El backend usa una **arquitectura modular por capas**:

```text
HTTP
  ↓
Controller      → HTTP, validación sintáctica, códigos de respuesta
  ↓
Service         → reglas de negocio, autorización, límites transaccionales
  ↓
Repository      → acceso a datos (Spring Data JPA)
  ↓
Entity          → modelo persistente JPA
  ↓
PostgreSQL (Supabase)
```

Cada módulo se organiza así:

```text
identity/
├── controller/   # IdentityController, DTOs de entrada/salida
├── service/      # IdentityService
├── repository/   # UserRepository (interfaz Spring Data)
├── entity/       # UserEntity, InstitutionEntity, RoleEntity, PermissionEntity
└── dto/          # MeResponse y demás contratos HTTP
```

La seguridad queda separada en `shared/security/`: `SecurityConfig`,
`SecurityBeans` y `ActiveUserAuthenticationConverter`. Spring Security
Resource Server valida el JWT de Supabase; no se implementa un filtro JWT
manual.

Se elimina la nomenclatura hexagonal del backend. No queda ningún resto a
medias: `domain/`, `application/`, `infrastructure/` y `presentation/` no se
usan en el MVP.

No se crean clases de servicio gigantes. Los servicios se dividen
(`IdentityService`, `UserService`, `RoleService`, `PermissionService` en
`identity/`; `SyncService`, `SyncPushService`, `ConflictService` en `sync/`)
solo cuando aparece una responsabilidad real que lo justifique.

## Reglas explícitas de la arquitectura por capas

En hexagonal, el compilador impide que un controller devuelva una entidad de
dominio con detalles de persistencia. En arquitectura por capas esa garantía
desaparece del compilador y pasa a depender de la disciplina del equipo.
Estas reglas la reemplazan y son obligatorias en código y en code review:

1. Ningún controller devuelve una entidad JPA directamente; siempre responde
   con un DTO.
2. Ningún controller consulta un repositorio ni ejecuta lógica de negocio;
   delega en el servicio.
3. Todo mapeo de entidad a DTO se ejecuta dentro del método transaccional del
   servicio, no después de que la transacción se cerró (evita
   `LazyInitializationException`).
4. El servicio define los límites transaccionales con `@Transactional`.
5. Los repositorios contienen consultas y acceso a datos, no reglas de negocio.
6. Los DTOs de API no reutilizan entidades JPA como contrato público.

Estas reglas se verifican automáticamente con **ArchUnit** (dependencia de
test), de modo que una violación rompe el build:

- `..controller..` no depende de `..repository..`.
- Los controllers dependen de `..service..`, no de clases JPA.
- Ningún método público de un controller retorna un tipo anotado con `@Entity`.
- `..service..` puede depender de `..repository..` y `..entity..`.
- `..repository..` puede depender de `..entity..`.
- La seguridad (`shared.security`) mantiene sus responsabilidades separadas.

## Consecuencias

### Positivas

- El código refleja el flujo real de una petición; un endpoint se entiende en
  segundos (controller → service → repository → entity → DTO).
- Se elimina la duplicación de modelos y los mappers intermedios.
- La documentación, los ejemplos y los desarrolladores de Spring Boot piensan
  en estos términos; no hay impuesto de traducción entre tutorial y repo.
- Las reglas que evitan la degradación quedan escritas y verificadas por
  máquina (ArchUnit), no solo en la memoria del equipo.

### Negativas

- Se pierde la garantía estructural que daba hexagonal por diseño; la
  disciplina ahora es una combinación de reglas escritas, code review y
  ArchUnit.
- Si una regla se omite en ArchUnit, una entidad JPA podría filtrarse a la
  API por descuido.
- Cambiar a otro mecanismo de persistencia costaría más que con puertos, pero
  ese escenario no está en el horizonte del MVP.

## Alternativas consideradas

- **Mantener hexagonal**: descartada. Pagaba un impuesto de traducción y
  duplicación sin ninguna necesidad concreta que lo justificara.
- **Capas sin reglas ni ArchUnit**: descartada. La simplicidad sin disciplina
  se degrada a "transaction script" desordenado.
- **Capas con reglas explícitas y ArchUnit**: adoptada. Es la protección
  necesaria para que la simplificación sea sostenible.