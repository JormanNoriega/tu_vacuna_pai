# Plan: inventario, entregas y vínculo con la vacunación

## Estado y alcance

Este documento recoge la dirección funcional acordada y las propuestas pendientes de detalle. **Es un plan, no una descripción de funcionalidades ya implementadas ni una autorización para activarlas.** Para el flujo online existente y sus límites, consultar [flujo operativo actual](12-flujo-operativo-inventario.md) y [puesta en marcha controlada](11-puesta-en-marcha-controlada.md).

La aplicación clínica debe seguir operativa durante la transición. Antes de implementar, contrastar este plan con el código, datos y permisos existentes, y diseñar una migración que conserve el historial. La validación automatizada no sustituye la revisión con responsables PAI ni la prueba con usuarios autorizados.

## Principios

- **Inventario** controla existencias físicas; **Entregas y jornadas** gestiona su distribución y custodia; el registro clínico documenta la atención. Son procesos distintos relacionados entre sí.
- Los frascos son unidades físicas; las dosis nominales de una presentación, las aplicaciones clínicas y las dosis descartadas son conceptos distintos. No convertir automáticamente frascos en dosis clínicamente utilizables.
- Una entrega no equivale a una aplicación; una jornada no mueve existencias por sí sola y es opcional para la vacunación rutinaria.
- No inventar existencias, lotes ni movimientos para cuadrar un saldo. No asumir que el inventario está vacío ni usar datos ficticios en producción.
- Una aplicación clínica legítima no debe perderse por una discrepancia logística. La excepción documenta un hecho, pero no autoriza administrar sin verificar identidad, vencimiento y condiciones de uso.
- El servidor valida permisos, institución, concurrencia y transiciones. Los movimientos históricos deben ser trazables y las correcciones, explícitas; los reintentos no deben duplicar efectos.

## 1. Inventario

### Pantalla principal

- Presentar una tarjeta por vacuna que destaque los **frascos disponibles físicamente en depósito**, con datos reales de la institución.
- Mostrar como información secundaria los frascos en tránsito o custodia y el número de lotes. Desglosar tránsito y custodia cuando se disponga de datos fiables. No sumar esas cantidades al disponible.
- Identificar unidades y evitar presentar como cero una cifra que no pudo consultarse. Diseñar estados de carga, error, sin permisos, sin conexión y sin existencias.
- Al abrir la vacuna, mostrar lotes, fabricante, vencimiento, presentación —incluidas dosis nominales por frasco—, cantidades y movimientos. Conservar la entrada física por lote con su auditoría.
- El buscador y el resumen deben desplazarse con el contenido, en vez de permanecer ambos fijos bajo la barra superior. Conservar la navegación principal.
- Retirar el acceso operativo de asignaciones de Inventario y ofrecerlo como módulo independiente. No retirar el CSV existente hasta acordar su nueva ubicación.

La tarjeta es una representación propuesta; las definiciones exactas de agregación, lotes contados y filtros de disponibilidad deben verificarse contra el modelo y los estados reales, incluidos vencidos y cuarentena.

## 2. Entregas y jornadas

Crear una opción independiente del menú principal, **Entregas y jornadas**, con dos pestañas:

1. **Entregas:** crear una entrega con o sin jornada; consultar tránsito, recepción y custodia; gestionar devoluciones y novedades. El vacunador consulta su propia custodia y confirma la recepción física según sus permisos.
2. **Jornadas:** programar jornadas, asignar responsables, consultar entregas vinculadas y visualizar progreso. Definir qué indicadores de progreso son fiables antes de mostrarlos.

La entrega consulta el saldo real del lote; al registrarse, el inventario entregado deja de estar disponible para otra entrega y queda en tránsito, aunque todavía no se haya recibido. La verificación y el movimiento deben ser atómicos ante operaciones concurrentes. La jornada por sí sola no reserva ni mueve frascos; cerrarla no implica devolverlos automáticamente.

### Destinos de custodia

Diseñar la custodia para admitir **persona, punto de vacunación o equipo**, sin prometer que las tres opciones estarán disponibles en la primera interfaz. Inicialmente se prevén entregas a vacunadores. Separar el titular de la custodia de la persona que ejecuta cada operación.

Para puntos o equipos se acordó un **responsable principal obligatorio**, designado o sustituido por un administrador, con entrega y conteo documentados e historial. Sin embargo, se priorizan asignaciones físicas individuales a vacunadores: la operación compartida y sus permisos quedan para una fase posterior. El diseño extensible no equivale a habilitar ya equipos, puntos ni transferencias entre ellos.

Para brigadas sin conexión, no se permitirá que varios dispositivos descuenten independientemente del mismo saldo compartido. La dirección acordada es separar físicamente y entregar cantidades exclusivas a cada vacunador antes de desconectarse. Si varios usan una misma nevera, se considera para una fase futura un único dispositivo responsable del inventario compartido; registrar aplicaciones clínicas en otros dispositivos no les autoriza a descontar ese mismo saldo offline. Para un frasco multidosis, inicialmente se prevé que un solo dispositivo gestione su consumo durante cada período sin conexión. Estas son decisiones de diseño, **no una habilitación de consumo offline**: faltan identidad de dispositivo, exclusividad, transferencias, conflictos, recuperación y sincronización segura y validada.

