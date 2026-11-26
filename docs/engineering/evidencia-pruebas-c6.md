# Evidencia de pruebas automatizadas (C6)

## Alcance

Registro de la ejecución local de pruebas para los módulos móvil Flutter y API
Spring Boot, realizado el 26 de noviembre de 2026. Los resultados corresponden
a esta ejecución y deben repetirse después de cambios posteriores.

## Resultado de la ejecución

| Módulo | Comando | Resultado |
|---|---|---|
| Flutter | `cd apps/mobile; flutter test --coverage` | 312 pasaron; 0 fallaron; 2 omitidas. |
| Flutter | `cd apps/mobile; flutter analyze test/features/dashboard/statistics_controller_test.dart test/features/users/users_page_test.dart` | Sin incidencias en los dos tests modificados. |
| Backend | `cd services/api; .\mvnw.cmd test` | 468 ejecutadas; 0 fallos; 0 errores; 7 omitidas. `BUILD SUCCESS`. |

El reporte global Flutter `apps/mobile/coverage/lcov.info` registró 10.866
líneas cubiertas de 24.692 instrumentadas (44,01 %). Es una cifra global de la
aplicación, no una cobertura exclusiva de Estadísticas. El proyecto no tiene
actualmente reporte JaCoCo para la cobertura Java.

## Pruebas destacadas

- [statistics_controller_test.dart](../../apps/mobile/test/features/dashboard/statistics_controller_test.dart): cuatro pruebas del controlador; caché offline, actualización remota, notificaciones a listeners, error remoto y validación del periodo.
- [StatisticsQueryServiceTest.java](../../services/api/src/test/java/com/pai/api/attentions/service/StatisticsQueryServiceTest.java): dos pruebas del agregado; KPIs, dosis canceladas, límite final exclusivo, granularidad no reconocida, período vacío y alcance de IDs consultados.
- [users_page_test.dart](../../apps/mobile/test/features/users/users_page_test.dart): verifica el shimmer y el contenido de usuarios en viewport móvil. Se corrigió el viewport del test para corresponder a la ruta responsiva que intenta verificar.
- [InventoryApiFeatureFlagsTest.java](../../services/api/src/test/java/com/pai/api/inventory/controller/InventoryApiFeatureFlagsTest.java): prueba aislamiento de flags. Se fijaron en `false` los valores base del test, evitando heredar los defaults `true` del archivo de configuración.

Las pruebas nuevas usan repositorios falsos o repositorios mockeados; no
requieren una API desplegada, credenciales Supabase ni una base PostgreSQL.

## Reproducción

Desde la raíz del repositorio, en PowerShell:

```powershell
Push-Location apps/mobile
flutter test --coverage
Pop-Location

Push-Location services/api
.\mvnw.cmd test
Pop-Location
```

Pruebas focalizadas:

```powershell
Push-Location apps/mobile
flutter test test/features/dashboard/statistics_controller_test.dart
flutter test test/features/users/users_page_test.dart --plain-name "UsersPage muestra skeleton shimmer mientras carga vacunadores y luego muestra el listado"
Pop-Location

Push-Location services/api
.\mvnw.cmd -Dtest=StatisticsQueryServiceTest test
.\mvnw.cmd -Dtest=InventoryApiFeatureFlagsTest test
Pop-Location
```

## Límites de la evidencia

- La ejecución completa es local; no hay workflow de CI configurado en `.github/workflows`.
- Se omitieron 2 pruebas Flutter y 7 pruebas backend. Las pruebas backend omitidas incluyen escenarios que requieren PostgreSQL, Supabase u otras condiciones de integración; no se cuentan como evidencia ejecutada.
- No se reporta cobertura Java porque JaCoCo no está configurado.
- La cobertura Flutter es global; no debe interpretarse como cobertura de cada feature.

## Evaluación respecto a C6

La evidencia respalda el nivel 3: hay pruebas automatizadas ejecutables en los
módulos principales y se ejecutaron suites completas con resultados registrados.
No respalda el nivel 4: falta integración continua, cobertura backend reportada y
ejecución demostrada de las pruebas de integración omitidas.