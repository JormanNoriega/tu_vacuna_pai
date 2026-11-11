# Prueba integrada de inventario móvil

`InventoryMobileE2eTest` inicia una API Spring local con `app.inventory.api-enabled=true`, una base H2 efímera, identidades y tokens sintéticos, y ejecuta los widgets Flutter mediante HTTP real. La prueba crea un lote, registra una entrada de 10 frascos, entrega 3 y confirma la recepción. Después declara una devolución de 2 y confirma físicamente su reincorporación desde la vista administrativa: comprueba saldo 9 y tres movimientos.

En Windows, desde `services/api`:

```powershell
$env:INVENTORY_RUN_MOBILE_E2E = 'true'
.\mvnw.cmd '-Dtest=InventoryMobileE2eTest' test
```

El servidor escucha en un puerto local temporal y termina con la prueba; no accede a Supabase ni usa sus credenciales. El catálogo, la selección de vacunadores y la validación del token son datos simulados. La API, sus verificaciones de permisos y el servicio transaccional de inventario son los reales. La base de la prueba es H2: no sustituye una prueba completa con Supabase Auth, PostgreSQL y usuarios reales, ni una validación en dispositivo físico. La prueba PostgreSQL separada comprueba la migración, concurrencia y recepción, pero no la interfaz móvil.

La configuración de la aplicación mantiene el endpoint desactivado por defecto. Activarlo solo en entornos de prueba controlados; no habilita restricciones clínicas ni cuotas offline.

## Prueba explícita con Supabase Auth y PostgreSQL

`InventorySupabaseMobileE2eTest` es una prueba **opt-in que escribe temporalmente en el proyecto configurado**. Crea dos identidades temporales mediante Supabase Auth Admin, una institución temporal y sus datos de inventario; obtiene JWT reales por contraseña e inicia la API real local con inventario habilitado solo en ese proceso. Los widgets recorren creación de lote, entrada, asignación con jornada, recepción, devolución e incidencia. Después verifica saldo 9, devolución confirmada e incidencia de pérdida. La prueba elimina únicamente los registros de la institución e identidades que ella creó y deshabilita los sembradores globales durante su ejecución.

En Windows, desde `services/api`, y solo con autorización para modificar el proyecto de prueba configurado en `.env.local`:

```powershell
$env:INVENTORY_RUN_SUPABASE_MOBILE_E2E = 'true'
$env:INVENTORY_EXPECTED_DB_MARKER = '<referencia-del-proyecto>'
.\mvnw.cmd '-Dtest=InventorySupabaseMobileE2eTest' test
```

Requiere credenciales locales de base y servicio; no debe ejecutarse en producción. Las credenciales temporales y JWT no se imprimen. La eliminación se intenta en `finally`, pero una interrupción brusca o una falla de red puede dejar datos de prueba; se debe verificar la limpieza antes de repetir. La prueba ejecuta widgets en el entorno de pruebas Flutter y obtiene los JWT fuera de la pantalla de login: **no valida la pantalla de inicio de sesión ni un dispositivo físico**, ni habilita el consumo clínico o reservas offline.