### Diseño local de custodia individual

- Identidad lógica: institución, custodio individual y lote; varias entregas y recepciones pueden contribuir a una misma custodia sin que finalizar una entrega elimine su procedencia. El actor de una operación se registra por separado del custodio.
- Cada contribución futura debe referenciar una recepción confirmada y su entrega; para una entrega histórica recibida por el endpoint anterior, que no tiene fila de recepción, la fuente debe identificar explícitamente la entrega histórica. Nunca crear una recepción ficticia ni contar simultáneamente esa fuente histórica y nuevas recepciones para la misma entrega.
- La proyección de dominio `IndividualCustody` suma exclusivamente contribuciones verificadas que recibe como entrada y conserva sus referencias. `unaccounted` significa recibido menos salidas o novedades ya atribuidas; **no es saldo físico comprobado, disponibilidad sanitaria, saldo apto para consumo ni inventario offline**. El cálculo no descubre aplicaciones, frascos abiertos ni eventos omitidos.
- El servicio futuro debe verificar institución, custodio, lote y procedencia en la base; asociar cada salida a fuentes de forma trazable, impedir duplicados y cantidades negativas con transacciones y bloqueos, y mantener idempotencia y permisos. El cálculo puro no aporta esas garantías ni prueba la autenticidad de sus argumentos.
- La asignación de devoluciones y novedades históricas a recepciones individuales aún no está definida: el modelo actual registra esas novedades por entrega, no por recepción. No repartirlas arbitrariamente ni activar la proyección sobre datos reales hasta diseñar una transición auditable, una estrategia de evidencia para registros históricos y pruebas de concurrencia en PostgreSQL.
- No hay nueva tabla, migración, API, saldo operativo ni conexión con cierre, aplicaciones u offline en esta etapa. La proyección no representa custodias de punto o equipo y no concede permisos.

#### Prototipo de persistencia aditiva (solo pruebas)

El archivo `services/api/src/test/resources/inventory/individual_custody_candidate.sql` **no es una migración Flyway**. Propone una identidad de custodia por institución, vacunador y lote, y una relación de procedencia a nivel de entrega. Sus claves compuestas de prueba impiden vincular una entrega a otra institución, lote o vacunador y evitan vincular una misma entrega dos veces. Varias entregas del mismo custodio y lote pueden relacionarse con la misma custodia. Recepciones y novedades conservan sus tablas e identificadores y se consultan a través de la entrega, sin asignar arbitrariamente una novedad a una recepción ni crear saldos o movimientos.

La vinculación no equivale a recepción física ni prueba la aptitud o saldo; el esquema candidato por sí solo **no valida** permisos, institución del usuario, estado de la entrega, recepción efectiva, uso concurrente, inmutabilidad ni migración histórica. Antes de convertirlo en migración operativa se requieren diseño de autorización y ciclo de vida, restricciones reales, manejo de entregas en tránsito y correcciones, auditoría de consultas/decisiones, protección contra cambios directos, estrategia de adopción histórica sin inferencias y pruebas PostgreSQL. No se ha decidido ni ejecutado una importación automática.

`CandidateCustodyLinkService` existe solo en `src/test`: no es bean ni endpoint y usa exclusivamente las tablas candidatas. El prototipo exige permiso de escritura, institución, custodio activo de esa institución y recepción positiva respaldada por sus registros o por una entrega completa sin filas de recepción; comprueba cantidades, lote y receptor, serializa por institución y entrega y reconoce reintentos idénticos. No acredita ni cambia existencias y no enlaza historia automáticamente. Sus pruebas usan H2 y un `TransactionTemplate`; la marca de recepción histórica por entrega es evidencia limitada, no prueba de conteo físico. Antes de cualquier promoción a código operativo se deben validar transacciones reales, límites de la evidencia histórica, autorizaciones y concurrencia en PostgreSQL, auditoría y adopción con el responsable institucional.

Las pruebas aisladas también cubren dos entregas con el mismo custodio y lote, recepción complementaria antes o después de vincular, reintentos y conflictos concurrentes de identificadores. Mantienen las recepciones y novedades en su entrega original y comprueban que no se crean movimientos. La prueba concurrente de recepción usa una operación JDBC sintética, no el recorrido completo de la API; no sustituye una integración PostgreSQL ni habilita consumo.

`CandidateCustodyReviewService` es otra consulta exclusiva de `src/test`: reúne para una custodia candidata las entregas ya vinculadas con sus recepciones, novedades y resoluciones originales, incluidas las regularizaciones asociadas a cada resolución, por institución y con `INVENTORY_READ`. Usa una sentencia que evita multiplicar la evidencia y no calcula saldo, atribuye novedades a recepciones ni infiere consumo o ubicación. Las entregas históricas sin recepción individual permanecen así. El resultado no incluye frascos abiertos ni aplicaciones clínicas, y no certifica completitud o aptitud. Las referencias se probaron en H2; la prueba PostgreSQL desechable incluye un escenario preparado, aún no ejecutado. No hay endpoint ni interfaz operativos.

