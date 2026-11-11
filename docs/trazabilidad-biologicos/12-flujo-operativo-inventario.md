# Inventario: organización operativa acordada

## Objetivo y unidades

El inventario online registra frascos completos por institución y lote. Las opciones de dosis del esquema clínico son parte del catálogo, no cantidades físicas. Las dosis nominales por frasco no demuestran disponibilidad clínica ni dosis aplicadas. No se activa consumo offline, reservas ni claves de instalación.

## Flujos

1. **Vacuna y existencias:** la ficha muestra dosis del catálogo en solo lectura y lotes institucionales. Agregar existencias permite seleccionar un lote existente o registrar uno nuevo con fabricante, número, vencimiento, dosis nominales por frasco, cantidad y motivo. La creación del lote y su entrada se confirman en una sola transacción. Registrar únicamente cantidades contadas físicamente.
2. **Asignaciones y jornadas:** el responsable entrega frascos de un lote a un vacunador, opcionalmente en una jornada. La jornada organiza actividades y no mueve existencias por sí sola. El vacunador confirma la recepción completa tras el conteo físico.
3. **Recepción y novedades:** devoluciones, pérdidas y cuarentena son eventos distintos; una devolución solo vuelve al saldo tras revisión y destino explícitos. No se infiere consumo ni descarte clínico de las entregas.
4. **Informes:** consultar y exportar datos reales autorizados por institución, diferenciando saldo actual, entradas, entregas y novedades. Identificar fecha de consulta y unidades; nunca presentar cantidades asignadas como dosis aplicadas. Filtros avanzados y formatos adicionales se incorporarán incrementalmente.

## Seguridad y operación

Las lecturas requieren INVENTORY_READ; las entradas y asignaciones INVENTORY_WRITE; la confirmación y declaración propias requieren ATTENTION_CREATE. El servidor limita por institución y actor. Los identificadores estables evitan duplicados; ante respuesta incierta se consulta el estado antes de iniciar otra operación. No se crean datos ficticios para probar en producción.

## Futuro: carga masiva

No implementada ni habilitada. Diseñar una plantilla con vacuna, identidad de lote, vencimiento, capacidad, cantidad y soporte; validar permisos, datos, duplicados y consistencia contra lotes existentes, mostrar vista previa y requerir confirmación. Definir transacciones, concurrencia, idempotencia, auditoría y manejo de errores antes de activarla. No convertir frascos en dosis disponibles sanitariamente por simple multiplicación.
