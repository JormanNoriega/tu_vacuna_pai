# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

El usuario principal es personal de enfermeria y salud que registra y consulta atenciones de vacunacion durante su jornada en instituciones de salud.

## Product Purpose

Tu Vacuna PAI permite registrar pacientes, atenciones y dosis aplicadas, consultar historiales, gestionar el catalogo de vacunas y exportar datos. La aplicacion debe seguir siendo util sin conectividad y sincronizar cambios cuando el servicio remoto este disponible.

## Positioning

El producto combina una experiencia operativa offline-first para el trabajo de campo con una fuente de verdad remota y sincronizacion controlada mediante operaciones idempotentes.

## Operating Context

La aplicacion se usa en dispositivos moviles y posiblemente tabletas, durante flujos repetitivos de registro y consulta. El usuario necesita confirmar rapidamente el estado de una atencion, continuar trabajando sin red y reconocer cuando existen operaciones pendientes de sincronizacion.

## Capabilities and Constraints

- El cliente es Flutter y el backend es Spring Boot modular con arquitectura hexagonal.
- La persistencia oficial es PostgreSQL administrado por Supabase; el cliente mantiene almacenamiento local cifrado y una outbox para trabajo offline.
- La identidad usa Supabase Auth y la autorizacion debe respetar roles y permisos.
- El flujo funcional heredado incluye desbloqueo local, inicio de sesion, registro de personal, dashboard, nueva atencion, historial, inventario, ajustes y exportacion.
- La implementacion nueva debe respetar la regla `UI -> Controller -> Use Case -> Repository -> Local / Remote`.
- No se debe copiar la implementacion SQLite/GetX anterior como arquitectura: se reconstruye desde cero.
- Queda abierta la decision final sobre la libreria de estado y la estrategia exacta de base local.

## Brand Commitments

- El nombre del producto es Tu Vacuna PAI / Mi Vacuna.
- La interfaz debe estar disponible en espanol; el soporte de ingles queda como capacidad heredada por confirmar.
- El producto debe comunicar seguridad operativa, claridad y confianza sin sacrificar velocidad de captura.
- Se conserva el icono y los assets de marca existentes como referencia hasta que se apruebe una sustitucion.

## Evidence on Hand

- La aplicacion anterior en `C:\Users\jorma\Desktop\mi vacuna\mi_vacuna` contiene flujos funcionales, componentes, tema, icono y recursos de splash.
- `docs/architecture/architecture.md` y los ADR del repositorio contienen las decisiones tecnicas objetivo.
- No hay que inventar testimonios, metricas, clientes, precios ni capacidades comerciales.

## Product Principles

- Offline primero: una red inestable no debe bloquear el trabajo.
- Una atencion debe poder registrarse de forma segura y trazable.
- El estado de sincronizacion debe ser visible y comprensible.
- La interfaz debe priorizar tareas frecuentes sobre configuracion secundaria.
- La nueva arquitectura debe mantener separadas UI, dominio, datos y transporte.

## Accessibility & Inclusion

La interfaz debe respetar los objetivos de accesibilidad de Material 3, mantener objetivos tactiles adecuados en movil y tablet, ofrecer contraste suficiente, estados de foco y errores claros, y respetar tamanos de texto y reduccion de movimiento del sistema.
