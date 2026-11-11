# Modelo mínimo y asignación offline

**Estado:** propuesta técnica para revisar antes de implementar; no es una migración ni modifica los contratos aprobados. Nombres y estructura de tablas son ilustrativos. La aplicación sigue funcionando como ahora hasta que la solución completa, la transición y la contingencia estén listas.

## Principio

Reutilizar catálogo, usuarios, atenciones, transacciones Drift, outbox, sincronización y autorizaciones existentes. Agregar solo las piezas logísticas necesarias para inventario, jornadas y entregas individuales. No construir un segundo motor de sincronización ni depender de una jornada para atender.

## Modelo funcional mínimo

| Concepto | Datos esenciales y relaciones propuestas | Para qué sirve |
|---|---|---|
| Presentación | Vacuna existente, producto/fabricante cuando corresponda, tipo de envase y capacidad nominal histórica. | Diferenciar dosis clínicas de frascos; gobierno y compatibilidad del producto pendientes. |
| Lote | Institución, presentación, número y vencimiento. | Identificar existencias sin confundir el lote textual histórico con stock comprobado. |
| Movimiento y saldo | Lote, responsable o ubicación, unidad física, tipo, cantidad, fecha, actor y referencia al hecho; saldo derivado o proyección verificable. | Registrar entradas, entregas, devoluciones, incidencias y consumos sin modificar la historia. Los saldos no sustituyen el historial. |
| Jornada | Institución, nombre, fecha o periodo, lugar, estado y participantes. | Organizar la actividad. Su creación no mueve inventario; finalizarla no cierra custodias. |
| Entrega y líneas | Institución, origen, vacunador responsable, jornada opcional, estado y líneas por lote y frascos. | Registrar asignación y recepción; desde una jornada o directamente. Reposiciones y devoluciones son hechos diferenciados. |
| Instalación registrada | Identificador de instalación, institución, estado y vínculo autorizado con usuario; datos mínimos para registrar y revocar. | Distinguir dónde se ha concedido una reserva. No usar identificadores permanentes de hardware ni asumir que un UUID prueba identidad. |
| Autorización offline y líneas | Custodia, instalación, usuario, generación, estado y cuota exclusiva por lote. | Reservar parte de existencias ya entregadas; no crea stock ni sustituye la custodia física. |
| Apertura multidosis | Lote, custodia, autorización, fecha de apertura, capacidad nominal histórica, aplicaciones y cierre/novedad. | Relacionar las aplicaciones con un frasco abierto identificable sin seleccionar uno en cada atención. |
| Incidencia/devolución | Lote, cantidad y unidad, responsables, motivo, estado y fechas; recepción cuando aplique. | Registrar pérdida, inmovilización o retorno físico sin confundirlos con una aplicación. |

No es necesario que cada concepto sea una tabla o pantalla separada. El diseño final debe determinar las claves, proyecciones y restricciones mínimas; no crear estructuras genéricas para custodias compartidas que aún no se utilizarán.

## Relación con lo existente

- Mantener `vaccines`, `vaccine_options` e `institution_vaccines` como catálogo y configuración, no como saldo.
- Ampliar `attentions` con una relación **nullable** a jornada para las nuevas atenciones cuando corresponda. Las atenciones antiguas y rutinarias pueden no tenerla. La selección recordada es una propuesta local visible, modificable y no un registro automático irrevocable.
- Mantener `applied_doses.lot_number` y los snapshots históricos. Para aplicaciones nuevas asociar el lote físico y, cuando aplique, apertura y consumo. Antes de añadir FK o restricciones, inspeccionar datos y compatibilidad; no enlazar históricos por coincidencia textual.
- Registrar consumo junto con `REGISTER_APPLIED_DOSE`, sin un segundo comando independiente que pueda aceptarse por separado. En móvil, dosis, apertura si corresponde, saldo local y outbox se guardan en la misma transacción; en servidor, dosis, movimiento, cuota e idempotencia se confirman o revierten juntos.
- Migraciones y campos nuevos deben ser aditivos y contemplar clientes antiguos y operaciones pendientes. Fecha de corte y conteo físico inicial no producen consumos retroactivos.

## Identificación y reserva offline: propuesta mínima

La autorización clínica offline del [ADR-005](../decisions/ADR-005-autenticacion-y-autorizacion-offline.md) se basa en usuario desbloqueado y ventana de validación; **no reserva inventario ni identifica por sí misma una instalación**. Las nuevas reservas serían adicionales y seguirían sujetas a esa política.

