# Entregas y jornadas: flujo guiado

La primera integración local de seguimiento posterior está descrita en
[Custodia y cierre](15-custodia-y-cierre-integrado.md), con sus condiciones de
habilitación y límites clínicos. No equivale a consumo automático por frasco.

## Alcance

Interfaz Flutter de operación online. Conserva las APIs existentes y no requiere
migraciones ni datos de demostración en Supabase. No activa consumo clínico,
reservas ni operaciones offline.

## Entrega directa

1. En **Entregas**, elegir **Nueva entrega**.
2. Seleccionar al vacunador.
3. Agregar vacunas/lotes y cantidades de frascos completos. Solo se ofrecen
   lotes con saldo registrado y sin vencimiento, usando la fecha de Colombia.
4. Indicar el motivo o soporte y revisar antes de confirmar.
5. Confirmar la entrega física. El vacunador confirma después su recepción.

No requiere jornada, lugar ni fecha de actividad. No se debe registrar una
entrega como si fuera una reserva o una intención futura.

Cada lote genera una entrega independiente. El servidor vuelve a validar
permisos, institución, saldo y vencimiento. Si una operación de varios lotes
falla parcialmente, se conservan las entregas confirmadas y los identificadores
de las pendientes; **Reintentar pendientes** no vuelve a enviar las confirmadas.
Esto no es una transacción única para varios lotes. Si se abandona la pantalla
tras un resultado incierto, revisar las entregas antes de iniciar otra operación.

## Jornada

1. En **Jornadas**, elegir **Nueva jornada**.
2. Indicar lugar y fecha. Para varios días, usar la opción de rango.
   El nombre es opcional; si se omite, se construye a partir del lugar.
3. Guardar y elegir los vacunadores del equipo.
4. Abrir cada vacunador y pulsar **Asignar vacunas**.
5. Elegir sus lotes, cantidades y motivo; revisar y confirmar.

Guardar una jornada o agregar participantes no mueve frascos. Las asignaciones
son entregas físicas separadas y quedan vinculadas a la jornada y al vacunador.
Las jornadas guardadas pueden retomarse desde la lista aunque aún no tengan equipo.
El equipo se agrega mediante operaciones independientes: un error no elimina
participantes ya guardados y el reintento completa los pendientes.
No se ofrece retirar participantes porque ese flujo no está implementado.

Finalizar la jornada impide nuevas asignaciones para ella, pero no devuelve
frascos ni resuelve pendientes. No se permite modificar el equipo ni asignar
vacunas en una jornada finalizada.

## Consulta y seguimiento

El inicio del administrador institucional ofrece **Entregas** y **Jornadas**:
requieren rol `ADMIN_INSTITUTION`, permiso `INVENTORY_READ` y controlador
disponible; no se ofrecen a cuentas con rol `VACCINATOR`. Cada acción vuelve a
validar el acceso antes de navegar. `INVENTORY_WRITE` habilita los formularios
administrativos; sin él se conserva la consulta. Estos accesos no sustituyen la
autorización institucional del servidor.

### Después de asignar

1. El despacho queda pendiente de recepción.
2. El vacunador destinatario entra en **Entregas y jornadas** y pulsa **Recibir**,
   o abre el detalle y pulsa **Confirmar recepción**. Registra lo recibido
   físicamente; una diferencia exige observación. No recibe el administrador en
   su nombre.
3. El administrador consulta el estado desde **Entregas** o desde el vacunador
   dentro de una jornada. Revisa diferencias e historial cuando corresponda.
4. El vacunador puede declarar devolución o novedad; el administrador revisa
   las devoluciones pendientes. Declarar una devolución no acredita depósito
   automáticamente.

La recepción ya está implementada. Aún falta completar la operación de
custodia persistente, el cierre integrado y la integración clínica por
producto/frascos multidosis. No se deben interpretar las atenciones como
descuentos automáticos de estos frascos. Finalizar la jornada no cierra
entregas, confirma devoluciones ni resuelve diferencias.

- La pantalla principal muestra entregas o jornadas, no el catálogo de lotes.
- El detalle de entrega conserva recepción, diferencias, historial,
  conciliación y las devoluciones/novedades relacionadas, según el rol.
- La recepción complementaria y la declaración de novedades pueden coexistir
  en el detalle de una entrega parcial.
- CSV y seguimiento pendiente siguen disponibles en **Más opciones**.
- Las devoluciones y novedades generales se agrupan en una sección desplegable.
- Las vistas de solo lectura no ofrecen nuevas entregas ni edición de jornadas.

## Dirección de interfaz

Modo **Operate**: dos tareas claras y divulgación progresiva. Se conserva el
lenguaje Material existente, sin sustituir la identidad global ni cambiar el
módulo de Inventario. El éxito es poder pasar de lugar/fecha a equipo y de equipo
a frascos por persona sin interpretar tablas administrativas.

## Límites de validación

Las pruebas de widgets usan datos sintéticos locales; no equivalen a probar el
recorrido con sesiones reales o a certificar concurrencia PostgreSQL. Los
guardados de varios lotes y participantes no sobreviven al cierre de la app como
borradores persistentes. La operación requiere conexión.
