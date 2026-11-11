# Configuración e inventario de biológicos PAI

**Estado:** los documentos iniciales contienen propuestas históricas; la implementación online y sus límites actuales se describen en [flujo operativo](12-flujo-operativo-inventario.md). Las propuestas de consumo offline no están habilitadas.
**Alcance:** configuración institucional de vacunas, inventario, custodia, asignaciones, jornadas, consumo offline, conservación e informes.

**Prioridad:** jornadas forma parte de la primera versión, aunque su uso es opcional para la atención rutinaria. La adaptación y habilitación de la vista web se dejan para después. Reutilizar los módulos existentes y mantener la atención actual operativa durante la transición.

## Documentos

1. [Diagnóstico y configuración del catálogo](01-diagnostico-y-catalogo.md).
2. [Operación: inventario, asignaciones y jornadas](02-operacion-inventario.md).
3. [Aplicación, frascos y sincronización offline](03-consumo-y-offline.md).
4. [Modelo de datos propuesto](04-modelo-datos.md).
5. [Informes, fases y decisiones pendientes](05-informes-y-plan.md).
6. [Auditoría técnica y alcance simplificado](06-auditoria-y-mvp.md).
7. [Modelo mínimo y asignación offline](07-modelo-minimo-y-dispositivo.md).
8. [Flujo operativo de inventario y propuesta de carga masiva](12-flujo-operativo-inventario.md).

## Decisiones centrales

- El catálogo maestro define vacunas y dosis clínicas; el administrador institucional no las crea ni modifica. La configuración local no altera el catálogo maestro.
- El inventario físico es independiente del catálogo: registra productos, presentaciones, lotes, ubicaciones, custodias y cantidades.
- La custodia pertenece a una persona, equipo o punto; una autorización offline concede a un dispositivo una cuota de esa custodia. La cuota no es inventario adicional.
- Las entregas distinguen preparación, salida física, recepción y disponibilidad offline.
- Las aplicaciones normales generan consumo trazable, también sin conexión. La dosis del esquema clínico no determina por sí misma la cantidad física consumida.
- Una jornada es opcional para la vacunación rutinaria y las asignaciones rápidas. Terminar una jornada no obliga a devolver las existencias ni a cerrar la custodia.
- Los movimientos históricos no se editan ni borran como mecanismo normal de corrección. Las diferencias y contingencias requieren resolución trazable.
- El MVP propone frascos completos por custodia y evita compartir frascos abiertos entre dispositivos. La operación real debe validarse.

## Interpretación y límites

Estos documentos distinguen el código observado de lo propuesto. Las cantidades de dosis por frasco son **nominales**: un remanente no se presume utilizable. Los requisitos de cadena de frío, reutilización y descarte deben validarse por producto, protocolo institucional y lineamientos PAI vigentes antes de implementar reglas clínicas.

El análisis del estado actual se basó en lectura de código y documentación; no se recorrió la aplicación iniciando sesión ni se verificaron datos de la base de datos. Los documentos no certifican conformidad normativa ni funcionamiento en producción.

Referencia oficial para validación: [lineamientos técnicos y manuales PAI/PAIWEB de MinSalud](https://vacunacion.minsalud.gov.co/RT/Paginas/lineamientos-tecnicos.aspx). Revisar la versión vigente y los manuales de inventario, cadena de frío, aplicación y reportes con un responsable PAI.
