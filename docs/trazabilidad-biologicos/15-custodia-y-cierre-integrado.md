# Custodia y cierre: integración operativa inicial

## Estado

Implementación local de API, persistencia y Flutter. **No desplegada ni habilitada
en producción.** Requiere V39 y `APP_INVENTORY_CUSTODY_WORKFLOW_ENABLED=true`, además
de la API base de inventario. El indicador nuevo permanece `false`; las
recepciones y devoluciones anteriores no necesitan habilitarlo.

V38 ya existe en el repositorio y no se modifica. Antes de desplegar debe
verificarse la historia Flyway real; no asumir la versión remota a partir de
este documento. Arrancar el backend con Flyway habilitado puede aplicar las
migraciones pendientes: no usar producción como entorno de pruebas.

## Accesos

- Inicio del administrador institucional: **Custodia y cierre**, bajo las mismas
  guardas de rol y lectura que Entregas/Jornadas. Nunca aparece como acceso
  administrativo para vacunadores.
- Entregas y jornadas: **Custodia y cierre** para administradores;
  **Mi custodia y conteos** para vacunadores.
- Detalle de entrega: **Continuar a custodia y cierre**.
- Detalle de jornada, activa o finalizada: **Ver custodia y cierre de la jornada**.
  La bandeja filtra por jornada sin sumar entregas como si fueran saldo físico.

La bandeja administrativa conserva el acceso al seguimiento de devoluciones y
correcciones por verificar. Dentro de cada entrega se puede revisar su
diferencia de traslado y confirmar devoluciones pendientes, según permisos.

## Recorrido

1. **Entrega física y recepción.** Se conserva el registro existente.
2. **Finalización de transferencia.** Una recepción explícita completa sin
   diferencias ni novedades finaliza automáticamente el traslado, en la misma
   transacción. No sucede para historia sin recepción individual, recepciones
   complementarias ni incidencias. El administrador revisa esos casos con
   evidencia; las diferencias de traslado deben estar resueltas.
3. **Conteo por el destinatario.** Documenta frascos cerrados y abiertos que
   conserva, agotados y descartados acumulados y dosis descartadas acumuladas.
   No incluir frascos ya declarados en devoluciones, pérdidas o cuarentena.
   Cada registro es una nueva instantánea; no se suman conteos entre sí.
   Un conteo discrepante se conserva y se señala: no genera pérdida ni ajuste.
4. **Vínculo clínico explícito.** Se proponen aplicaciones existentes compatibles
   por institución, profesional, vacuna y número de lote. El usuario debe
   confirmar su procedencia y documentarla. No se vinculan por coincidencia
   automática, no se crean dosis/lotes ni se modifica la aplicación.
5. **Revisión administrativa del corte.** Requiere transferencia finalizada,
   conteo aritméticamente explicado y ninguna aplicación vinculada anulada.
   Compara un identificador de conteo y la base de evidencia consultada para
   rechazar revisiones obsoletas. Cambios posteriores vuelven a exigir revisión.
6. La custodia continúa visible si hay frascos cerrados/abiertos o devoluciones
   pendientes. Finalizar la jornada no ejecuta estos pasos.

## Significado y límites

- Una **finalización de transferencia** no cierra custodia ni confirma destino
  físico, regularización o aptitud sanitaria.
- Una **revisión de custodia** documenta la evidencia de un corte; **no es un
  cierre sanitario integral**, ni certifica integridad del registro clínico.
- La diferencia aritmética compara recibido registrado menos novedades
  declaradas menos categorías del conteo explícito. Puede ser negativa.
  No es saldo operativo, disponibilidad, ubicación inferida ni pérdida.
- Frascos y dosis se muestran separados. El agotamiento/descarte se declara;
  no se convierte automáticamente una aplicación en consumo de un frasco.
- El vínculo es **aplicación → entrega → lote/custodio**, no identidad individual
  del frasco. El número de lote clínico no se trata como FK del lote logístico.
- No se han implementado apertura individual con UUID/código, remanente por
  frasco, conservación, uso clínico automático ni reglas multidosis. Requieren
  protocolos PAI/producto y validación sanitaria.
- Si se anula una aplicación o su atención, se conserva el vínculo y se señala
  revisión pendiente; no se devuelve producto al saldo. La corrección/reasignación
  auditable de vínculos clínicos aún no tiene un flujo habilitado: no borrar
  vínculos para forzar una conciliación.
- Los conteos/descartes no controlan ni descuentan el límite de devoluciones
  del servicio anterior. Son evidencia declarativa, no un nuevo libro de
  existencias. Se mantiene la necesidad de cotejo físico y revisión.
- La revisión no certifica que todas las aplicaciones estén sincronizadas o
  vinculadas. No hay conciliación automática de clínica offline.

## Persistencia y seguridad

V39 crea cuatro tablas aditivas, sin backfill:
`inventory_transfer_finalizations`, `inventory_custody_counts`,
`inventory_clinical_links`, `inventory_custody_reviews`. No modifica existencias,
aplicaciones, recepciones ni CSV. RLS sin políticas para clientes, privilegios
directos revocados y triggers que rechazan UPDATE/DELETE de esta evidencia.
El backend debe tener privilegios de servidor apropiados y seguir validando
permisos e institución; no exponer estas tablas mediante acceso cliente.

Las escrituras bloquean la entrega y usan UUID de operación estable. Vincular
una aplicación bloquea también su registro y permite un único vínculo. Los
reintentos idénticos devuelven la operación original, sin sustituir su evidencia.
Un fallo incierto en Flutter mantiene los datos y advierte al salir.

Consultar custodia propia exige `ATTENTION_CREATE` y ser destinatario; consulta
administrativa, `INVENTORY_READ`; finalización y revisión, `INVENTORY_WRITE`.
Consultar candidatos clínicos administrativos y vincularlos requiere además
`ATTENTION_READ`. No se devuelven datos de pacientes en esta superficie.

## Puerta de despliegue

Las pruebas H2/Flutter no certifican PostgreSQL. Antes de habilitar:

1. Ejecutar V39 en PostgreSQL aislado y comprobar RLS, revocaciones, FKs y triggers.
2. Probar permisos con sesiones reales, aislamiento institucional, recepción
   y finalización transaccional, enlaces concurrentes y reintentos tras timeout.
3. Validar el formato de conteos y evidencia con responsables institucionales.
4. Verificar conciliación física y las limitaciones anteriores; no presentar
   este corte declarativo como consumo clínico integrado completo.
5. Evaluar paginación de historia y candidatos clínicos para el volumen real.
6. Aplicar migración y desplegar deliberadamente; habilitar el indicador solo
   después de esas validaciones. Reservas, claves y consumo offline siguen apagados.
