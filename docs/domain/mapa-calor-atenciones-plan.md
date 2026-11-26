# Plan: visor geográfico de atenciones y jornadas

**Estado:** diseño acordado; validación técnica y desarrollo pendientes.  
**Referencia revisada:** commit `a019ac5` (`feat(statistics): add real admin dashboard`). Este documento describe el código local revisado, no una auditoría de datos de producción.

**Avance de implementación:** existe un visor experimental MapLibre conectado al endpoint Spring, habilitado por defecto. Se autorizó probarlo con los registros de prueba de Supabase. La cuadrícula de `0.018` grados es una aproximación de prueba cerca de Colombia, no una resolución uniforme de 2 km. El aislamiento extremo a extremo, la concurrencia bajo carga, la privacidad y la visualización real en cada plataforma aún requieren validación. No utilizar con datos de producción antes de completar esas validaciones.

El acceso al visor aparece en Flutter para administradores institucionales y consulta la API geográfica de Spring, habilitada por defecto. El mapa usa por defecto OpenFreeMap Liberty; se puede indicar otro con `--dart-define=GEOGRAPHY_MAP_STYLE_URL=...`. El navegador descarga MapLibre GL JS desde un CDN y el proveedor cartográfico recibe las solicitudes de estilo, fuentes y teselas correspondientes al área visualizada; evaluar proveedor, términos y exposición del encuadre antes de publicar. El zoom máximo 14 es provisional, no una decisión de privacidad.

La versión `maplibre_gl` 0.25.0 se fijó porque versiones posteriores entran en conflicto con la dependencia `excel` actual. La compilación web y Android no sustituye la prueba interactiva de capas de calor ponderadas y círculos en dispositivos reales. La compilación web JavaScript funciona; el análisis preliminar de WebAssembly informa incompatibilidades en `image` 4.3.0. Android informa que el plugin aplica Kotlin Gradle Plugin y necesitará actualización para futuras versiones de Flutter.

## Objetivo y alcance

Ofrecer al administrador institucional un visor geográfico en la aplicación móvil y la web, únicamente con conexión. La primera entrega mostrará la concentración de atenciones de su institución, sumando las registradas por todos sus vacunadores, mediante modos de calor y agrupaciones. Una fase posterior incorporará la visualización de jornadas, una vez validadas las relaciones entre los datos y sus permisos.

El visor no representa cobertura de vacunación ni garantiza el lugar exacto de aplicación. Se mostrarán solo atenciones con coordenadas utilizables; las ubicaciones capturadas pueden ser aproximadas o antiguas. Las capas de puntos de vacunación y análisis de cobertura territorial se descartan del alcance.

### Decisiones funcionales

- Acceso exclusivo al administrador institucional, limitado a su institución. Vacunadores y superadministradores no tienen acceso en la primera versión; definir explícitamente el comportamiento de cuentas con varios roles.
- Contar atenciones `COMPLETED`, excluyendo anuladas; verificar las transiciones y probar anulaciones posteriores.
- Excluir coordenadas nulas, incompletas, no finitas o fuera de rango. No asumir que un par válido es necesariamente correcto.
- Períodos predefinidos de 7, 30 y 90 días, por defecto 30. Sin filtro individual por vacunador ni fechas arbitrarias.
- Zona operativa `America/Bogota`. Definir los períodos como días calendario incluyendo el día actual: desde el inicio local del primer día hasta el inicio local del día siguiente, inicio inclusivo y fin exclusivo; convertir ambos límites a instantes para la consulta.
- Sin actualización automática ni persistencia local del resultado geográfico. El botón **Actualizar** vuelve a consultar al servidor, pero no invalida su caché compartida.
- La pantalla permite alternar entre **calor** y **agrupaciones** usando la misma respuesta agregada, sin nueva petición mientras los datos sigan en memoria. Los controles visuales, como opacidad, no alteran la política de publicación.
- Para la prueba, la opacidad inicial será 80 %, con intensidad y radio visual ajustables en el cliente. La escala y la leyenda deben aclarar el efecto de estos controles para evitar comparaciones engañosas.
- La resolución de celdas y el umbral mínimo serán configurables en el servidor por responsables autorizados, no mediante controles libres en el mapa. Sus valores para datos reales requieren aprobación de privacidad; un resultado vacío no justifica reducir el umbral sin evaluación.
- Usar provisionalmente celdas de aproximadamente 2 km y un mínimo de 5 atenciones solo para pruebas; no son una política de privacidad aprobada ni garantizan anonimato. El zoom máximo se definirá en la validación.
- Mostrar fecha real de generación del resultado y una leyenda que indique que las ubicaciones son aproximadas.

