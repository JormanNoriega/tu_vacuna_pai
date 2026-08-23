# Invariantes de dominio compartidas

Este documento es la referencia funcional común para Flutter (Dart) y Spring Boot (Java). Cada regla puede tener una implementación local en Flutter para mejorar la experiencia offline, pero Spring Boot siempre es la autoridad final.

## Principios

- Flutter valida localmente las reglas deterministas que puede conocer sin conexión.
- Spring repite esas validaciones y agrega estado global, permisos, scope, concurrencia y auditoría.
- Una validación local incorrecta nunca debe convertirse en una autorización de seguridad.
- Los DTOs y comandos pueden generarse o validarse desde OpenAPI, pero las reglas de dominio viven en este documento y en sus pruebas.
- Cada cambio de una invariante requiere actualizar sus pruebas en Dart y Java.

## Matriz de invariantes

| Invariante | Validación Flutter | Validación Spring | Autoridad final |
|---|---|---|---|
| Una `Attention` `COMPLETED` no se edita | Bloquea la acción y no genera `UPDATE_ATTENTION` | Rechaza la modificación | Spring |
| Una `Attention` solo se completa desde un estado válido | Valida transición local | Valida estado oficial y transición | Spring |
| Una atención anulada no recibe nuevas dosis | Bloquea el formulario | Rechaza el comando | Spring |
| `AppliedDose` es append-only | No genera UPDATE/DELETE; solo cancelación con motivo | Rechaza UPDATE/DELETE y exige motivo para cancelar | Spring |
| Todo paciente debe tener identificador UUID | Genera UUID local | Valida formato y unicidad | Spring |
| Los campos obligatorios deben estar completos | Valida antes de guardar localmente | Valida request y dominio | Spring |
| Un paciente duplicado no se mergea automáticamente | Marca candidato local y evita auto-merge | Crea `PatientMergeRequest` | Spring + revisión humana |
| Un merge de identidad requiere administrador | No ofrece merge offline | Exige `MERGE_RESOLVE` y scope institucional | Spring |
| Los catálogos no se modifican offline | Caché de solo lectura | Solo `SUPER_ADMIN` puede escribir | Spring |
| Solo `VACCINATOR` puede generar operaciones clínicas offline | Consulta capacidades locales | Revalida permiso actual al sincronizar | Spring |
| Una operación offline debe tener `operation_id` | Genera UUID y lo persiste con el outbox | Aplica idempotencia | Spring |
| Una operación dependiente requiere dependencia aceptada | Ordena y envía la cadena | Rechaza dependencias ausentes o fallidas | Spring |
| Un usuario debe estar activo para sincronizar | Bloquea si la última validación lo indica | Consulta estado actual | Spring |
| Toda operación clínica sincronizada se audita | Conserva estado local | Crea `AuditEvent` | Spring |

## Estados de `Attention`

```text
DRAFT → IN_PROGRESS → COMPLETED
  └────────────────────────→ CANCELLED (con motivo)
```

Reglas:

- `DRAFT` e `IN_PROGRESS` permiten las modificaciones definidas por el caso de uso.
- `COMPLETED` es inmutable; solo puede anularse con motivo y trazabilidad.
- `CANCELLED` no permite nuevas modificaciones clínicas.
- El cliente puede bloquear una transición inválida antes de sincronizar, pero el servidor debe repetirla.

## Estados de `AppliedDose`

```text
REGISTERED → CANCELLED(reason, actor, timestamp)
```

No existe edición ni eliminación física. Una corrección se representa con una operación de cancelación y, si corresponde, una nueva dosis registrada.

## Regla de autorización

La UI puede ocultar botones, pero no autoriza. En cada request y en cada `push`, Spring debe validar:

```text
JWT válido
→ usuario activo
→ permiso actual
→ institución y scope
→ estado del agregado
→ invariante de dominio
→ transacción
→ auditoría
```

## Pruebas espejo

Los casos críticos deben existir en ambos stacks con los mismos nombres, entradas y resultados esperados:

```text
cannot_edit_completed_attention
cannot_update_applied_dose
requires_reason_to_cancel_dose
rejects_invalid_attention_transition
does_not_auto_merge_patient_identity
rejects_operation_without_accepted_dependency
```

Las pruebas de Dart protegen la experiencia local. Las pruebas de Java protegen la integridad y seguridad del sistema.
