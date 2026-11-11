# Auditoría técnica y alcance simplificado

**Estado:** revisión enfocada mediante lectura de código; propuesta preliminar, no esquema definitivo. No se ejecutaron pruebas, se inspeccionaron datos reales ni se validaron procedimientos sanitarios. Complementa, sin sustituir, los demás documentos.

## Criterio de diseño

Reutilizar lo que funciona y mantener el formulario clínico sencillo. La solución se diseña de forma genérica porque no se dispone actualmente de una institución para entrevistar; eso no demuestra que sea un proceso estándar PAI ni que cumpla la normativa. Las reglas por producto deben contrastarse con fuentes oficiales vigentes y responsables competentes antes del uso real.

## Lo que ya existe y podemos aprovechar

| Área | Evidencia | Implicación |
|---|---|---|
| Institución y roles | `V1__create_identity.sql`: usuario vinculado a institución; roles de administrador y vacunador; permisos `INVENTORY_READ` y `INVENTORY_WRITE` sembrados. | Reutilizar identidad y alcance institucional; comprobar autorización efectiva en endpoints y decidir acceso de consulta del vacunador a su asignación. Los permisos sembrados no implementan inventario. |
| Atención clínica | `AttentionService` usa transacciones, alcance institucional e `IdempotencyCoordinator`; `V9__create_attentions.sql` conserva dosis y snapshots. | Integrar el consumo en el registro de dosis, sin sustituir el módulo clínico. La anulación no implica devolución física automática. |
| Lote actual | `applied_doses.lot_id` es nullable y no tiene FK de inventario; `lot_number` es texto. `clinical_offline_repository.dart` incluye `lotNumber` en el comando. | No confundir texto con existencia comprobada. La selección futura necesita una referencia validada sin romper registros o clientes anteriores. |
| Escritura offline | `clinical_offline_repository.dart` usa `SyncOutboxRepository.commitLocalWrite`; `sync_outbox.dart` guarda escritura y operación en una transacción Drift. | Extender la misma transacción para registrar consumo y apertura cuando corresponda; no crear un segundo motor. |
| Sincronización | `sync_engine.dart` utiliza push/pull, dependencias, reintentos y estados; `SyncPushService` procesa cada operación por separado. `V11__enrich_processed_operations.sql` documenta operaciones procesadas. | La dosis y su consumo deben ser **una operación de negocio atómica**, no dos comandos independientes cuya aceptación parcial deje inconsistencia. Mantener rechazos visibles. |
| Dispositivo | No apareció `deviceId`, `device_id` ni `deviceIdentifier` en la búsqueda en `apps/mobile/lib`. | No se ha demostrado una identidad de dispositivo apta para cuotas exclusivas. Diseñar identificación, persistencia, recuperación y prevención de duplicación antes de prometer esa garantía. |
| Históricos | El lote histórico es texto y no prueba entradas, aperturas ni desperdicios. | Conservar atenciones; iniciar inventario con conteo físico y fecha de corte, sin inventar movimientos retroactivos. Revisar datos reales antes de migrar. |

La búsqueda de dispositivo es acotada y no prueba que no exista una identificación bajo otro nombre o fuera de esa ruta. La idempotencia existente es una base: revisar retención y concurrencia reales y añadir garantías duraderas para evitar consumos duplicados, sin asumir que el contrato documental basta por sí solo.

## Primer alcance operativo recomendado

1. **Catálogo:** adaptar la vista existente para mostrar datos y dosis maestras en solo lectura y opciones institucionales editables permitidas; proteger las restricciones también en servidor. Separar configuración de existencias.
2. **Inventario central:** producto/presentación, lote, vencimiento, entrada inicial o recepción y cantidades físicas.
3. **Jornadas:** crear actividad con fecha, lugar y participantes; consultar entregas y atenciones relacionadas y finalizarla sin cerrar custodias. Se incluye en la primera versión, pero no se exige para atención rutinaria.
4. **Asignación individual:** entregar frascos completos por lote a un vacunador, desde una jornada o sin ella, confirmar recepción y registrar autorización local exclusiva para un dispositivo. Internamente puede haber más de un estado; la interfaz debe mostrar acciones comprensibles.
5. **Aplicación:** conservar el formulario; ofrecer lotes de la asignación y asociar el consumo a la dosis. Para multidosis, apertura asistida y control del remanente sin selección de frasco en cada atención. No tratar capacidad nominal como disponibilidad sanitaria.
6. **Novedades y devolución:** registrar pérdida o incidencia, inmovilizar las cantidades afectadas cuando corresponda y confirmar físicamente lo devuelto antes de sumarlo al disponible. Una anulación clínica no devuelve automáticamente existencias.
7. **Consulta básica:** mostrar existencias y movimientos, responsables, pendientes de sincronización y diferencias. Excel/PDF y conciliación avanzada pueden añadirse después; los procedimientos manuales transitorios deben ser explícitos antes de uso real.

La custodia individual es la primera modalidad operativa, no una afirmación sobre todas las instituciones. Dejar para después equipos o puntos compartidos, frascos compartidos entre dispositivos, sensores, automatizaciones complejas y adaptación/habilitación de la vista web. No es necesario construir hoy tablas o interfaces para posibilidades futuras que no estén justificadas.

## Orden seguro de trabajo

1. Revisar en ejecución la app, contratos, datos y cambios locales existentes; concretar el modelo mínimo y la estrategia de identificación de dispositivo.
2. Diseñar migraciones **aditivas** y compatibles con datos históricos y clientes anteriores; definir política de activación por institución y contingencia antes de exigir stock.
3. Adaptar la configuración de catálogo existente; probar restricciones institucionales tanto en interfaz como en servidor.
4. Implementar entrada de existencias, jornadas y asignaciones con control transaccional de concurrencia; probar que no se entregue dos veces el mismo saldo y que una asignación no requiera jornada.
5. Extender el flujo offline y el comando de dosis para aplicar consumo e idempotencia de forma atómica en SQLite y servidor. Probar reintentos, fallos parciales, desconexión y dispositivo perdido.
6. Completar devolución, incidencias y consulta; validar protocolos sanitarios, recuperación y operación completa antes de habilitar restricciones de inventario en uso real.

Las fases son incrementos de desarrollo, no autorización para operar un sistema logístico incompleto. Hasta que la transición y contingencia estén listas, no se debe bloquear el flujo clínico actual por ausencia de inventario. Falta decidir el comportamiento para aplicaciones reales que no puedan asociarse a una cuota válida y el tratamiento de datos registrados por clientes antiguos o recibidos tarde.

## Verificaciones mínimas antes de activar

- Dos asignaciones simultáneas no comprometen más stock del disponible; cuotas de dispositivos no duplican existencias.
- Aplicación, apertura cuando aplique, consumo local y outbox son atómicos; el servidor confirma consumo y aplicación en la misma transacción; reintentos no duplican efectos.
- Lote, cuota, actor e institución son coherentes; una cuota no descargada no puede usarse offline.
- La devolución requiere recepción; diferencias, cuarentenas, pérdidas y anulación quedan trazables.
- Históricos siguen visibles; respaldos, actualización de clientes y datos reales se verifican antes de migrar.
- Una jornada permite asociar entregas y atenciones; puede finalizar sin devolver existencias ni cerrar custodias, y se permite atender o asignar sin jornada.
- Apertura, conservación y descarte se basan en lineamientos y ficha del producto vigentes; no se han validado en esta revisión.
