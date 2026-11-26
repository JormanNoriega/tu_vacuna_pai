# Observer: entregas y devoluciones

## Problema y alcance

Cuando un administrador despacha frascos o un vacunador declara una devolución,
la otra persona necesita ver el cambio sin refrescar manualmente. Este canal es
un aviso efímero para aplicaciones abiertas; no confirma recepción física ni
sustituye las consultas y reglas de inventario.

## Participantes

| Rol | Archivo | Responsabilidad |
|---|---|---|
| Fuente local observable | `apps/mobile/lib/features/inventory/presentation/inventory_controller.dart` | Expone el stream `changes` y distribuye los eventos recibidos. |
| Observadores de vistas | `inventory_page.dart`, `widgets/admin_web_delivery_view.dart`, `delivery_detail_page.dart` y `pending_follow_ups_page.dart` | Se suscriben y actualizan los datos correspondientes. |
| Observador del aviso | `features/dashboard/presentation/pages/dashboard_page.dart` | Recibe eventos y muestra `AppSnackbar`. |
| Cliente de transporte | `features/inventory/data/inventory_event_client.dart` | Abre SSE autenticado y traduce mensajes a eventos locales. |
| Evento de servidor | `services/api/.../inventory/service/InventoryChange.java` | Identifica tipo, institución y operación. |
| Emisor SSE | `services/api/.../inventory/service/InventoryEventStream.java` | Tras el commit, autoriza y envía el aviso a las suscripciones correspondientes. |
| Orígenes | `InventoryService.dispatch` y `CustodyEventService.report` | Publican cambios al crear una entrega o declarar una devolución. |

Flutter y Spring aportan mecanismos de streams y eventos; la separación en
observadores, el filtrado de destinatarios y la integración con las vistas son
específicos del proyecto. SSE es el transporte, no el patrón Observer en sí.

## Seguridad y límites

El servidor verifica sesión, institución y permisos; antes de enviar vuelve a
resolver el usuario. La entrega se avisa al vacunador destinatario y la
devolución a las personas con lectura de inventario de esa institución. Los
eventos contienen identificadores, no datos clínicos; las vistas consultan la
API para recuperar datos autorizados.

La publicación se procesa después del commit y los reintentos existentes no
publican nuevamente. Si se pierde el aviso, el registro sigue en la API. Las
suscripciones están en memoria y se limitan a una instancia del servidor: no
son una cola persistente ni ofrecen notificaciones con la app cerrada. La
demostración requiere probar que web y móvil alcanzan la misma instancia y que
el proxy no retiene el flujo SSE.

Si el canal falla, la interfaz muestra un aviso persistente y recomienda
consultar manualmente; al recibir `ready` informa que se recuperó la conexión.
Ante un 401 el cliente intenta renovar la sesión una vez; un nuevo rechazo o
un 403 muestra el problema de sesión o permisos. La recuperación del canal no
reproduce eventos perdidos.
