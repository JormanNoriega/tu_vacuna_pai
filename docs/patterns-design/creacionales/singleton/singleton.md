# Patron: Singleton

## 1. Intencion

Garantizar que una clase tenga **una unica instancia** y ofrecer un punto de
acceso global a ella.

## 2. Donde esta en nuestro codigo

En el backend **no escribimos ningun Singleton a mano**: lo provee el
**contenedor IoC de Spring**, que por defecto crea **una sola instancia** de cada
bean.

- Todo bean anotado `@Service`, `@Component`, `@Repository` o `@Configuration`
  es singleton por defecto. Ejemplos del proyecto:
  - `catalog/service/CatalogSelectionService.java:27` (`@Service`)
  - `patients/service/PatientMapper.java:24` (`@Component`)
  - `catalog/service/CatalogMapper.java:20` (`@Component`)
  - `synchronization/service/SyncPushService.java` (`@Service`)
  - `catalog/service/VaccineService.java` (`@Service`)
  - `shared/security/PermissionGuard`, `shared/application/IdempotencyCoordinator`
- Unico bean declarado de forma explicita con `@Bean`:
  - `shared/security/SecurityConfig.java:40` (clase `@Configuration` en `:22`).

## 3. Aclaracion importante

**El patron ya estaba aplicado y no lo sabiamos.** No lo implementamos nosotros:
lo reconocimos al estudiar las clases y ver las anotaciones de Spring. No existe
un `static getInstance()` ni una instancia manual; el ciclo de vida lo gestiona
el contenedor.

## 4. Evidencia de codigo

Bean singleton por anotacion + inyeccion por constructor:

```java
// catalog/service/CatalogSelectionService.java
@Service
public class CatalogSelectionService implements VaccineCatalogPolicy {

  private final VaccineRepository vaccines;
  private final VaccineOptionRepository vaccineOptions;
  private final InstitutionVaccineRepository institutionVaccines;
  private final InstitutionVaccineOptionRepository institutionOptions;

  public CatalogSelectionService(
      VaccineRepository vaccines,
      VaccineOptionRepository vaccineOptions,
      InstitutionVaccineRepository institutionVaccines,
      InstitutionVaccineOptionRepository institutionOptions) {
    this.vaccines = vaccines;
    this.vaccineOptions = vaccineOptions;
    this.institutionVaccines = institutionVaccines;
    this.institutionOptions = institutionOptions;
  }
}
```

`@Component` (mismo singleton, para mappers/utilidades):

```java
// patients/service/PatientMapper.java
@Component
public class PatientMapper {
  public PatientResponse toResponse(/* ... */) { /* ... */ }
}
```

El unico `@Bean` explicito (tambien singleton por defecto):

```java
// shared/security/SecurityConfig.java
@Configuration
@EnableWebSecurity
@EnableMethodSecurity
public class SecurityConfig {

  @Bean
  public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
    // ...
    return http.build();
  }
}
```

Nota: en ningun lado hay `private static X instance;` ni `getInstance()`. La
instancia unica la gestiona el contenedor y se **inyecta por constructor**.

## 5. Como nos ayuda

- Una **unica instancia compartida** por toda la aplicacion (servicios sin estado).
- **Inyeccion por constructor**: quien lo necesita lo recibe, no lo busca.
- **Testabilidad**: al no haber estado global, los tests instancian el servicio
  con mocks de sus colaboradores (no hay que resetear un singleton).
- **Ciclo de vida gestionado** por Spring (creacion, orden, destruccion).

## 6. Pros y contras

| Pros | Contras |
|---|---|
| Una sola instancia, sin `static`/`getInstance()`. | El estado compartido debe evitarse (servicios sin estado). |
| Inyeccion por constructor y buen testeo. | Acopla el diseno al contenedor (aunque es el estandar Spring). |
| Ciclo de vida centralizado. | Un singleton con estado mutable seria dificil de testear. |

> Escribir un Singleton clasico con `static instance` romperia la inyectabilidad
> y la testabilidad que el proyecto defiende; por eso **no** se implementa a mano.

## 7. Diagrama

- Estado actual: [`singleton.drawio`](./singleton.drawio)

## 8. Verificacion

- `mvnw test` -> todas las pruebas en verde (los servicios singleton se cubren con
  mocks en `CatalogSelectionServiceTest`, `CatalogMapperTest`, `SyncPushServiceTest`,
  `InstitutionVaccineServiceClone`, etc.).