Una prueba H2 adicional comprueba que la revisión excluya otra custodia y evidencia con institución discordante, comparando el contenido de nueve tablas antes y después. Para poner a prueba esos filtros el fixture mínimo inserta deliberadamente referencias inconsistentes que las claves foráneas reales deberían impedir; esto no valida dichas restricciones ni sustituye pruebas de aislamiento y permisos reales en PostgreSQL.

La consulta candidata también conserva, bajo cada entrega, la referencia y evidencia de su finalización candidata cuando existe. Una entrega sin ese registro no se presenta como finalizada; un cierre no elimina la custodia ni las devoluciones pendientes. La prueba H2 compara además la tabla candidata de finalizaciones sin escrituras. El escenario equivalente PostgreSQL está preparado, no ejecutado; el cierre sigue sin ser operativo.

Para conservar la trazabilidad de la vinculación, la revisión candidata incluye el actor y la fecha originales del vínculo de cada entrega, distintos del custodio. La consulta no los modifica ni los interpreta como prueba adicional de recepción física; sus pruebas son locales y la comprobación equivalente en PostgreSQL desechable sigue pendiente.

Una prueba H2 adicional revisa dos custodias del mismo vacunador en lotes distintos: cada una conserva únicamente sus entregas y evidencia, incluidas resoluciones, regularizaciones y finalización. Compara las tablas del fixture antes y después; no certifica existencia física ni sustituye PostgreSQL.

Una prueba integrada H2 procesa recepción, vinculación y cierre candidatos en una transacción y posteriormente declara una devolución mediante `CustodyEventService`. La revisión candidata conserva las referencias de recepción, cierre y devolución pendiente; el reintento de la declaración no duplica el evento ni acredita el depósito. La prueba usa autorización simulada, tablas mínimas y `TransactionTemplate`: no habilita estos prototipos ni sustituye PostgreSQL o una revisión con usuarios reales.

#### Transición propuesta para historia por entrega

1. Leer una instantánea consistente de cada entrega y sus recepciones y novedades originales, verificando institución, custodio, lote y permisos. Conservar identificadores y registros originales —incluidos actor, fecha, tipo, estado, motivo y confirmación— sin reescribirlos.
2. Mantener cada novedad como evidencia **a nivel de entrega**, no asignarla a una recepción individual si el registro original no contiene esa relación. Para la recepción histórica completa sin filas de recepción, conservar como origen la propia entrega recibida; no insertar una recepción nueva.
3. Contrastar la cantidad recibida registrada con el total de recepciones reales cuando existan; detectar duplicados, fuentes mezcladas, ámbitos discordantes, estados desconocidos o novedades superiores a lo recibido. Estos casos quedan en revisión y no producen una cifra calculada ni cambios automáticos.
4. El residuo aritmético a nivel de entrega, si las comprobaciones pasan, es únicamente **recibido registrado menos novedades registradas**, no un conteo físico, una disponibilidad, una validación sanitaria ni una prueba de consumo. Una devolución pendiente cuenta entre las novedades registradas, pero no acredita depósito; su destino y confirmación siguen siendo los del evento original.
5. Antes de persistir cualquier transición, definir cómo registrar la versión y evidencia de revisión, evitar importaciones duplicadas, tratar operaciones nuevas simultáneas, recuperar fallos y atribuir eventualmente las novedades a fuentes cuando exista evidencia. Se requiere un plan de migración reversible, permisos y pruebas PostgreSQL; no se aplica ninguna modificación histórica por esta propuesta.

El cálculo local `HistoricalCustodyTransition` comprueba cantidades y referencias proporcionadas; no certifica procedencia o integridad del historial, no guarda una auditoría nueva y no se conecta a `IndividualCustody`. La atribución a recepciones y la creación de saldo operativo permanecen desactivadas.

El backend local ofrece `GET /api/v1/institutions/{institutionId}/inventory/assignments/{assignmentId}/historical-custody-review`, sujeto a `INVENTORY_READ`, al ámbito institucional y al indicador existente de API de inventario. La consulta reúne entrega, recepciones y novedades en una sola sentencia de lectura; devuelve identificadores, cantidades, actores, fechas, notas y motivos de revisión, pero no devuelve la cifra aritmética del cálculo ni ningún saldo. `assignmentOnlyReceiptEvidence` indica que la única evidencia de recepción completa es la propia entrega; no distingue si se registró antes de V33 o mediante el endpoint anterior. La vista administrativa local se abre desde las opciones de cada entrega y muestra esa evidencia en modo de lectura; las resoluciones y movimientos se consultan por separado. Es una revisión informativa de reglas limitadas, no una certificación de integridad o aptitud. No hay escritura, migración ni auditoría de acceso nueva. H2 comprobó una escritura posterior a la sentencia y anterior a la respuesta; la ejecución de la consulta y su consistencia en PostgreSQL aislado siguen sin validarse.