## Revisión de captura de coordenadas

La captura ya existe, pero no está garantizada para todas las atenciones:

1. `apps/mobile/lib/features/attentions/presentation/pages/nueva_atencion_page.dart` inicia `_fetchLocationInBackground()` en `initState` y guarda la posición en `_latitude` y `_longitude`. Al crear la atención pasa esos valores a `ensureAttentionStarted`.
2. `apps/mobile/lib/core/device/location_service.dart` solicita ubicación actual con precisión media y tiempo límite de cuatro segundos; si falla, intenta la última posición conocida. Si no hay permiso, servicio o posición, devuelve `null`. No se conserva antigüedad, precisión ni origen de la lectura.
3. `apps/mobile/lib/features/attentions/presentation/attention_controller.dart` transmite las coordenadas en las rutas en línea, fuera de línea y de respaldo. La captura ocurre en segundo plano: si la atención se crea antes de obtener resultado, puede guardarse sin coordenadas; la lectura tardía no garantiza actualizar una atención ya creada.
4. `apps/mobile/lib/core/synchronization/clinical_offline_repository.dart` guarda las coordenadas en SQLite y las incluye en el comando de creación; `command_payloads.dart` omite cada campo si es nulo. La sincronización permite enviar posteriormente la atención.
5. `services/api/src/main/java/com/pai/api/attentions/dto/CreateAttentionRequest.java` acepta coordenadas opcionales y valida sus rangos individualmente. `AttentionService` las asigna al crear la atención. La migración `V19__add_location_to_attentions.sql` agregó columnas anulables y límites de rango.
6. Existen pruebas de persistencia local y payload en `apps/mobile/test/core/synchronization/clinical_offline_repository_test.dart`, y pruebas de validación y respuesta en el backend. Esto no constituye una prueba integral de captura GPS, sincronización y almacenamiento remoto.

La ubicación pretende corresponder al punto de atención, pero en la práctica es la posición capturada por el dispositivo al iniciar el formulario o su última posición conocida, no una confirmación del lugar de vacunación. El formulario permite además registrar fechas de atención anteriores: la ubicación capturada al abrirlo no demuestra dónde ocurrió una atención histórica. Revisar también el ciclo de reinicio del formulario y sus reintentos antes de inferir que cada nueva atención vuelve a capturar ubicación.

**Fuera del alcance inicial:** cambiar la captura o bloquear el registro. Como mejora futura se podría estudiar `location_accuracy`, `location_captured_at` y `location_source`, junto con una política de antigüedad y la correspondiente sincronización. No inferir retroactivamente esos datos para registros existentes.

## Integración con cambios recientes

El commit revisado agregó el panel de estadísticas administrativas, con `StatisticsController`, `StatisticsRepositoryImpl`, `StatisticsService` y `StatisticsQueryService`. Aprovechar sus convenciones de presentación y la separación existente entre reportes y consultas clínicas, sin acoplar necesariamente el mapa a la respuesta del tablero.

El endpoint actual `GET /api/v1/metrics/statistics/dashboard` exige `ATTENTION_READ` y `StatisticsService` obtiene la institución con `DataScope`. Ese permiso por sí solo no expresa el acceso exclusivo acordado para el mapa: crear y probar una autorización específica antes de leer la caché.

`StatisticsRepositoryImpl` persiste la respuesta de estadísticas en metadatos de SQLite. **No reutilizar esa persistencia para el mapa**: su caché será independiente y exclusivamente en memoria. Revisar la ubicación apropiada del mapa en el panel administrativo móvil y web y sus estados de sesión.

## Arquitectura prevista

```text
Flutter móvil / web
  visor MapLibre + capas de calor y agrupaciones
  caché en memoria
          |
          v
Spring: endpoint de consulta geográfica
  autorización explícita y alcance institucional
          |
          v
consulta cacheada (@Cacheable + Caffeine)
          |
          v
consulta agregada por celdas en PostgreSQL
```

