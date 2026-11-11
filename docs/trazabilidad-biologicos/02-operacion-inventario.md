# Operación: inventario, asignaciones y jornadas

**Estado:** flujo propuesto; validar con una institución y responsable PAI. La complejidad interna no debe convertirse en trámites innecesarios para el vacunador.

## Conceptos

- **Producto/presentación:** forma física del biológico, incluido fabricante y dosis nominales por frasco cuando aplique.
- **Lote:** identificación y vencimiento del producto recibido.
- **Ubicación:** depósito o lugar físico de inventario.
- **Punto de vacunación:** lugar operativo de atención; puede o no custodiar existencias.
- **Custodia:** responsabilidad física de existencias de un vacunador, equipo o punto; puede durar más de una jornada.
- **Entrega/asignación:** traslado documentado desde un origen hacia una custodia. La autorización para operar offline se gestiona dentro de este flujo, pero no es custodia física.
- **Jornada:** actividad planificada con fecha, lugar o puntos, personal y metas opcionales.

Las jornadas se incluyen en la primera versión; son opcionales para la atención rutinaria. Una jornada organiza una actividad; una asignación registra la entrega y responsabilidad física. Una jornada puede agrupar varias entregas y una entrega puede existir sin jornada. La interfaz puede ofrecer «Entregar vacunas» desde la jornada sin duplicar el registro.

Para asociar atenciones, se propone que el vacunador seleccione una jornada disponible y que la app la recuerde para las siguientes atenciones; también debe poder atender sin jornada. La selección recordada debe mostrarse claramente, poder cambiarse o quitarse y no asociar nuevas atenciones silenciosamente a una jornada finalizada. El detalle de persistencia offline y el tratamiento de jornadas finalizadas sin conexión quedan pendientes de diseño y pruebas.

## Flujo principal

1. **Recibir:** registrar producto, presentación, lote, vencimiento, cantidad física, ubicación, responsable y soporte disponible.
2. **Planificar opcionalmente:** crear jornada, puntos, personal y cantidades estimadas. Planificar no descuenta stock.
3. **Asignar:** seleccionar vacunador o custodia y líneas por lote y presentación; permitir asignación rápida y reposición sin jornada.
4. **Entregar y recibir:** distinguir reserva opcional, salida física, tránsito y confirmación de recepción. Una diferencia se registra como incidencia.
5. **Preparar offline:** emitir una autorización de dispositivo sobre cuota de custodia; la app debe recibirla y guardarla localmente antes de usarla.
6. **Vacunar:** registrar aplicaciones y consumo; capturar pérdidas y novedades separadas.
7. **Decidir remanentes:** mantener frascos cerrados en custodia, transferirlos o devolverlos; no se devuelven automáticamente al finalizar una jornada.
8. **Conciliar:** contrastar movimientos y conteo físico; conservar y resolver diferencias.
9. **Informar:** generar comprobantes y reportes con corte y estado provisional o conciliado.

### Estados de entrega y disponibilidad

Una entrega puede pasar por `BORRADOR → PREPARADA → EN_TRÁNSITO → RECIBIDA`, con cancelación cuando sea físicamente coherente e incidencia ante diferencias. Preparada no es entregada; entregada no es recibida; recibida no significa que el dispositivo ya tenga autorización offline. La app puede confirmar localmente la descarga antes de que el servidor reciba dicha confirmación.

## Unidades y multidosis

Registrar los frascos cerrados como unidades físicas por lote y presentación. `5 frascos × 10 dosis nominales = 50 dosis nominales` es una equivalencia informativa, no una garantía de 50 aplicaciones ni de que todo remanente sea utilizable. Los frascos abiertos se controlan por apertura y destino del remanente; ver [consumo y offline](03-consumo-y-offline.md).

En el MVP se propone entregar frascos completos por custodia. La custodia compartida y transferencia de frascos abiertos entre dispositivos quedan fuera del alcance inicial, sin impedir su incorporación futura.

## Conservación y cadena de frío

Registrar incidencias de conservación, cantidades y lotes afectados, responsable, fechas conocidas y decisión autorizada. Estados propuestos: **disponible, en cuarentena, no utilizable y descartado**. Una cantidad en cuarentena no se entrega ni se consume como disponible hasta su liberación autorizada. Una incidencia puede afectar una ubicación o cantidad y no necesariamente todo un lote.

El descarte físico debe ser trazable y diferente de declarar un producto no utilizable. No se incluyen sensores automáticos en el MVP. Rangos, tiempos, conservación de frascos abiertos y reglas de liberación requieren validación por producto y normativa vigente; la configuración local no debe relajar exigencias sanitarias.

## Cierre clínico y cierre logístico

Una jornada puede estar finalizada mientras una custodia sigue abierta para el día siguiente. El cierre logístico puede quedar provisional por sincronización, devolución o diferencias pendientes. No se debe presentar un informe como conciliado mientras no cumpla los controles aprobados.

Conciliar por lote y custodia: existencia inicial + entradas − salidas − aplicaciones − pérdidas − devoluciones = saldo esperado; comparar con conteo físico. Mantener separadas las unidades de frascos cerrados y el contenido de frascos abiertos: no forzar conversiones que oculten diferencias.