La consulta local de solo lectura `GET /api/v1/institutions/{institutionId}/inventory/pending-follow-ups`, también limitada por `INVENTORY_READ` y el ámbito institucional, lista devoluciones con estado `RETURN_PENDING` y cantidades de correcciones de despacho aún no regularizadas mediante V35. Una corrección no regularizada puede estar físicamente en investigación, verificada pero no apta, u otra situación: **la consulta no determina ubicación, pérdida ni aptitud**. Las devoluciones dejan de aparecer al confirmarse su destino, incluso si este es cuarentena; consultar el evento original para el historial. No crea saldos, movimientos ni decisiones; no es una bandeja de conciliación completa ni tiene paginación. La vista local de Entregas y jornadas separa ambos tipos, requiere conexión y permiso de lectura y no ofrece acciones de escritura; falta comprobarla con usuarios reales. Hay pruebas H2 y escenarios PostgreSQL preparados pero no ejecutados.

La consulta `GET /api/v1/institutions/{institutionId}/inventory/assignments/{assignmentId}/conciliation` es otra lectura administrativa sujeta a `INVENTORY_READ` y al ámbito institucional. Reúne, por entrega, cantidades despachadas, recibidas y resueltas; la diferencia registrada pendiente; pérdidas confirmadas; correcciones de despacho con sus frascos regularizados y por verificar; devoluciones declaradas aún pendientes; las resoluciones con su motivo, actor y fecha; y motivos de revisión cuando las sumas registradas no coinciden o el estado no concuerda con la diferencia. **No calcula existencia física, no acredita depósito ni aptitud sanitaria, no atribuye devoluciones a recepciones y no modifica datos.** Usa las columnas y tablas de V34 y V35, ya aplicadas en producción. La vista «Ver conciliación» se abre desde las opciones de cada entrega para administradores con lectura, muestra estados de carga, error, sin permiso y sin conexión, y advierte sus límites. Falta probarla con usuarios reales y validar la consulta en PostgreSQL.

## 3. Estados y movimientos

### Entrega: modelo propuesto

Usar una máquina de estados con transiciones validadas en el dominio y en el servidor. Es preferible comenzar con estados explícitos, entidad de dominio y casos de uso; aplicar el patrón de comportamiento **State** con una clase por estado solo si la complejidad lo justifica. No confundir una máquina de estados con un requisito de usar ese patrón concreto.

| Estado o situación propuestos | Significado y efecto esperado |
| --- | --- |
| Pendiente de recepción | El saldo salió de depósito y está en tránsito; no puede volver a entregarse. |
| Recibida | Se confirmó la recepción física y la cantidad recibida pasó a custodia. |
| Conciliada / cerrada | La revisión requerida de saldos y novedades se completó conforme a reglas por definir. |
| Cancelada o rechazada | Se conserva el historial y se registra el destino físico real de los frascos. |
| Diferencia de recepción | Se documenta la discrepancia y queda sujeta a revisión; no se inventa el destino de lo faltante. |

Esta tabla **no certifica estados o transiciones existentes**. Se acordó permitir recepción parcial: la cantidad físicamente aceptada pasa a custodia; la diferencia requiere motivo y queda pendiente de conciliación, no como pérdida ni como tránsito confirmado. Puede resolverse mediante recepción complementaria, pérdida acreditada o corrección autorizada y auditable del despacho. Antes de implementar, diseñar la matriz completa de transiciones, actores, permisos, cantidades, efectos, concurrencia e idempotencia; decidir cómo representar la situación de diferencia sin confundir el estado global de la entrega con el estado de cada cantidad.

Cuando se demuestra que el despacho registrado excedía el despacho real, el administrador documenta la corrección sin borrar el original. La diferencia no vuelve automáticamente al depósito ni se declara perdida: se investiga su ubicación. Tras conteo y evidencia, un responsable autorizado puede confirmar la permanencia física en depósito y registrar una regularización trazable. No debe registrarse como devolución ficticia algo que nunca salió. Las condiciones de aptitud se verifican antes de considerarlo disponible.

### Finalización de entrega y continuidad de custodia

Decisión acordada: la entrega es un documento de transferencia independiente del inventario del custodio. Puede finalizar administrativamente una vez confirmada la recepción y resueltas las diferencias del traslado, aunque queden frascos bajo custodia individual. Esos frascos conservan custodio y lote; posteriores aplicaciones, devoluciones o transferencias afectarían la custodia mediante operaciones propias, sin reabrir la entrega. Cerrar una jornada no mueve existencias ni obliga a devolverlas. Una diferencia sin justificar sigue identificada como incidencia y no se presume en custodia.

No se exige agregar un estado llamado `CONCILIADA`; el diseño mantendrá separados la finalización de la transferencia y el seguimiento de custodia. **Esto no está implementado**: el modelo actual limita novedades por entrega y todavía no dispone de inventario independiente por custodio ni consumo clínico integrado. `CLOSED_WITH_DIFFERENCE` significa únicamente que se resolvió la cantidad pendiente del traslado; no certifica cierre administrativo ni que una corrección haya sido verificada físicamente en depósito. Antes de implementarlo hay que precisar la evidencia de revisión, el seguimiento de las correcciones y cómo preservar trazabilidad al operar una custodia que recibe múltiples entregas. No registrar cierres ni simular saldos para anticipar ese modelo.

