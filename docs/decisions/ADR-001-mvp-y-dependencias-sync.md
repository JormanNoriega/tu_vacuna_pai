# ADR-001: MVP y dependencias de sincronización

- Estado: Aceptada
- Fecha: 2026-08-23
- Alcance: Flutter, Spring Boot y sincronización offline

## Contexto

El caso de uso principal permite que un vacunador trabaje sin conexión y registre una cadena de operaciones relacionadas:

```text
CREATE_PATIENT → CREATE_ATTENTION → REGISTER_APPLIED_DOSE
```

Si el cliente envía una dosis antes de que exista la atención en el servidor, la sincronización falla aunque los datos sean válidos localmente.

## Decisión

El MVP incluye un grafo simple de dependencias. No se implementa un motor de grafos general: se soporta una cadena de operaciones con dependencias opcionales.

Cada operación contiene:

```text
operation_id
command_type
aggregate_id
payload
depends_on_operation_id[]
```

El cliente debe enviar las operaciones respetando el orden de sus dependencias. Spring procesa el batch en ese orden y no acepta una operación que dependa de otra que todavía no llegó o que no fue aceptada.

## Comportamiento

```text
Dependencia aceptada
  → se procesa la operación siguiente

Dependencia ausente
  → operación REJECTED / DEPENDENCY_NOT_FOUND

Dependencia fallida
  → operaciones dependientes BLOCKED o REJECTED

operation_id repetido
  → se devuelve la respuesta original sin reprocesar
```

La transacción de cada comando es atómica. La persistencia del agregado y de `processed_operations` debe ocurrir de forma consistente.

## Consecuencias

### Positivas

- El caso normal paciente → atención → dosis funciona desde el MVP.
- El comportamiento es determinista y fácil de probar.
- No se introduce infraestructura innecesaria.
- La idempotencia permite reintentos seguros.

### Negativas

- El cliente debe mantener correctamente el orden de la cola.
- Un error en una operación puede bloquear operaciones dependientes.
- Las cadenas muy complejas requerirán una evolución posterior del protocolo.

## Fuera de alcance

- Reordenamiento automático de dependencias recibidas hacia adelante.
- Resolución automática de conflictos clínicos.
- Motor de planificación o grafo distribuido.
