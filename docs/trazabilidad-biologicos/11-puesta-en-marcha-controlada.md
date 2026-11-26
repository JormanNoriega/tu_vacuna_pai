# Puesta en marcha controlada: inventario en línea

> **Actualización de configuración:** las funciones de inventario están habilitadas
> por defecto en `application.yml`; las indicaciones históricas de este documento
> sobre habilitarlas mediante variables ya no describen el valor predeterminado.
> Las limitaciones de seguridad y validación señaladas siguen siendo relevantes.

## Estado

### Integración local de vistas de lectura

La prueba `InventoryReadViewsLocalE2eTest` está desactivada por defecto. Inicia un servidor Spring efímero en `127.0.0.1` con H2 en memoria, autenticación simulada y datos sintéticos; ejecuta widgets Flutter contra sus endpoints reales y compara las tablas antes y después. No usa `.env.local`, no inicia el backend habitual ni ejecuta Flyway. Desde `services/api`:

```powershell
$env:PAI_RUN_LOCAL_READ_E2E = 'true'
.\mvnw.cmd '-Dtest=InventoryReadViewsLocalE2eTest' test
```

Se verifican referencias de recepción y novedad, tipos de seguimiento, denegación a un vacunador, rechazo de otra institución y entrega inexistente, y ausencia de escrituras en las tablas del fixture. Esta prueba usa identidades simuladas y un esquema H2 mínimo: **no valida permisos de usuarios reales, migraciones ni comportamiento PostgreSQL**.

**Advertencia de desarrollo:** las migraciones `V33`–`V37` fueron aplicadas y validadas por Flyway en Supabase el 16/11/2026. V33 se restauró exactamente al contenido aplicado (checksum `-1050557124`) y V34–V37 quedaron registradas con sus checksums locales; la base está en la versión 37 y un segundo `migrate` no ejecutó cambios. Esto **no** sustituye la prueba aislada en PostgreSQL ni la validación de concurrencia: `DisposablePostgresInventoryTest` sigue desactivada y las pruebas H2 no reemplazan PostgreSQL. No se crearon existencias, lotes, recepciones ni movimientos de prueba.

Las pruebas `InventoryPostgresMigrationTest` e `InventoryPostgresConcurrencyTest` leen `services/api/.env.local`; la segunda usa usuarios y catálogo existentes y escribe datos de prueba. Sus marcadores de activación identifican una configuración, pero **no demuestran que sea una base aislada**. No ejecutarlas con credenciales de producción ni asumir que son una prueba segura de staging. Preparar una base PostgreSQL desechable, con credenciales explícitamente separadas y sin datos reales, antes de validar migraciones, transacciones e idempotencia.

### Prueba local desechable de V33–V37

`DisposablePostgresInventoryTest` está desactivada por defecto y no lee `.env.local`. Requiere un servidor PostgreSQL local independiente, **sin túnel ni reenvío a otro servidor**, y una base nueva vacía cuyo nombre sea `pai_inventory_test_` seguido de 32 caracteres hexadecimales minúsculos. Crear previamente la base y el usuario dedicado `pai_inventory_test_runner`, con contraseña, permiso de conexión y creación de esquema en esa base; no usar credenciales reales ni de producción. El servidor debe aceptar conexiones por TCP a `127.0.0.1` y reportar esa misma dirección como `inet_server_addr()`.

Desde `services/api`, con valores propios de la instancia local:

```powershell
$env:PAI_DISPOSABLE_PG_RUN = 'true'
$env:PAI_DISPOSABLE_PG_URL = 'jdbc:postgresql://127.0.0.1:5432/pai_inventory_test_0123456789abcdef0123456789abcdef'
$env:PAI_DISPOSABLE_PG_USER = 'pai_inventory_test_runner'
$env:PAI_DISPOSABLE_PG_PASSWORD = '<contraseña local>'
.\mvnw.cmd '-Dtest=DisposablePostgresConfigTest,DisposablePostgresInventoryTest' test
```

La prueba rechaza parámetros JDBC adicionales, otros usuarios, bases sin el nombre exigido, un servidor que no reporte loopback, un esquema `app` existente y objetos comunes en `public`. Estas guardas reducen riesgos, pero **no prueban que un servidor local no sea un túnel o réplica**: verificarlo antes de ejecutar. La prueba crea datos sintéticos y no borra la base; tras una ejecución se necesita otra base vacía. La creación y eliminación de la base quedan a cargo del operador.

Para reproducir las dependencias de inventario ejecuta V20–V22 sobre tablas mínimas y crea entregas históricas sintéticas recibidas y en tránsito antes de establecer una línea base Flyway en V32. Después aplica V33–V37, verifica su migración sin crear recepciones ni resoluciones ficticias, y prueba reintentos y conflictos concurrentes de creación de lotes solos y combinados, recepción, resolución, concurrencia entre ambas y concurrencia de regularización. **No valida V1–V32 completas, permisos reales ni un despliegue de producción**. Complementar con una prueba completa en un entorno aislado representativo. Nunca activar las pruebas antiguas que usan `.env.local` para este procedimiento.

La prueba desechable también prepara una lectura histórica con proxy transaccional y una recepción concurrente. Una implementación anterior con varias sentencias mostró una lectura mezclada en H2 pese a `REPEATABLE_READ`; ahora la consulta reúne la evidencia en una sola sentencia. La prueba H2 confirma que una escritura realizada después de obtener esa sentencia y antes de devolver la respuesta no mezcla los resultados, incluso dentro de una transacción `READ_COMMITTED`. **Esto no valida PostgreSQL ni una escritura a mitad de la ejecución de la sentencia**: hay que ejecutar la prueba desechable y comprobar la semántica y el rendimiento reales. Una transacción exterior tampoco eleva automáticamente su aislamiento por la anotación del método.

Al final de esa misma prueba se aplica el esquema candidato de custodia desde `src/test/resources` y se ejercita el servicio exclusivo de pruebas con autorización simulada, recepciones sintéticas, reintentos y vínculos concurrentes. El prototipo permanece fuera de Flyway y de la aplicación. Esta prueba está preparada, **no ejecutada en PostgreSQL**, y no sustituye pruebas con permisos y configuración reales.

La prueba también prepara el esquema candidato de finalización y carreras entre el cierre y los servicios de recepción complementaria y declaración de devolución. Usa una tabla mínima de reservas vacía porque el fixture no ejecuta V23. Comprueba que la devolución siga pendiente y que el cierre no cree movimientos ni altere el depósito. Sigue siendo una prueba de prototipos con autorización simulada, no una habilitación de cierre o consumo.

Asimismo prepara la composición experimental de recepción, custodia y finalización con una transacción común: reintentos concurrentes, rollback ante fallos de autorización o finalización y recepción parcial seguida de complementaria. El prototipo usa la identidad del vacunador para el vínculo interno, con autorización simulada en pruebas y sin conceder escritura administrativa. Esta sección tampoco se ha ejecutado en PostgreSQL y no aprueba el modelo de permisos ni su despliegue.

También prepara una devolución declarada y reintentada después de ese cierre: la consulta candidata debe conservar las referencias originales de recepción, cierre y devolución pendiente sin crear movimientos ni acreditar depósito. Este escenario está desactivado por defecto y aún no se ha ejecutado en PostgreSQL.

Se añadieron escenarios preparados para rechazar un comprobante interno después de rollback o commit, reintentar la misma recepción y verificar que el vínculo registre al vacunador sin solicitarle `INVENTORY_WRITE`. Estos escenarios también requieren ejecutar la prueba optativa en una base desechable: compilar la prueba o pasar H2 no demuestra que funcionen en PostgreSQL.

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