Decisiones posteriores: ante recepción completa y sin incidencias, el sistema podrá finalizar automáticamente la entrega; con diferencias o incidencias, el administrador revisa y autoriza la finalización una vez resueltas las diferencias del traslado. Una corrección de despacho puede permitir esa finalización con la verificación de ubicación física todavía pendiente como seguimiento independiente y visible, sin acreditar depósito. El cálculo local `TransferFinalization` solo expresa si corresponde finalización automática, revisión administrativa o mantener pendiente: no persiste cierres, no autoriza al administrador ni implementa la bandeja de seguimiento.

El prototipo `CandidateTransferFinalizationService` y `transfer_finalization_candidate.sql` existen solo en pruebas: registran una finalización única por entrega, con identidad de operación, tipo, actor, fecha y evidencia administrativa, sin modificar custodia, incidencias o saldos. Simulan reintentos y bloqueo por entrega. El caso automático es conservador y no está conectado a la recepción; la evidencia histórica sin recepción explícita requiere revisión administrativa. Se acordó que una devolución declarada pero aún no recibida físicamente no impide la finalización administrativa: sigue pendiente y visible, sin acreditar el depósito. El prototipo conserva los registros originales, pero **no implementa ni garantiza la bandeja de seguimiento físico**. No es migración, endpoint ni funcionalidad operativa; faltan integración transaccional, autorización real, revisión de incidencias concurrentes y pruebas PostgreSQL.

Las pruebas H2 incluyen decisiones contradictorias concurrentes, recepción complementaria y devolución pendiente antes o después de finalizar; verifican que persistan la evidencia y la novedad sin generar movimientos. Las escrituras concurrentes de recepción y novedad son simulaciones JDBC con bloqueo, no llamadas al flujo operativo real; no demuestran integración extremo a extremo ni seguimiento visible.

La clase `CandidateReceiptOrchestrator`, exclusiva de pruebas, combina la recepción real del servicio local con los prototipos de vinculación y finalización dentro de un `TransactionTemplate`. El vínculo interno comprueba `ATTENTION_CREATE`, institución, destinatario y una recepción positiva del mismo vacunador y entrega, y registra su identidad real; no pide ni simula `INVENTORY_WRITE`. La ruta administrativa de vinculación sigue separada y exige escritura. Las pruebas H2 comprueban permiso denegado, otra identidad o recepción, rollback, reintento y concurrencia. Una recepción inicialmente parcial se mantiene para revisión.

Es solo un diseño experimental: el método interno está en `src/test`, no es bean ni endpoint. El orquestador emite un comprobante interno de uso único únicamente después de procesar la recepción —incluido un reintento válido—, lo vincula al hilo y recurso transaccional, y lo invalida al terminar; no se puede construir desde el llamador ordinario. Las pruebas rechazan uso duplicado, después de commit o rollback y en una transacción `REQUIRES_NEW`. Además, el vínculo vuelve a verificar el registro de recepción y su destinatario. El observador del comprobante es un gancho exclusivo de pruebas, no una interfaz de seguridad operativa. Antes de promoverlo se necesita revisar la encapsulación real, reintentos e identidades, seguridad, límites transaccionales y PostgreSQL. No habilita sincronización offline ni concede permisos administrativos.

### Libro de movimientos

Los estados no sustituyen el registro de cantidades. Conservar movimientos trazables con lote, unidad, cantidad, origen, destino, actor, fecha y referencia a la operación; por ejemplo, depósito → tránsito → custodia, y devolución, cuarentena o pérdida según corresponda. Un cambio de estado y sus movimientos deben confirmarse de forma coherente y atómica.

Usar operaciones con identificadores estables e idempotencia y consultar su estado ante una respuesta incierta. Evitar saldos negativos automáticos, duplicados y modificaciones silenciosas del historial. No se exige adoptar *event sourcing* completo: un libro de movimientos y auditoría no implica reconstruir todo el sistema desde eventos.

## 4. Primera integración clínica y logística: online

### Trazabilidad objetivo

Vincular, cuando corresponda y con identidad verificable:

**Aplicación clínica → vacuna → producto/presentación → lote → entrega o custodia de origen.**

Mostrar al vacunador su saldo por vacuna, presentación y lote. En el flujo normal integrado, la aplicación clínica y su efecto logístico deben quedar coordinados en el servidor: no registrar uno como exitoso y perder silenciosamente el otro. Definir el límite transaccional real y las reglas de recuperación antes de implementar.

### Monodosis y multidosis

- En una presentación monodosis, una aplicación puede corresponder al uso de un frasco, sujeto a la presentación real y a las reglas aplicables.
- En multidosis, abrir un frasco afecta el saldo de frascos cerrados; las aplicaciones se relacionan con las dosis de un frasco abierto, no con un frasco nuevo por cada aplicación.
- El saldo nominal de un frasco abierto **no demuestra** que sea seguro o apto para uso. Identidad, vencimiento, cadena de frío, tiempo tras apertura, condiciones de uso y descarte dependen de producto y protocolos vigentes.
- Definir identificación y apertura de frascos, responsable, dosis remanentes, descartes, correcciones y tratamiento de frascos abiertos antes de automatizar. Validar con el responsable PAI y las fuentes oficiales aplicables.