- Crear una consulta estadística separada del flujo de escritura clínica, siguiendo el puerto de consultas existente entre `reports` y `attentions`.
- El backend determina institución, zona y límites temporales; no confiar en una institución enviada por el cliente.
- Una sola respuesta por institución y período, con celdas agregadas; evaluar GeoJSON para alimentar una capa de calor ponderada. Los puntos deben ser centros de celdas, nunca coordenadas originales de atenciones.
- La cuadrícula inicial se definirá tras medir distribución y privacidad. No elegir resolución ni umbral mínimo sin esa evaluación.
- Mantener el visor y la gestión de capas reutilizables para incorporar jornadas posteriormente, sin construir por anticipado endpoints ni servicios de funciones aún no definidas.
- Cada capa nueva tendrá sus propios datos, permisos y política de caché. La autorización para ver estadísticas agregadas no implica autorización para ver secuencias individuales.
- Escala de color fija inicialmente, con leyenda y pruebas visuales. Si resulta inadecuada, acordar una alternativa sin sugerir comparaciones engañosas.
- El mapa base genera solicitudes propias al proveedor de tiles; son distintas de las peticiones a Spring. Evaluar MapLibre para las plataformas reales y OpenFreeMap como candidato, verificando condiciones, atribución y disponibilidad.

### Caché y consultas

- Servidor: Spring Cache con Caffeine, TTL inicial de 30 minutos y máximo inicial de 500 entradas, sujeto a medición de memoria y ajuste.
- Configurar mediante propiedades de Spring Boot la resolución, el umbral, los períodos permitidos, el período predeterminado y la caché. No crear inicialmente una tabla de configuración por institución ni una pantalla para cambiar estos valores.
- Clave derivada del alcance autorizado, período y límites o fecha de referencia en Bogotá, además de cualquier configuración que cambie el resultado, incluida la política de resolución y umbral; al cambiarla, invalidar o versionar las entradas afectadas. Comprobar autorización en cada petición antes de invocar el método cacheado.
- Para una clave idéntica, probar coordinación de cargas concurrentes con `@Cacheable(sync = true)` y el proveedor elegido. Evitar llamadas internas que omitan el proxy de Spring. La caché en memoria es independiente por instancia y se pierde al reiniciar.
- Cliente: memoria con TTL inicial de 5 minutos; separar por sesión, institución y período, limpiar al cerrar sesión o cambiar de institución. El botón manual omite la caché del cliente, no la del servidor. Evitar respuestas tardías de una sesión anterior.
- Mantener en la respuesta el instante original de generación, incluso en caché; no sustituirlo por el instante de recepción del cliente. Limitar memorias y no conservar respuestas sensibles en cachés HTTP compartidas.
- Carga inicial y cambio de período generan como máximo una petición por acción; ni desplazar ni acercar el mapa consulta Spring. Las solicitudes a Spring pueden responderse sin consultar PostgreSQL, pero la reducción efectiva depende de filtros, tráfico e instancias.
- Alternar entre calor y agrupaciones, o cambiar ajustes puramente visuales, no requiere nueva petición mientras esté disponible la respuesta compartida.

## Jornadas y secuencias: fase posterior

El objetivo es visualizar jornadas y, cuando los datos y permisos lo permitan, una secuencia aproximada de atenciones. Esto requiere una investigación y un diseño propios antes de implementar la capa.

- La migración `V21__inventory_campaigns.sql` relaciona jornadas de inventario con vacunadores y asignaciones; en la revisión inicial no se encontró una relación directa entre atenciones y jornadas. No asumir que ya se puede reconstruir una jornada de forma fiable.
- Verificar si existe una asociación indirecta segura; si no existe, diseñar una relación explícita y su captura, persistencia y sincronización offline antes de consultar secuencias. No asignar atenciones históricas a jornadas sin una regla justificada.
- Comprobar el significado y calidad de los tiempos y coordenadas. Una fecha clínica puede ser retrospectiva y la ubicación puede proceder de una última posición conocida.
- No unir atenciones de varios vacunadores como si fueran una sola trayectoria. Una secuencia por vacunador requiere una política y autorización específicas, distintas de la capa agregada.
- Una línea entre registros es una **secuencia estimada**, no un recorrido GPS real ni una ruta vial comprobada. No afirmar distancias, trayectorias ni desplazamientos reales a partir de esos puntos.
- Un motor de rutas podría evaluarse en una etapa posterior como estimación vial separada; el seguimiento GPS continuo queda fuera del alcance inicial y requeriría un diseño de privacidad y consentimiento propio.

## Privacidad y calidad

