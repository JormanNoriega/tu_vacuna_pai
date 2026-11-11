# Informes, fases y decisiones pendientes

**Estado:** planificación preliminar. No iniciar implementación o migraciones sin aprobar las decisiones pendientes y validar procedimientos PAI.

## Informes

El registro diario existente es un informe clínico de vacunadores. Los siguientes informes logísticos son nuevos:

| Informe | Contenido mínimo | Formato objetivo |
|---|---|---|
| Comprobante de entrega | Identificador, responsables, fechas, vacunador/custodia, lote, presentación, cantidades enviadas y recepción. | PDF y Excel |
| Comprobante de devolución | Identificador, responsables, lote, cantidades y condición al recibir. | PDF y Excel |
| Existencias | Vacuna, producto, lote, vencimiento, ubicación/custodia y estado. | Excel; PDF cuando sea útil |
| Asignaciones | Entregas, reposiciones, estado de recepción y cuotas pendientes. | Excel/PDF |
| Consumo y desperdicio | Aplicaciones, pérdidas y descartes separados por lote y contexto. | Excel/PDF |
| Movimientos | Entradas, salidas, consumos, ajustes y responsables. | Excel/PDF |
| Jornada y conciliación | Planificado frente a entregado, aplicado, desperdiciado, devuelto, saldo en custodia y diferencias. | Excel/PDF |

Cada informe debe indicar fecha de corte, alcance y estado de sincronización. Un cierre es provisional si hay pendientes relevantes; el cierre definitivo requiere los controles y resolución aprobados. Una custodia que continúa abierta se informa como tal. No afirmar que los formatos son oficiales o sustituyen PAIWEB sin validación.

Automatizar alertas de saldos bajos, vencimientos, cuarentena, entregas o devoluciones pendientes, diferencias y sincronización atrasada. El dashboard debe distinguir saldos confirmados de datos locales pendientes. El conteo de aplicaciones no es por sí solo una medida de calidad del vacunador.

## Fases propuestas

Las jornadas están dentro del primer alcance, no de una fase futura opcional. La adaptación y habilitación para navegador web se posponen; las fases siguientes se refieren a la aplicación existente. Los informes logísticos avanzados pueden añadirse después de las consultas básicas.

1. **Validación y diseño:** recorrido de la app real, inspección de datos y revisión de fuentes oficiales. Entrevistar personal PAI cuando sea posible; su ausencia no convierte las suposiciones en reglas verificadas.
2. **Configuración de catálogo:** separar visualmente catálogo e inventario; dosis oficiales de solo lectura; opciones institucionales claras.
3. **Inventario central:** producto, presentación, lote, recepción, estados, movimientos y saldos.
4. **Asignaciones y jornadas:** entrega y recepción, custodia, asignación rápida y jornada opcional; preparar autorización offline desde la asignación.
5. **Consumo y offline:** apertura semiautomática, aplicaciones y movimientos atómicos, sincronización, idempotencia y contingencias aprobadas.
6. **Devolución y conciliación:** remanentes, conservación, diferencias, custodia entre jornadas y cierre provisional/definitivo.
7. **Informes y alertas:** ampliar infraestructura existente con reportes logísticos Excel/PDF.
8. **Evolución de catálogo:** publicación/versionado y tratamiento explícito de cambios durante desconexión, coordinados con las fases anteriores.

Son dependencias de diseño, no una autorización para habilitar producción incompleta. No se debe bloquear el registro clínico existente por falta de inventario hasta tener listo el trabajo offline, transición y contingencia aprobados.

## Criterios de aceptación esenciales

- Administrador institucional no puede crear ni modificar dosis maestras; opciones locales no alteran el catálogo global.
- Dos entregas simultáneas no pueden comprometer más existencias que las disponibles.
- El dispositivo no usa una asignación que aún no recibió y guardó localmente; el servidor distingue confirmación pendiente.
- Aplicación y consumo quedan atómicamente registrados localmente y en servidor; reintentos no duplican efectos.
- En multidosis se sugiere un frasco abierto identificable o se confirma una apertura nueva sin obligar a seleccionar frasco en cada atención.
- Un remanente nominal no se presenta automáticamente como utilizable ni como desperdicio.
- Cuarentena, pérdidas, devoluciones y correcciones tienen responsables y trazabilidad; no se editan movimientos históricos.
- Finalizar una jornada no fuerza devolución ni cierre de custodia; el informe indica pendientes y corte.
- Se crean jornadas con fecha, lugar y participantes, se asocian entregas y atenciones, y también se permite asignar y atender sin jornada.
- Los históricos sin lote físico enlazado permanecen disponibles sin relaciones ni existencias inventadas.

## Decisiones y validaciones pendientes

1. Quién gobierna el catálogo de productos y presentaciones y cómo se autoriza su compatibilidad clínica.
2. Unidad física de consumo por producto, incluyendo si se necesita volumen u otra unidad además de dosis nominales.
3. Política operativa y sanitaria de apertura, identificación, conservación, transferencia y descarte de frascos multidosis.
4. Confirmar si limitar el MVP a un frasco abierto identificable por lote y custodia es compatible con el trabajo real.
5. Mecanismo de activación local offline y momento de confirmación visible al administrador.
6. Permisos, justificación y regularización de la contingencia sin inventario o cuota válida.
7. Procedimiento ante dispositivo perdido, autorización revocada y eventos que lleguen tarde.
8. Recepción física, diferencias, cadena de frío, permanencia de custodia y cierres parciales de varios días.
9. Tratamiento de datos históricos, `lot_id` existentes y actualización de catálogo durante desconexión.
10. Validación normativa, formatos de reporte y relación con PAIWEB por responsable PAI. No se han certificado los flujos frente a la normativa.
11. Selección y persistencia de jornada en la atención, incluido su cambio, finalización y trabajo sin conexión; se propone recordar la selección de forma visible, sin imponerla a la atención rutinaria.
