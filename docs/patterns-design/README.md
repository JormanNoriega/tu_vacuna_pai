# Catálogo de Patrones de Diseño (GoF) — Tu Vacuna PAI

Este directorio consolida la documentación arquitectónica, guías de sustentación, matrices de responsabilidades y diagramas UML de los **patrones de diseño GoF** implementados y aplicados en el sistema **Tu Vacuna PAI**.

La documentación se organiza formalmente en tres categorías:

---

## 📂 Organización por Categorías

### 1. [Patrones Creacionales](./creacionales/)
Abstraen el proceso de instanciación y creación de objetos, garantizando que el sistema sea independiente de cómo se crean, componen y representan sus componentes:
* **[Guía Consolidada de Patrones Creacionales](./creacionales/GUIA-PATRONES-CREACIONALES.md)**
* **[Singleton](./creacionales/singleton/singleton.md):** Gestión de instancias únicas provistas por el contenedor IoC de Spring Boot (`@Service`, `@Component`).
* **[Factory Method](./creacionales/factory-method/factory-method.md):** Fábrica desacoplada para la resolución de comandos de sincronización y entidades.
* **[Abstract Factory](./creacionales/abstract-factory/abstract-factory.md):** Creación de familias de exportadores de reportes clínicos (`PaiReportFactory`, XLSX y CSV).
* **[Builder](./creacionales/builder/builder.md):** Construcción fluida y consistente de entidades clínicas complejas con más de 20 atributos (`AppliedDoseEntity.Builder`).
* **[Prototype](./creacionales/prototype/prototype.md):** Clonación eficiente de plantillas de configuración de vacunas para nuevas instituciones (`InstitutionOptionPrototype`).

---

### 2. [Patrones Estructurales](./estructurales/)
Se ocupan de la composición de clases y objetos para formar estructuras más grandes y mantenibles, garantizando desacoplamiento y optimización de recursos:
* **[Guía Consolidada de Patrones Estructurales](./estructurales/GUIA-PATRONES-ESTRUCTURALES.md)**
* **[Proxy (Protection Proxy)](./estructurales/proxy/README.md):** Intermediario de seguridad (`VaccineSecurityProxy`) que valida permisos de usuario antes de permitir el acceso al catálogo clínico real.
* **[Decorator](./estructurales/decorator/README.md):** Envoltura dinámica para auditoría y enmascaramiento transparente de datos sensibles (`MaskingAuditRecorderDecorator`).
* **[Adapter](./estructurales/adapter/README.md):** Adaptador de infraestructura (`SupabaseAuthAdapter`) para desacoplar el protocolo HTTP crudo de las Edge Functions del contrato de dominio PAI.
* **[Flyweight](./estructurales/flyweight/README.md):** Optimización de memoria RAM compartiendo estado intrínseco de vacunas (`SharedVaccineFlyweight`, `VaccineFlyweightFactory`).

---

### 3. [Patrones de Comportamiento](./comportamiento/)
Gestionan los algoritmos, el flujo de control y la asignación de responsabilidades entre objetos interdependientes:
* **[Guía y Clasificación de Patrones de Comportamiento](./comportamiento/README.md)**
* **[Chain of Responsibility](./comportamiento/chain-of-responsibility/README.md):** Cadena de admisión secuencial desacoplada (`SyncAdmissionChain`, `SyncOperationFilter`) para procesar operaciones de sincronización offline con cortocircuito eficiente (dependencias, idempotencia, soporte de comandos, permisos y ejecución de dominio).
* **Command (`SyncCommandHandler`):** Encapsulación de comandos offline reversibles.
* **Strategy:** Políticas de sincronización y resolución de conflictos.
* **State (`SessionStatus`):** Ciclo de vida y estados de la sesión clínica.

---

## 🛠️ Verificación y Pruebas
Todos los patrones cuentan con tests unitarios y reglas de arquitectura ArchUnit que garantizan su cumplimiento estructural:
* Backend: `cd services/api && ./mvnw.cmd test`
* Móvil: `cd apps/mobile && flutter test`