1. Con conexión, el vacunador inicia sesión en la instalación que usará. Se propone generar un identificador aleatorio de instalación y registrar su vínculo con usuario e institución en el servidor.
2. Para autenticar la instalación, evaluar un par de claves generado localmente: clave privada no exportable en almacenamiento seguro del sistema cuando la plataforma lo soporte, clave pública registrada con el usuario autenticado. Si no existe esa garantía, no presentar el mecanismo como protección contra clonación; definir alternativa y nivel de riesgo aceptable antes de habilitarlo.
3. La entrega física se confirma. El servidor reserva atómicamente cantidades por lote para esa instalación y generación, verificando institución, usuario, custodia y stock no comprometido. Una cuota no es inventario adicional.
4. El dispositivo descarga y guarda la autorización y sus saldos de manera persistente antes de operar sin conexión. La confirmación de descarga puede estar pendiente de llegar al servidor: este debe seguir considerando comprometida la cuota, incluso si no recibió la confirmación.
5. Cada aplicación local válida reduce la cuota local y genera el comando clínico con referencias a autorización, generación y lote. La validación del usuario y de la ventana offline sigue aplicando. La app debe mostrar el saldo disponible y operaciones pendientes, sin exponer conceptos técnicos innecesarios.
6. Al reconectar, el servidor valida la operación, su autor, alcance, autorización y generación, aplica el consumo atómicamente y conserva la idempotencia. Los rechazos quedan visibles para revisión; una vacunación real no debe desaparecer por un conflicto.

### Límites de seguridad y consistencia

- Un UUID es un identificador, **no un secreto ni prueba de posesión**. Una clave vinculada a hardware puede reducir clonación, pero no garantiza por sí sola protección completa; requieren diseño de desafío/firma, almacenamiento y verificación específicos por plataforma.
- El servidor no observa consumos mientras el dispositivo está desconectado. Mantener comprometida la cuota completa pendiente hasta recibir y conciliar los eventos; no volver a entregarla solo porque venció un plazo o no llegó una confirmación.
- Si se revoca una instalación, está perdida o se reinstala, no liberar automáticamente su reserva. Contar y resolver bajo autorización; los eventos tardíos se conservan y revisan, incluso después de una nueva generación. Una reinstalación se trata como una instalación nueva salvo procedimiento de recuperación validado.
- Un respaldo o clon de datos locales, relojes manipulados, restauración, cambio de usuario y pérdida de clave requieren tratamiento explícito y pruebas. Ningún diseño offline puede conocer una revocación remota que aún no recibió el dispositivo.
- La cuota exclusiva para una instalación no debe confundirse con frasco compartido: el MVP no comparte frascos abiertos entre dispositivos. Las reglas sanitarias aplicables deben validarse por producto.

## Jornada en la atención

Propuesta: el vacunador selecciona una jornada disponible o «sin jornada»; la selección se recuerda y se muestra en las siguientes atenciones, con opción de cambiarla o quitarla. Guardar la referencia con la atención, no inferirla después desde la entrega. Deben definirse vigencia local, actualización y tratamiento de una jornada finalizada remotamente mientras el dispositivo estaba desconectado. No asignar silenciosamente nuevas atenciones a una jornada que el dispositivo sabe finalizada.

## Pruebas necesarias antes de habilitar

1. Dos entregas o reservas concurrentes no comprometen más existencias que las disponibles; recepción diferente a la enviada queda visible.
2. El dispositivo no consume una reserva no descargada; perder la confirmación de descarga no libera la cuota en servidor.
3. Fallo a mitad de una transacción y reintentos no duplican dosis, aperturas ni consumos; probar servidor y almacenamiento local.
4. Pérdida, reinstalación, clon/restauración y eventos tardíos no provocan reasignación silenciosa ni pérdida de atenciones.
5. Jornada opcional y recordada de forma visible; sin asociación automática a jornada conocida como finalizada; finalizar no modifica saldos.
6. Históricos y clientes antiguos continúan funcionando durante la transición; probar recuperación y operaciones pendientes antes de habilitar nuevas restricciones.
7. Verificar aislamiento institucional, permisos, ventana offline, incidentes y conservación conforme a reglas validadas.

## Decisiones abiertas

Tecnología de claves por plataforma y recuperación; cómo comprobar posesión al sincronizar; revocación y resolución de eventos tardíos; activación progresiva y compatibilidad con clientes antiguos; fuente y gobierno de presentaciones; reglas sanitarias de apertura y descarte; contingencia para aplicación real sin cuota; cierre remoto de jornadas. No habilitar uso real con reglas sanitarias inventadas ni exigir stock antes de aprobar estas decisiones y probar el flujo completo.