- No devolver identificadores de pacientes, profesionales ni ubicaciones originales. No registrar coordenadas sensibles ni enviar datos clínicos al proveedor del mapa base.
- Acordar resolución, umbral de conteo y zoom máximo con responsables de privacidad. Suprimir celdas pequeñas reduce riesgo, pero no garantiza anonimato.
- Evaluar inferencias por comparación entre períodos solapados, actualizaciones y totales. No publicar totales que permitan deducir celdas suprimidas sin validación de privacidad.
- Indicar que la ausencia de puntos puede deberse a coordenadas faltantes, restricciones de privacidad o falta de atenciones; no mostrar coordenadas inventadas.

## Validación y ejecución

1. **Auditoría funcional:** verificar transiciones de anulación y finalización, permisos y roles múltiples, ciclo de captura/reset, sincronización tardía y plataformas reales.
2. **PoC MapLibre:** con datos ficticios, validar capa de calor ponderada, leyenda, desempeño, plataformas, proveedor y accesibilidad. No usar datos reales sin la política de privacidad aprobada.
3. **PoC PostgreSQL:** medir cantidad y distribución de coordenadas válidas, tamaño de respuesta y tiempos por institución y período, usando datos agregados y sin extraer identificadores. Analizar planes con `EXPLAIN` y, cuando sea seguro y autorizado, `EXPLAIN ANALYZE`. Decidir índices solo con evidencia y mediante el flujo de migraciones del proyecto.
4. **Acordar privacidad y presentación:** tamaño de celda, umbral, zoom, escala y política de totales. Son condiciones previas para publicar datos reales.
5. **Implementar backend:** endpoint, autorización y alcance, consulta de agregación, DTO, caché, configuración y pruebas; no alterar el registro clínico.
6. **Integrar clientes:** visor administrativo en móvil y web, modos de calor y agrupaciones con la misma respuesta, caché en memoria, filtros, fecha de generación y estados de carga, error y ausencia de datos.
7. **Medir y probar:** aislamiento institucional y roles, concurrencia, uso de memoria, planes SQL y volumen de respuesta. Verificar sincronizaciones tardías y cancelaciones tras el vencimiento de la caché.
8. **Planificar e implementar jornadas en una fase posterior:** completar la auditoría de relación jornada-atención, acordar permisos y privacidad, resolver captura y sincronización si faltan, y solo entonces construir y probar su capa independiente.

## Criterios de aceptación

- [ ] Un administrador solo consulta su institución; vacunadores y superadministradores son rechazados, incluso ante una caché precalentada.
- [ ] La PoC confirma compatibilidad de MapLibre y calor ponderado en las plataformas objetivo.
- [ ] Abrir o cambiar período carga los datos; mover o acercar el mapa no genera peticiones a Spring.
- [ ] Cambiar entre calor y agrupaciones reutiliza los datos ya cargados; los controles visuales no modifican los límites de privacidad.
- [ ] Las solicitudes concurrentes para la misma clave comparten la carga según la configuración elegida.
- [ ] Actualizar consulta al servidor sin invalidar la caché compartida y conserva la fecha real de generación.
- [ ] Se excluyen atenciones no completadas o anuladas y coordenadas incompletas o inválidas.
- [ ] Una atención sincronizada tarde aparece tras regenerar la entrada de caché si cumple los filtros; una anulación posterior deja de aparecer tras regenerarla.
- [ ] La respuesta no expone coordenadas originales ni identificadores personales; la política de celdas y posibles inferencias está aprobada.
- [ ] La caché geográfica del cliente no se persiste y se limpia entre sesiones e instituciones.
- [ ] Se registran mediciones de tiempo SQL, tamaño de respuesta, memoria y comportamiento con datos representativos.
- [ ] Antes de publicar jornadas se verifica la relación con las atenciones, la autorización específica y que la interfaz distinga una secuencia estimada de un recorrido real.

## Fuera de alcance

Se descartan las capas de **puntos de vacunación** y **análisis de cobertura territorial**. Las jornadas y su posible secuencia son una funcionalidad distinta, prevista para una fase posterior.

También quedan fuera de la primera entrega Redis, PostGIS, tablas precalculadas, proxy manual, Strategy sin necesidad concreta, WebSockets, consultas por desplazamiento o zoom, tareas de regeneración, filtro individual por vacunador en las capas agregadas y persistencia local del mapa. Evaluarlos más adelante solo si las mediciones o requisitos lo justifican.
