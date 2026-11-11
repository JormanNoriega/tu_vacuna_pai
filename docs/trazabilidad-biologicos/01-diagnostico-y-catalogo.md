# Diagnóstico y configuración del catálogo

**Estado:** diagnóstico por lectura de código y diseño propuesto. No se comprobó la interfaz en ejecución ni el estado real de la base de datos.

## Diagnóstico

| Área | Evidencia observada | Brecha |
|---|---|---|
| Catálogo maestro | `services/api/src/main/resources/db/migration/V5__create_vaccine_catalog.sql` define `vaccines` y `vaccine_options`, con dosis globales. | Se necesita definir publicación y actualización versionada sin romper trabajo offline ni históricos. |
| Configuración institucional | La misma migración define `institution_vaccines` y opciones locales; `InstitutionVaccineService` habilita vacunas y copia plantillas iniciales. | Falta una experiencia clara para configurar cada vacuna y relacionarla con inventario. |
| Vista administrativa | `apps/mobile/lib/features/catalogs/presentation/pages/catalog_page.dart` llama «Inventario» al catálogo y abre un diálogo de opciones por vacuna. | No muestra existencias físicas. El diálogo ofrece al administrador «Agregar como dosis», aunque `CatalogRules` no acepta dosis como opción local. |
| Aplicaciones | `AttentionService` valida la selección y guarda snapshots clínicos. | No genera consumo físico. No se verificó el flujo en ejecución. |
| Lote | `V9__create_attentions.sql` tiene `lot_id` sin FK de inventario y `lot_number` como texto. | El lote guardado no demuestra existencia física, saldo ni condiciones de uso. |
| Inventario y jornadas | No se encontraron módulos funcionales para cantidades, entregas o conciliaciones en la revisión realizada. | El catálogo habilitado no limita las aplicaciones por stock. |
| Informes | `ReportController` y `reports/export/` implementan resumen y exportación de registro diario; también existen métricas. | Son reportes clínicos, no control logístico. El README que describe `reports` como esqueleto está desactualizado. |

## Catálogo maestro y configuración local

El comportamiento actual no es una copia institucional completa y versionada del catálogo: existen relaciones institucionales con vacunas globales y copia inicial de plantillas operativas. Las dosis se consultan desde el catálogo global; la aplicación clínica conserva snapshots de selección.

| Dato | Responsable propuesto | Regla |
|---|---|---|
| Identidad, código, nombre y dosis clínicas | Superadministrador | Solo lectura para el administrador institucional. |
| Habilitación institucional | Administrador de la entidad | No modifica la definición global ni implica stock. |
| Jeringas, goteros, observaciones y opciones operativas | Institución, dentro de límites clínicos validados | No permitir que la configuración suprima requisitos obligatorios. |
| Presentación, fabricante, dosis nominales y lote | Catálogo de producto e inventario | La gobernanza del catálogo de productos está pendiente de decisión. |
| Umbrales de alerta | Institución | Configurables sin alterar reglas sanitarias. |

### Pantalla por vacuna

Al seleccionar una vacuna, presentar información oficial y dosis en **solo lectura**, estado institucional, opciones operativas agrupadas y enlace a existencias y alertas. Corregir la acción «Agregar como dosis» del administrador. La gestión de catálogo no debe llamarse inventario físico.

### Actualizaciones del catálogo

Diseñar una publicación versionada con identificadores estables, conservación de snapshots clínicos y sugerencias operativas que no sobrescriban configuraciones locales. Definir cómo evaluar eventos registrados offline con una versión anterior: `CatalogSelectionService` actualmente valida el estado activo al procesar, por lo que un cambio durante la desconexión puede requerir revisión. No se afirma que exista hoy un sistema completo de versiones publicadas.

## Referencia legacy

El proyecto anterior está en `../mi_vacuna/`. Su `lib/app/modules/vaccine_management/vaccine_form_page.dart` agrupaba características y opciones como laboratorio, jeringa, gotero, observaciones, neumococo y dosis. Su `lib/app/data/database_helper.dart` almacenaba opciones ligadas a una vacuna.

Recuperar como referencia funcional una pantalla agrupada y comprensible. No copiar su arquitectura ni permitir que el administrador cambie libremente dosis, edades o requisitos clínicos. No asumir que sus flags expresan reglas oficiales.
