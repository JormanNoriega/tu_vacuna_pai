# Repositorios con Spring Data JPA: cómo funcionan

> Documento de apoyo a `ADR-006-arquitectura-backend-por-capas.md`.
> Explica por qué la capa `repository/` solo contiene interfaces y dónde vive
> su implementación. No describe una decisión nueva; describe el mecanismo del
> framework tal como se usa hoy en `services/api`.

---

## 1. Resumen

En `services/api/.../repository/` solo hay **interfaces** que extienden
`JpaRepository`. No existe ninguna clase `...RepositoryImpl` escrita a mano.

La implementación **la genera Spring Data JPA en tiempo de arranque**. La
interfaz es el repositorio: su código real no está en el repositorio de código,
lo fabrica el framework.

```text
Service
  │  (inyecta la interfaz por constructor)
  ▼
PatientRepository   ← INTERFAZ escrita por nosotros
  │
  ▼
proxy dinámico generado por Spring en runtime
  │
  ▼
SimpleJpaRepository → EntityManager (JPA/Hibernate)
  │
  ▼
SQL → PostgreSQL (Supabase)
```

---

## 2. Cómo se genera la implementación

1. `@SpringBootApplication` (`ApiApplication.java`) activa la auto-configuración
   de Spring Boot, que incluye `JpaRepositoriesAutoConfiguration`.
2. Esa auto-configuración **escanea** las interfaces que extienden
   `Repository`/`JpaRepository` (`PatientRepository`, `UserRepository`, …).
3. Para cada interfaz crea un **proxy dinámico** (patrón Proxy) que la
   implementa y lo registra como **bean** de Spring.
4. El proxy delega en la clase base
   `org.springframework.data.jpa.repository.support.SimpleJpaRepository`, que
   usa el `EntityManager` de JPA para ejecutar el SQL contra PostgreSQL.

Por eso un servicio puede recibir la interfaz por constructor sin que exista
una clase concreta: Spring inyecta el proxy generado.

---

## 3. De dónde salen los métodos

Hay tres orígenes distintos:

| Origen | Ejemplos en el proyecto | Quién lo implementa |
|---|---|---|
| **Heredados** de `JpaRepository`/`CrudRepository` | `save`, `findById`, `deleteById`, `findAll`, `existsById` | `SimpleJpaRepository` (código de Spring) |
| **Query derivada del nombre** | `findByIdAndInstitutionId`, `findByEmail`, `existsByInstitutionIdAndDocumentTypeAndDocumentNumber`, `deleteByPatientId` | Spring parsea el nombre y construye el JPQL |
| **`@Query` explícita** | `findRolesByUserId`, `updateStatusScoped`, `maxConsecutive` | JPQL escrito por nosotros; Spring lo valida y ejecuta |

### 3.1 Queries derivadas del nombre

Spring interpreta el nombre del método y lo traduce a una consulta. Ejemplo en
`PatientRepository`:

```java
List<PatientEntity> findByInstitutionIdAndDocumentNumber(UUID institutionId, String documentNumber);
```

Descomposición:

- `findBy` → prefijo de consulta (`findBy`, `existsBy`, `deleteBy`, `countBy`…).
- `InstitutionId` → campo `institutionId` de `PatientEntity`.
- `And` → operador SQL `AND`.
- `DocumentNumber` → campo `documentNumber`.
- Los parámetros se enlazan en el mismo orden de aparición.

Equivale a:

```sql
SELECT * FROM app.patients WHERE institution_id = ? AND document_number = ?
```

**Regla:** los nombres deben coincidir exactamente con los campos de la entidad.
Si no, la aplicación **falla al arrancar** con un error del tipo
`No property X found for type PatientEntity`.

Prefijos soportados: `findBy`, `readBy`, `queryBy`, `getBy`, `countBy`,
`existsBy`, `deleteBy`, `removeBy`. Palabras clave: `And`, `Or`, `OrderBy...Asc`,
`OrderBy...Desc`, `In`, `True`, `IsNull`, etc.

### 3.2 `@Query` explícita

Cuando el nombre sería incómodo (JOINs, `UPDATE`), se escribe el JPQL:

```java
@Query("""
    SELECT DISTINCT u FROM UserEntity u
    JOIN UserRoleEntity ur ON ur.userId = u.id
    JOIN RoleEntity r ON r.id = ur.roleId
    WHERE u.institutionId = :institutionId
      AND r.code IN :roleCodes
    ORDER BY u.fullName
    """)
List<UserEntity> findByInstitutionIdAndRoleCodes(...);
```

- `@Query` → consulta explícita (JPQL, no SQL nativo).
- `@Param` → nombre del parámetro enlazado.
- `@Modifying` → marca que es un `UPDATE`/`DELETE` en lugar de un `SELECT`.

---

## 4. Traza completa de una llamada

Cuando `PatientService.search` ejecuta
`patients.findByInstitutionIdAndDocumentTypeAndDocumentNumber(...)`:

```text
PatientService
  │  patients.findByInstitutionIdAndDocumentTypeAndDocumentNumber(...)
  ▼
proxy generado (implementa PatientRepository)
  │
  ▼
SimpleJpaRepository → EntityManager.createQuery(...)
  │
  ▼
JPA/Hibernate → SQL
  │
  ▼
PostgreSQL (Supabase)
```

El objeto `patients` del constructor del servicio es ese proxy, inyectado por
Spring.

---

## 5. Consecuencias prácticas

- **Ventaja:** no se escribe código de acceso a datos repetitivo; el 90 % de
  las consultas se declara con el nombre del método.
- **Ventaja:** la interfaz es fácil de mockear en tests unitarios.
- **Cuidado:** un error en el nombre del método no es un error de compilación;
  se detecta al arrancar (o en el test de contexto).
- **Cuidado:** las queries derivadas y `@Query` viven en la capa de datos, no
  deben contener reglas de negocio (ADR-006).
- **Cuidado:** para mantener el alcance institucional (ADR-007) las consultas
  de recursos institucionales **siempre** incluyen `institutionId` en el
  `WHERE`; nunca se expone un `findById` sin scope para rutas clínicas.

---

## 6. Cómo ver el SQL generado

Opciones locales (no dejar activo en producción):

- `spring.jpa.show-sql=true` en `application.properties`/`application.yml`.
- Logging de `org.hibernate.SQL` (sentencias) y
  `org.hibernate.orm.jdbc.bind` (parámetros).
- El código base de la implementación vive en
  `org.springframework.data.jpa.repository.support.SimpleJpaRepository`,
  dentro del JAR de Spring Data JPA.