### Conservación de frascos abiertos

Un frasco abierto no tiene que agotarse ni descartarse automáticamente al terminar una jornada. Si el producto, el fabricante y los lineamientos vigentes lo permiten, y se cumplen las condiciones sanitarias y de conservación, puede conservarse para su uso posterior. De lo contrario se aísla, evalúa o descarta conforme al protocolo.

- **Conservado es una condición operativa de un mismo frasco abierto**: no crea otro frasco ni reinicia la fecha u hora de apertura o reconstitución. Una jornada puede terminar sin cerrar el frasco.
- Registrar identidad individual del frasco abierto, lote y presentación, apertura y, cuando corresponda, reconstitución, custodia o ubicación, aplicaciones vinculadas, remanente nominal y novedades. Precisar cómo identificar físicamente el frasco y traspasar su custodia antes de implementarlo.
- Identificación acordada para la primera versión: UUID técnico y código corto visible generado por la app, que el personal anota en una etiqueta o soporte sin cubrir el etiquetado original. El vacunador selecciona el frasco en la app sin tener que escribir el código; la etiqueta conserva además los datos exigidos por el protocolo. Un QR queda como opción futura. Aún hay que definir unicidad del código visible, selección segura, concurrencia y traspasos antes de construirlo.
- Al final de la jornada, ofrecer registrar su conservación o descarte; la conservación requiere constatar las condiciones aplicables, no solo la existencia de dosis nominales restantes. Al retomar, presentar los frascos abiertos compatibles para evaluar su uso antes de abrir otro, sin sustituir el criterio sanitario.
- Configurar y versionar las reglas aplicables por producto y presentación, incluyendo fabricante, apertura o reconstitución, vencimiento y condiciones de conservación. No aplicar un plazo universal ni incorporar como regla automática un plazo orientativo sin validación documental y sanitaria vigente.
- Calcular y mostrar el límite de uso conforme a las reglas validadas y el vencimiento aplicable. Si el límite se cumple, bloquear nuevas aplicaciones vinculadas al frasco y solicitar su gestión según protocolo. Registrar fechas y horas con zona horaria inequívoca; resolver qué hacer cuando falta información, no hay regla validada o existen datos contradictorios. No asumir aptitud.
- Ante sospecha de ruptura de cadena de frío u otra condición que comprometa la seguridad, bloquear preventivamente su uso hasta una evaluación autorizada; registrar la decisión y su fundamento. No presumir que toda incidencia permite recuperar el producto.
- Al descartar, registrar el frasco y las dosis nominales remanentes como desperdicio, por separado de las aplicaciones. El descarte debe ser trazable y no reutilizable; no se registran aplicaciones ficticias.

Ejemplo ilustrativo: un frasco de 10 dosis con 4 aplicaciones tiene 6 dosis **nominales** sin utilizar; podrían conservarse únicamente si el frasco cumple las condiciones aplicables, o registrarse como desperdicio si debe descartarse. De 100 frascos recibidos podrían quedar 90 cerrados, 8 abiertos y 2 descartados, pero la aptitud de los 8 abiertos y las dosis administradas o desperdiciadas se controlan por separado. Estos ejemplos no representan datos reales.

Los tiempos orientativos mencionados para vacunas líquidas o reconstituidas, incluida la referencia a la Circular 026 de 2017, requieren verificar el documento, su vigencia, alcance, ficha del fabricante y protocolo institucional antes de convertirse en reglas. No se ha verificado aquí un plazo sanitario específico.

### Conciliación básica

En la primera integración online, ofrecer consulta por lote de frascos recibidos, cerrados en custodia, abiertos, devueltos y novedades, y mostrar por separado aplicaciones y dosis descartadas. No comparar ni sumar frascos y dosis como si fueran la misma unidad. El cierre formal exige reglas adicionales sobre frascos abiertos y diferencias.

Ejemplo ilustrativo **solo monodosis**: de 50 frascos recibidos, 35 utilizados, 10 devueltos y 3 descartados dejan 2 por justificar en el cálculo. Si esos 2 siguen físicamente en custodia, no son necesariamente una pérdida; hay que contrastar saldo esperado y conteo físico. El ejemplo no modifica datos reales.

## 5. Aplicación con incidencia logística

La primera integración debe incluir una vía excepcional y una bandeja administrativa de **Pendientes de conciliación**:

1. El vacunador documenta la aplicación efectivamente realizada. Si no hay inventario utilizable asociado, el sistema ofrece registrar con incidencia logística, sujeto a permisos.
2. Solicitar motivo obligatorio —por ejemplo, entrega no registrada, error de inventario o incidencia operativa— e identificación del lote físico cuando se conozca. Si se desconoce, conservar esa ausencia como incidencia de trazabilidad; no crear un lote ficticio.
3. Guardar la aplicación clínica y la incidencia vinculada sin generar existencias ni saldo negativo automático. Dejar claro que el consumo logístico está pendiente.
4. El administrador revisa la evidencia: puede vincular a existencias reales, registrar entradas o entregas omitidas si están justificadas, o documentar la diferencia sin resolver. El vacunador no adquiere permisos de ajuste central por usar esta excepción.
5. Conciliar sin recrear la aplicación ni descontar dos veces. Registrar actor, motivo, evidencia disponible, fecha, decisiones y efectos.

