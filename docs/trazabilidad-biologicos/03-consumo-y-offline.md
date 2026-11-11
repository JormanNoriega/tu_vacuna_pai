# Aplicación, frascos y sincronización offline

**Estado:** diseño propuesto. Las políticas de frascos abiertos y conservación requieren validación sanitaria antes de implementarse.

## Qué hace el vacunador durante una atención

El formulario debe permanecer sencillo: seleccionar vacuna, dosis clínica y lote disponible de su asignación, y guardar. El sistema relaciona la aplicación con custodia e inventario y registra el consumo; no debe pedir seleccionar un identificador de frasco en cada atención.

Hoy se puede registrar el lote en la aplicación, pero todavía no está vinculado a existencias físicas verificadas. La futura selección debe proceder de los lotes y cuotas autorizados para la custodia.

### Monodosis

En el caso habitual de una aplicación por frasco monodosis, guardar la aplicación registra también el consumo del frasco. No se necesita seleccionar individualmente un frasco cerrado. Excepciones y cantidad administrada dependen de la presentación y protocolo validados.

### Multidosis

Abrir un frasco significa destapar físicamente el envase para comenzar a utilizarlo. Se registra porque las dosis nominales que sobran no siempre pueden conservarse o utilizarse después.

1. La app busca un frasco abierto identificable para vacuna, lote y custodia según la información local.
2. Si existe, lo sugiere sin pedir una selección en cada atención.
3. Si no existe, pregunta: «¿Abriste un nuevo frasco de este lote?».
4. Al confirmar, crea una apertura con identificador interno y continúa con la aplicación.
5. Se registra el destino del remanente y el cierre cuando corresponda; no se presume que sea reutilizable ni que se haya desperdiciado automáticamente.

Los frascos cerrados se cuentan por lote y presentación, sin identificarlos uno a uno. Una referencia física visible puede registrarse opcionalmente para distinguir aperturas; el identificador digital por sí solo no identifica el frasco físico. Como simplificación **propuesta y pendiente de aprobación**, restringir a un frasco abierto identificable por lote y custodia para evitar selección ambigua. Si hay más de uno, no seleccionar a ciegas.

Ejemplo: un frasco de 10 dosis nominales y 4 aplicaciones tiene 6 dosis de capacidad nominal sin resolver; eso no demuestra que las 6 sean utilizables. El uso o descarte requiere protocolo validado.

## Autorización offline

La cuota se concede a un dispositivo sobre existencias bajo custodia; no cambia la responsabilidad física y no suma existencias a la entidad. No se puede comprometer la misma cuota en dos dispositivos. Para el MVP, no compartir un mismo frasco abierto entre dispositivos.

Si el administrador prepara una asignación mientras el dispositivo está desconectado, esta no aparece ni puede usarse localmente hasta que el dispositivo la reciba y guarde. Si la guarda y luego se desconecta antes de confirmar al servidor, el dispositivo puede conocerla localmente mientras el panel administrativo muestra confirmación pendiente. Este comportamiento es una propuesta que requiere aprobación.

## Atomicidad e idempotencia

Para una aplicación normal, una transacción SQLite debe guardar la aplicación clínica, la apertura confirmada si corresponde, el consumo, la proyección local y el outbox; si falla una parte, no se guarda solo otra. En el servidor, la misma operación de negocio confirma aplicación, consumo, proyección e idempotencia en una transacción.

Reutilizar `operationId` y el motor de sincronización existentes, añadiendo restricciones duraderas de unicidad para que un reintento no duplique el consumo aun después de una posible purga de operaciones procesadas. Enviar dependencias en orden y conservar los eventos rechazados para revisión.

## Excepciones

- **Sin cuota:** no registrar como consumo normal. El modo de contingencia para documentar vacunaciones reales queda pendiente de aprobación de permisos y procedimiento; no crear saldo negativo silencioso.
- **Anulación clínica:** no devuelve automáticamente biológico. Investigar si fue error de registro, aplicación real o desperdicio; corregir con eventos compensatorios autorizados.
- **Dispositivo perdido:** no liberar ni reasignar automáticamente la cuota; investigar, contar y resolver con autorización. Eventos tardíos de una autorización anterior requieren revisión.
- **Cambio de dispositivo:** normalmente sincronizar y cerrar la autorización anterior antes de emitir otra. La custodia física continúa.
- **Cuarentena desconocida offline:** el dispositivo no puede conocer cambios que no recibió. Mostrar última actualización, permitir registrar incidencias conocidas en campo y revisar conflictos al sincronizar.
- **Aplicación real rechazada:** mantenerla visible para resolución; no borrarla ni fabricar un saldo coherente artificialmente.
- **Jornada terminada sin conexión:** mantener pendientes y cuotas comprometidas; el informe es provisional hasta que se sincronicen y resuelvan los hechos necesarios.
