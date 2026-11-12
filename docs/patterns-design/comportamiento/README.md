# Patrones de Comportamiento (GoF) — Tu Vacuna PAI

Los **patrones de comportamiento** se centran en los algoritmos, la asignación de responsabilidades y la comunicación e interacción entre objetos, definiendo cómo cooperan entre sí para cumplir flujos complejos sin acoplamiento rígido.

---

## 1. Categoría de Patrones de Comportamiento

En esta categoría se documentan los patrones GoF orientados al comportamiento del sistema.

| Patrón GoF | Propósito Principal | Presencia / Aplicación en Tu Vacuna PAI |
|---|---|---|
| **Chain of Responsibility** | Evita el acoplamiento del emisor a sus receptores encadenando los objetos de atención. Permite cortocircuitar y filtrar solicitudes por etapas. | [Cadena de admisión de operaciones de sincronización (`SyncPushService`, `SyncAdmissionChain`)](./chain-of-responsibility/README.md). |
| **Command** | Encapsula una solicitud como un objeto, permitiendo parametrizar clientes con distintas peticiones, colas y operaciones reversibles. | Manejo de comandos outbox/inbox en sincronización offline (`SyncCommandHandler`, `SyncPushService`). |
| **Strategy** | Define una familia de algoritmos, encapsula cada uno y los hace intercambiables en tiempo de ejecución. | Estrategias de cifrado de base de datos local y políticas de resolución de conflictos. |
| **State** | Permite a un objeto alterar su comportamiento cuando su estado interno cambia. | [Máquina de estados del ciclo de vida clínico (`AttentionEntity`, `AttentionState`)](./state/README.md). |
| **Observer** | Define una dependencia uno-a-muchos para que cuando un objeto cambie de estado, todos sus dependientes sean notificados automáticamente. | Reactividad en Flutter (`ChangeNotifier`, `ValueNotifier`, `NetworkInfo` stream listeners). |
| **Template Method** | Define el esqueleto de un algoritmo en una operación, difiriendo algunos pasos a las subclases. | Flujo de procesamiento y validación de exportación de reportes clínicos. |

---

## 2. Estructura de Documentación

Cada patrón de comportamiento documentado en este directorio cuenta con:
1. **Definición del patrón:** Propósito, problema previo y motivación de diseño.
2. **Estructura GoF:** Roles y responsabilidades de las clases participantes.
3. **Ubicación en el código:** Referencia exacta a clases, interfaces y paquetes.
4. **Diagramas UML:** Diagramas de secuencia y de clases (`.drawio` o Mermaid).
5. **Beneficios e Invariantes:** Principios SOLID respaldados (SRP, OCP) y pruebas asociadas.