La captura excepcional documenta un hecho clínico; no sustituye la verificación previa de identidad, vencimiento y condiciones de uso ni autoriza administrar una vacuna sin ella. Deben definirse los datos clínicos obligatorios, permisos específicos y tratamiento de lote desconocido con los responsables clínicos y la normativa vigente.

Decisión adicional: si una aplicación **ya ocurrió** y el lote físico no se conoce, conservar el hecho clínico mediante incidencia pendiente, señalar que el vencimiento no es verificable y no generar consumo automático. Esto no autoriza administrar sin las verificaciones previas. Un lote identificado como vencido debe bloquear nuevas aplicaciones; la implementación de esta distinción requiere integrar el registro clínico y validar el procedimiento excepcional.

### Dimensiones de estado independientes

| Registro clínico | Conciliación logística |
| --- | --- |
| Registrado | Pendiente, conciliado o requiere revisión. |
| Corregido o anulado mediante procedimiento autorizado | Requiere evaluar sus efectos logísticos. |

No marcar una atención clínicamente incompleta solo porque la logística siga pendiente. Corregir o anular una aplicación **no devuelve automáticamente** un producto al saldo: puede haberse utilizado o descartado. Definir una transición y revisión logística trazables. La terminología y las transiciones exactas de ambas dimensiones quedan pendientes de diseño detallado.

## 6. Fases y límites

1. **Diseño detallado y seguridad:** revisar implementación actual, matriz de estados y permisos, modelo de presentación/lote/custodia, migración, concurrencia e idempotencia. Validar reglas sanitarias y conciliación con responsables PAI.
2. **Experiencia y separación de módulos:** tarjetas y detalle de inventario, retirar zonas fijas, acceso independiente y pestañas de entregas/jornadas, preservando operaciones existentes y CSV. Definir orden de entrega para no ocultar funcionalidades.
3. **Primera integración online:** vínculo clínico-logístico, consumo normal por presentación y lote, saldo de custodia, conciliación básica, excepción y bandeja administrativa. Requiere resolver primero las reglas de multidosis y límites transaccionales.
4. **Conciliación avanzada:** conteos físicos, diferencias, ajustes autorizados y cierre formal con auditoría.
5. **Integración offline futura:** aplicación y consumo en una transacción local; identificadores estables y sincronización idempotente. Diseñar conflictos, concurrencia entre dispositivos y custodias compartidas, orden, rechazos, recuperación y evidencia antes de habilitar.
6. **Futuro:** importación masiva con validación y vista previa, y una sección coherente de informes diarios/mensuales y exportaciones. El CSV general existente se conserva donde está hasta acordar su traslado; no se prometen filtros o formatos aún no implementados.

Las fases ordenan dependencias, no constituyen fechas ni autorización de despliegue. En la fase actual permanecen desactivados consumo offline, reservas y claves de instalación. Cualquier cambio de esquema o puesta en producción requiere revisión, pruebas y aprobación operativa; no se reconstruyen saldos históricos por suposición.

## 7. Decisiones pendientes antes de construir

- Matriz de transiciones de entrega, recepción parcial, rechazo, cancelación, diferencias y cierre; destino físico de cada cantidad y permisos asociados.
- Reglas y evidencia para regularizar entradas o entregas omitidas, y política para diferencias no resueltas.
- Responsable principal, integrantes y permisos de custodias compartidas; evolución desde entregas a personas.
- Identidad de producto/presentación y frasco abierto; reglas clínicas y operativas validadas para apertura, reconstitución, conservación, bloqueo preventivo, uso, descarte y correcciones, incluidos datos faltantes y manejo de horas.
- Detalle de la excepción clínica: lote desconocido, datos mínimos, autorización, plazos y tratamiento de correcciones o anulaciones.
- Definiciones de saldos por estado, consulta eficiente, corte temporal y cifras de progreso de jornadas.
- Estrategia de migración de registros existentes, transacciones, identificadores idempotentes, concurrencia y recuperación ante fallos.
- Modelo offline y conflictos multidispositivo antes de activar cualquier consumo sin conexión.
- Pruebas en staging, permisos con sesiones reales, conciliación física y aprobación de despliegue.

### Decisiones operativas concretas pendientes

Estas preguntas no habilitan funcionalidades ni representan decisiones ya tomadas:

**Custodia compartida**

1. Decidido para una fase futura: responsable principal obligatorio, asignado o sustituido por administrador con conteo y entrega documentados.
2. ¿Qué integrantes pueden recibir, registrar novedades y efectuar traspasos, y qué operaciones requieren autorización del responsable o administrador?
3. ¿Qué ocurre al cambiar integrantes o responsable con frascos aún bajo custodia? Definir aceptación, conteo y registro del traspaso, sin alterar el historial.
4. Decidido: un único titular de custodia; no permitir descuentos offline independientes sobre el mismo saldo. Inicialmente se priorizan entregas individuales físicamente separadas.

