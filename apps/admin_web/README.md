# Tu Vacuna PAI: administración web

Aplicación Flutter Web independiente, **en migración y no lista para reemplazar
la aplicación existente**. Las consultas están conectadas a Spring, pero aún
deben comprobarse en navegador con usuarios y datos de prueba reales.

## Estado de módulos

| Módulo | Disponible en la web | Pendiente |
| --- | --- | --- |
| Acceso y sesión | Inicio de sesión y validación de perfil en Spring | Restauración al recargar, renovación de token y validación integral de seguridad |
| Inicio | Estructura adaptativa basada en Brayan, accesos directos, pacientes y dosis reales | Coordenadas/mapa, actividad diaria y personal en turno no están disponibles en la API |
| Personal | Consulta, búsqueda, filtros, páginas y ficha | Creación, roles y cambio de estado; este último tiene cliente probado con respuestas simuladas, pero no está habilitado |
| Catálogo e inventario | Catálogo global/institucional y existencias de lotes en solo lectura; stock requiere `INVENTORY_READ` y la API habilitada | Configuración, entradas/ajustes y regularizaciones |
| Entregas y custodia | Consulta de entregas, jornadas y eventos; requiere `INVENTORY_READ` | Despachos, recepción, cierres y conciliación |
| Historial | Consulta paginada por fechas y detalle de dosis; requiere `ATTENTION_READ` | Expediente por paciente y exportación |
| Estadísticas | Composición analítica de Brayan con totales históricos verificados | Cobertura, tendencias por período y productividad; se muestran como no disponibles, no con cifras de ejemplo |
| Instituciones | Pantalla de estado del módulo | Consulta y gestión para superadministradores |

Las pantallas siguen la composición azul de escritorio de Brayan. Los estados
de módulos pendientes describen la integración que falta y dan acceso a las
secciones conectadas; no implican que el backend ya ofrezca esas funciones.
El servicio de historial determina el alcance: según roles y permisos puede
devolver únicamente atenciones del usuario, no necesariamente toda la
institución. La API de inventario depende de `app.inventory.api-enabled` en
Spring y está deshabilitada por defecto. Las escrituras de inventario no están
habilitadas en esta aplicación. No se muestran datos de ejemplo como reales.

```sh
flutter pub get
flutter test
flutter run -d chrome --dart-define-from-file=development.local
```

Esta aplicación no importa `apps/mobile` ni inicializa Drift, outbox o
scheduler. La aplicación anterior y su almacenamiento local no se han
modificado ni retirado: antes de su transición hay que identificar posibles
operaciones pendientes y validar cómo recuperarlas.
`test/architecture_boundary_test.dart` comprueba en la VM que el grafo de
paquetes resuelto no incluya la aplicación móvil ni Drift/SQLite.

El código se compartirá mediante paquetes independientes únicamente cuando
existan consumidores reales y se hayan definido sus dependencias y pruebas. La
sesión, los contratos de API y cada módulo se integrarán por separado según el
[plan de remediación](../../docs/engineering/plan-remediacion-admin-web.md).

## Límites durante la transición

- `apps/mobile/lib/main.dart` inicia la composición existente en
  `mobile_bootstrap.dart`. Esta también sigue sirviendo a la web antigua.
- `apps/admin_web/lib/main.dart` es un punto de entrada independiente; configura
  sesión y API solo cuando se proporcionan las variables requeridas.
- El backend y Supabase son servicios comunes, no dependencias entre las
  aplicaciones. Las credenciales privilegiadas nunca deben ir en el navegador.
- No se ha creado un paquete común: se evaluará cuando la web necesite código
  que ya use móvil y sea posible mantenerlo sin dependencias offline.

## Preparación de conexión

`lib/connection` contiene validación de configuración y un cliente online para
`GET /api/v1/me`. El arranque configura Supabase Auth y Spring cuando existen
`SUPABASE_URL`,
`SUPABASE_PUBLISHABLE_KEY` y `API_BASE_URL` mediante `--dart-define`, sin
valores predeterminados. Solo se acepta clave `sb_publishable_`, nunca claves
secretas o service role. Se exige HTTPS salvo HTTP en localhost o 127.0.0.1.
La URL de API debe incluir el prefijo, normalmente `/api/v1`.

El SDK mantiene la sesión solo en memoria y no la restaura al recargar; tampoco
renueva el token: al vencer requiere iniciar sesión de nuevo. El cierre remoto
puede fallar si no hay red, aunque el acceso local se retire. La autorización
definitiva corresponde a Spring. Antes de un despliegue faltan pruebas reales
con credenciales, CORS y navegador, y revisar los flujos de sesión y seguridad.

Para desarrollo local en esta máquina, `development.local` contiene las tres
variables públicas y está ignorado por Git. Con Spring en el puerto 8080:

```powershell
flutter run -d chrome --dart-define-from-file=development.local
```

El archivo se incorpora al binario web: nunca poner contraseñas ni claves
secretas allí. Para otro entorno crear su propia configuración y usar HTTPS.
