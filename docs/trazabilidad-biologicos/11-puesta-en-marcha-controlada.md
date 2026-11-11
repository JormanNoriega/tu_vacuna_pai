# Puesta en marcha controlada: inventario en línea

## Estado

La API está deshabilitada por defecto mediante `app.inventory.api-enabled`. Los controladores quedan fuera del contexto salvo que se habilite explícitamente en el backend.

Para la prueba local actual, la aplicación apunta por defecto a `http://localhost:8082/api/v1`; iniciar el backend en ese puerto con `APP_INVENTORY_API_ENABLED=true`. Reiniciar completamente la aplicación después de cambiar `API_BASE_URL` o actualizar su valor por defecto. Puede elegirse otra dirección con `--dart-define=API_BASE_URL=...`. En el emulador Android se traduce `localhost` a `10.0.2.2`; en un teléfono físico se necesita una dirección de red accesible y una configuración de seguridad apropiada. No exponer el backend local a la red sin revisar dicha configuración.

## Alcance inicial recomendado

Solo inventario en línea, entradas de existencias, entregas y confirmación de recepción. Mantener sin configurar (o explícitamente `false`):

- `app.inventory.reservations-enabled`
- `app.inventory.installation-keys-enabled`

El registro de jornadas y novedades de custodia forma parte de la misma bandera general de API. El flujo no consume dosis clínicas, no bloquea atenciones y no habilita modo offline.

## Prerrequisitos antes de activar

1. Elegir ambiente piloto, institución, responsables y fecha de inicio; probar primero en staging con la misma versión de PostgreSQL que producción.
2. Confirmar permisos: solo `ADMIN_INSTITUTION`/`SUPER_ADMIN` administran inventario; vacunadores tienen `ATTENTION_CREATE` para ver sus entregas y confirmar su recepción. Verificar que cada usuario pertenece a la institución correcta.
3. Hacer conteo físico institucional por lote, caducidad y frascos disponibles. Registrar fecha de corte y responsables. No reconstruir saldo desde atenciones históricas ni crear movimientos retroactivos supuestos.
4. Verificar migraciones Flyway y respaldos; probar entradas, entrega, recepción, reintentos y saldo con IDs de movimiento nuevos/idempotentes en staging.
5. Acordar conciliación diaria del saldo físico frente al saldo del sistema y un canal de reporte. Ante diferencias, detener nuevos movimientos del piloto y escalar; no ajustar silenciosamente.

## Activación piloto

Solo tras aprobación operativa del responsable del piloto, configurar en el despliegue de **staging** `APP_INVENTORY_API_ENABLED=true` (equivalente Spring de `app.inventory.api-enabled=true`). No establecer las otras dos banderas. Verificar por HTTP con JWT reales: anónimo rechazado, `INVENTORY_READ`/`INVENTORY_WRITE` por institución, vacunador incapaz de crear lotes o entregar, y recepción limitada a su propia asignación. Ejecutar un lote sintético, entrada, entrega, recepción y comprobación de saldo; limpiar los datos de prueba y comprobar atenciones clínicas sin cambios.

La promoción a producción requiere una decisión explícita posterior, evidencia de staging, responsable presente y plan de reversa. Desactivar la bandera oculta los endpoints, pero no revierte movimientos ya registrados.

## Evidencia automatizada actual

`InventoryApiFeatureFlagsTest` comprueba que todos los controladores están cerrados sin bandera, que la bandera general expone solo los flujos en línea y que reservas/claves requieren banderas adicionales. `InventoryControllerTest` y `InventoryServiceTest` prueban validación, permisos y movimientos. La prueba Flutter HTTP local usa H2 y tokens sintéticos; no sustituye una prueba de JWT real en el ambiente piloto ni una prueba física. La integración Supabase/móvil existente es opt-in y no se ejecutó en esta comprobación.
