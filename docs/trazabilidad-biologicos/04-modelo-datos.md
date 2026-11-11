# Modelo de datos propuesto

**Estado:** diseño conceptual, no esquema definitivo ni migración. Los nombres son ilustrativos. Revisar el código y los datos efectivos antes de definir DDL, FK o estrategias de transición.

## Componentes

| Entidad propuesta | Datos y relaciones principales |
|---|---|
| `vaccine_products` | Producto/presentación asociado a `vaccines`: fabricante, tipo y capacidad nominal por frasco; preservar su significado histórico. |
| `inventory_lots` | Institución, producto, número de lote, vencimiento y versión. Evitar duplicados indebidos y revisar discrepancias de vencimiento. |
| Ubicación / contenedor | Representa depósito o punto. Usar un modelo que identifique inequívocamente dónde está un saldo. |
| Custodia | Responsable físico, institución, contexto y estado; puede continuar entre jornadas. |
| `inventory_balances` | Proyección por institución, contenedor/custodia, lote y estado; frascos cerrados y cantidades comprometidas. No es la única fuente histórica. |
| `inventory_movements` | Historial por lote, contenedor, tipo, cantidad, unidad, evento de negocio, actor, fechas, motivo y eventual compensación. |
| `inventory_transfers` / líneas | Documento de entrega, devolución o traslado; origen, destino, jornada opcional y cantidades preparadas, enviadas y recibidas. |
| `offline_authorizations` / líneas | Custodia, dispositivo, generación, estado y cuotas por lote. Una cuota compromete saldo, no crea stock. |
| `opened_vials` | Apertura con UUID, lote, custodia, autorización, fecha local, fecha recibida por servidor, capacidad nominal histórica y referencia física opcional. |
| Jornadas, puntos y personal | Actividad opcional; una jornada puede tener varios puntos y vacunadores. Punto, jornada y custodia son conceptos distintos. |
| Incidencias | Conservación o diferencias: cantidades afectadas, fechas, responsable, evaluación y decisión. |
| Conciliaciones / líneas | Corte, contexto, esperado, conteo, diferencia, estado y resolución. |

La decisión de representar ubicación y custodia mediante una tabla común de contenedores u otra estructura queda abierta. Debe evitar destinos ambiguos y garantizar aislamiento institucional. Estas entidades no exigen módulos o menús separados.

## Relaciones y restricciones

- Catálogo maestro `vaccines` y `vaccine_options` permanece separado de productos y existencias.
- Cada lote refiere a un producto y ámbito institucional. La identidad exacta del lote y discrepancias de vencimiento requieren validación.
- Cada saldo tiene lote, ubicación o custodia inequívoca y estado; cantidades físicas y comprometidas no negativas.
- Un movimiento tiene unidad explícita: no sumar frascos y dosis como si fueran la misma cantidad. Las correcciones enlazan movimientos compensatorios y no eliminan la historia.
- Una transferencia registra los efectos de origen, tránsito y destino vinculados a un mismo documento o evento. La recepción puede diferir del envío sin borrar la diferencia.
- La suma de cuotas activas no supera el saldo comprometible; una cuota no se autoriza simultáneamente a dos dispositivos.
- Una apertura pertenece a lote y custodia. Aplicación y consumo normal deben tener unicidad duradera para evitar duplicaciones.
- Validar coherencia de institución en todos los vínculos mediante servicios y restricciones de base de datos donde corresponda.
- Cantidades, unidades, productos, estados y referencias históricas deben permitir reconstrucción y verificación de proyecciones.

## Concurrencia y transacciones

La asignación debe validar y comprometer saldo atómicamente en PostgreSQL, mediante bloqueo de fila o actualización condicional y restricciones apropiadas. Con 20 frascos y dos solicitudes concurrentes de 15, como máximo una puede confirmar; la otra obtiene disponibilidad insuficiente. Probar concurrencia real, no confiar en la comprobación del frontend.

Recepción y movimiento; traslado y proyecciones; o aplicación, consumo e idempotencia deben confirmarse en la misma transacción correspondiente. En SQLite, aplicación, apertura confirmada si aplica, consumo, saldo local y outbox también son atómicos.

## Integración con tablas existentes

- `institution_vaccines` y `institution_vaccine_options`: conservar habilitación y opciones locales; no representan stock.
- `applied_doses`: conservar snapshots clínicos y relacionar lote, apertura, custodia y consumo cuando aplique. `dose_option_id` indica dosis de esquema, no la magnitud física de consumo.
- `applied_doses.lot_id` actualmente es nullable y no tiene FK a inventario; `lot_number` es texto. Inspeccionar datos antes de definir FK. No vincular históricos solo por coincidencia textual ni inventar movimientos retroactivos.
- Extender Drift y el outbox existentes con cuotas, lotes, aperturas, eventos y proyecciones necesarios; no diseñar un motor paralelo.
- Mantener las operaciones clínicas y logísticas visibles ante conflictos. Definir una transición que no interrumpa las atenciones actuales antes de exigir stock.

## Diseño aún pendiente

Gobierno del catálogo de presentaciones; unidad física y eventual volumen administrado; trazabilidad de cantidades afectadas por incidencias; política de frascos abiertos; compatibilidad de datos y clientes históricos; semántica de contingencia; retención e idempotencia duradera. No derivar reglas clínicas únicamente de la capacidad nominal.