**Cierre y conciliación**

1. Decidido: cierre automático tras recepción completa sin incidencias; con diferencias o incidencias, revisión y autorización administrativa. Quedan por definir datos y evidencia concretos de la revisión.
2. Decidido: una corrección de despacho con ubicación por verificar y una devolución no confirmada no impiden por sí solas finalizar tras revisión administrativa; exigen seguimiento visible independiente y no acreditan depósito. Las diferencias de traslado sin resolver impiden finalizar. Falta implementar el seguimiento posterior.
3. Decidido: la entrega puede finalizar manteniendo custodia activa; terminar una jornada no implica devolución ni cierre automático.
4. ¿Qué reglas de reapertura o corrección, permisos y auditoría se aplican si aparece evidencia posterior? El consumo y los frascos abiertos requieren además validación sanitaria antes de cerrar su conciliación.

## 8. Contraste inicial con la implementación

Revisión estática del código, no certificación de operación ni de datos reales:

- `InventoryService.dispatch` bloquea el lote y registra entrega, movimiento y descuento en una transacción. En código local se añadió recepción parcial y complementaria mediante identificador idempotente, conservando el endpoint previo para recepción completa. V33–V37 están aplicadas en producción (16/11/2026): V33 se restauró exactamente al contenido aplicado tras detectarse una edición posterior que impedía arrancar; V34–V37 se aplicaron y validaron con Flyway, y la base quedó en la versión 37. La guarda de longitud de `difference_note` quedó en V37. Las transacciones y la concurrencia de estos flujos siguen pendientes de prueba PostgreSQL/staging.
- Las devoluciones y novedades se representan aparte y el límite de declaraciones de una entrega parcial es la cantidad recibida. Una devolución vuelve al saldo de depósito solo tras confirmación y destino explícito.
- El código local registra resoluciones administrativas de diferencia por pérdida confirmada o corrección de despacho, con motivo, responsable, fecha y UUID de reintento. La corrección no acredita automáticamente el depósito. Una operación posterior permite regularizar una parte o toda la corrección tras confirmar conteo físico y aptitud, registrando un movimiento `DEPOT_CORRECTION`, nunca una devolución; no acepta lote vencido ni exceso de cantidad y mantiene historial e idempotencia. Las migraciones V34 y V35 están aplicadas en producción; su concurrencia y transacciones siguen pendientes de prueba PostgreSQL/staging. Cancelación y cierre conciliado integral siguen pendientes.
- `available_vials` es saldo registrado del lote. La consulta `listLots` no filtra vencimiento. Se acordó rechazar nuevas entregas cuando la fecha local de Colombia sea posterior al vencimiento, sin ocultar el lote ni impedir su gestión administrativa. El código local incorpora ese control en `dispatch`, pero no está desplegado ni verifica condiciones de conservación. El saldo no demuestra aptitud sanitaria y se debe verificar físicamente antes de entregar.
- También se acordó bloquear aplicaciones con lotes vencidos, incluso en el futuro flujo offline y en la sincronización. No está implementado: la integración clínica y la identificación fiable del lote requieren diseño y validación; no se debe interpretar el bloqueo de entrega como protección de aplicaciones. Las alertas configurables previas al vencimiento quedan pendientes.
- Los identificadores únicos y transacciones protegen contra duplicar ciertas escrituras, pero una colisión no equivale necesariamente a una respuesta idempotente exitosa. Además de la recepción completa y confirmación idéntica de devolución, el código local reconoce reintentos idénticos de declaraciones de custodia, incluso después de confirmar una devolución; reutilizar el identificador con otros datos se rechaza. La concurrencia se probó en H2, pendiente de verificar en PostgreSQL aislado. Revisar el contrato de las demás operaciones y la consulta de estado ante resultado incierto.
- Las entradas y despachos independientes reconocen localmente reintentos idénticos del mismo movimiento tras verificar autorización, institución, actor y datos; en despachos también se comparan entrega, destinatario y jornada. El despacho repetido devuelve el estado actual de la entrega y no constituye una nueva entrega. Los tiempos nuevos se guardan con precisión de microsegundos.
- La creación local de lote, sola o combinada con entrada, registra el tipo de operación para reconocer reintentos sin inferir que un lote y una entrada antiguos se crearon juntos. Los lotes históricos sin esa evidencia no se reconocen automáticamente como reintentos. La migración V36 está aplicada en producción; la concurrencia de estas operaciones aún requiere PostgreSQL aislado y las pruebas actuales usan H2.
- El historial de asignaciones no representa por sí solo la custodia actual: hay devoluciones y novedades, y todavía no hay consumo clínico integrado. No sumarlo como saldo de custodia sin definir y comprobar la fórmula y sus límites.
- El modelo actual de lote registra dosis nominales por frasco; no modela un frasco abierto individual ni su conservación. No habilitar descuento clínico multidosis hasta resolver las reglas y validar su implementación.
