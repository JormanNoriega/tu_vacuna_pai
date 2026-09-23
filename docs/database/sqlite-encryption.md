# Encriptación de la base local (SQLite3MultipleCiphers)

- Estado: Implementada y verificada (guarda de regresión 4/4 + demo en verde)
- Fecha: 2026-09-22
- Alcance: app móvil Flutter (`apps/mobile`), base Drift/SQLite local
- Mitigación obligatoria de: [`ADR-003-ventana-offline.md`](../decisions/ADR-003-ventana-offline.md) ("Base local cifrada", "Clave de base local en secure storage")
- Complementa a: [`ADR-005-autenticacion-y-autorizacion-offline.md`](../decisions/ADR-005-autenticacion-y-autorizacion-offline.md) ("los secretos y tokens se guardan en almacenamiento seguro, nunca en SQLite")
- Verificación: `apps/mobile/test/core/storage/database_encryption_test.dart`, `apps/mobile/test/core/storage/database_encryption_demo_test.dart`, `scripts/demo-cifrado.ps1`

---

## 1. Contexto y amenaza

La app es **offline-first**: el vacunador registra pacientes, atenciones y dosis
sin conectividad, y todo ese working set clínico vive en un archivo SQLite
local (`tu_vacuna_pai.db`) gestionado con Drift.

Un SQLite "normal" es legible por cualquiera que obtenga el archivo: cabecera
`SQLite format 3` en texto plano, esquema, y datos de pacientes (documento,
nombres, direcciones) visibles con cualquier herramienta.

**Amenaza cubierta**: extracción del archivo de base (dispositivo perdido o
robado, copia por USB/backup, acceso físico al storage). El dato en reposo debe
ser indistinguible de ruido sin la clave.

**Amenaza NO cubierta** (ver §7 Limitaciones): dispositivo rooteado y
desbloqueado con acceso al secure storage, o un usuario legítimo autorizado.

## 2. Decisión

Cifrado **a nivel de archivo** con **SQLite3MultipleCiphers** (sqlite3mc),
compatible con SQLCipher, integrado al binario nativo de SQLite que compila el
proyecto. Se eligió cifrado de base completa (y no cifrado campo a campo) porque:

1. Es **transparente**: el SQL, Drift, las transacciones y los índices siguen
   funcionando igual; no hay lógica de cifrado en los repositorios.
2. Cifra **todo**: datos, esquema, índices, páginas libres y WAL. No filtra
   metadata por longitud ni patrones de columnas.
3. La clave vive fuera del archivo, en el secure storage del SO.

## 3. Cómo funciona SQLite3MultipleCiphers

El motor SQLite se modifica para que cada página (4 KiB) pase por el codec al
escribirse/leerse del disco:

```text
        INSERT / SELECT (SQL normal, sin cambios en el código)
                          │
                          ▼
                ┌───────────────────┐
                │  SQLite + codec   │  ← descifra página al leer
                │  (sqlite3mc)      │  ← cifra página al escribir
                └───────────────────┘
                          │
                          ▼
        pacientes.db  =  bytes cifrados (sin cabecera legible)
                          ▲
                          │ clave (256 bits)
                  secure storage del SO
```

Sin la clave correcta, el archivo ni siquiera se reconoce como base SQLite:
la lectura falla con `file is not a database`.

Parámetros activos en este proyecto (verificados empíricamente, §6):

| Parámetro | Valor | Significado |
| --- | --- | --- |
| `PRAGMA cipher` | `chacha20` | Esquema ChaCha20-Poly1305 (cifrado autenticado AEAD, default de sqlite3mc) |
| `PRAGMA kdf_iter` | `64007` | Derivación de clave PBKDF2-HMAC-SHA512, 64007 rondas |
| `PRAGMA cipher_memory_security` | `OFF` | Desactiva el borrado defensivo de memoria por rendimiento; no afecta el cifrado en disco |

## 4. Implementación

### 4.1 Compilación del binario cifrado (`pubspec.yaml:24-30`)

El punto crítico: `PRAGMA key` **es un no-op silencioso** sobre un binario
SQLite plano. Por eso el binario nativo que descarga `package:sqlite3` se
compila con el flavor `sqlite3mc`:

```yaml
# Cifrado real de la base local: el binario nativo de SQLite que `package:sqlite3`
# descarga vía hooks se compila con SQLite3MultipleCiphers (sqlite3mc, compatible
# con SQLCipher). Sin esta opcion, `PRAGMA key` era ignorado (ADR-003).
hooks:
  user_defines:
    sqlite3:
      source: sqlite3mc
```

Esto aplica a la app y a los tests (`flutter test` compila el binario para el
host), por lo que la verificación corre sin emulador ni dispositivo.

### 4.2 Gestión de la clave (`app_database.dart:329-342`)

- Clave de **256 bits generada con CSPRNG** (`Random.secure()`), expresada en
  hexadecimal, **solo en el primer arranque**.
- Se persiste en **`flutter_secure_storage`** (Keychain en iOS, Keystore en
  Android, DPAPI/CredMan en Windows): el secure storage cifra con las
  credenciales del SO y requiere que el dispositivo esté desbloqueado.
- La clave **nunca** se guarda en la base, en el código ni en SharedPreferences
  (mismo principio que ADR-005 para los JWT).

```dart
static const _databaseKeyName = 'local_db_key';

static Future<String> _loadOrCreateKey(FlutterSecureStorage storage) async {
  final existing = await storage.read(key: _databaseKeyName);
  if (existing != null && existing.isNotEmpty) return existing;

  final random = Random.secure();
  final bytes = List<int>.generate(32, (_) => random.nextInt(256));
  final key = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  await storage.write(key: _databaseKeyName, value: key);
  return key;
}
```

> Nota de diseño: la clave aleatoria se pasa como passphrase a `PRAGMA key`, y
> sqlite3mc aplica igualmente su KDF (PBKDF2-SHA512, 64007 rondas) para derivar
> la clave de cifrado de páginas. La entropía proviene del CSPRNG (256 bits), no
> de una contraseña humana, por lo que no aplica el problema de PINs débiles.

### 4.3 Apertura de la base (`app_database.dart:314-327`)

```dart
static Future<AppDatabase> open(FlutterSecureStorage storage) async {
  final key = await _loadOrCreateKey(storage);
  final connection = driftDatabase(
    name: 'tu_vacuna_pai',
    native: DriftNativeOptions(
      setup: (raw) {
        raw.execute("PRAGMA key = '$key'");
        // SQLite3MultipleCiphers exige este pragma para abrir bases SQLCipher.
        raw.execute('PRAGMA cipher_memory_security = OFF');
      },
    ),
  );
  return AppDatabase(connection);
}
```

El orden es obligatorio: primero `PRAGMA key` (antes de cualquier otra
operación), luego los pragmas de configuración del cifrador. Resto del esquema
Drift: [`docs/database/sqlite-schema.drift`](sqlite-schema.drift).

### 4.4 Qué se cifra

Todas las tablas locales: perfil (`CurrentUser`), caches de catálogos, working
set clínico (`PatientsLocal`, `PatientGuardiansLocal`, `AttentionsLocal`,
`AppliedDosesLocal`) y outbox de sincronización (`SyncOutbox`, cuyo `payload`
JSON contiene los datos completos de cada operación pendiente).

## 5. Advertencia de migración

Una base creada **sin cifrado** por un build anterior no puede abrirse con
clave (y viceversa). Como la base local es solo cache + working set
recreable con una validación online, la solución adoptada es eliminar el
archivo local (o reinstalar la app) antes del primer arranque con cifrado.
Esto está documentado en `AppDatabase.open`.

## 6. Verificación

### 6.1 Guarda de regresión (4 tests)

`flutter test test/core/storage/database_encryption_test.dart -r expanded`

1. **Secreto fuera de texto plano**: se guarda un valor, se cierra la base y se
   busca la cadena en los bytes del archivo → no está.
2. **Clave incorrecta rechazada**: abrir con otra clave y leer lanza
   `SqliteException` ("file is not a database").
3. **Clave correcta lee**: el dato se recupera intacto.
4. **Motor identificado**: `PRAGMA cipher` = `chacha20` y `PRAGMA kdf_iter` =
   `64007`. Sobre un binario SQLite plano estos pragmas no existen (responden
   sin filas), así que este test prueba que el cifrado está **compilado dentro
   del binario**, no solo que el archivo es opaco.

```text
00:00 +3: el binario nativo es SQLite3MultipleCiphers (pragmas de cifrado)
PRAGMA cipher   = chacha20
PRAGMA kdf_iter = 64007
00:00 +4: All tests passed!
```

### 6.2 Demo en caliente (script único, sin emulador)

```powershell
.\scripts\demo-cifrado.ps1
```

Ejecuta los 4 tests anteriores y luego la demo visual
(`database_encryption_demo_test.dart`), que crea una base cifrada en
`%TEMP%\tu_vacuna_pai_demo_cifrado\pacientes.db`, inserta un dato
"confidencial" y muestra en pantalla:

```text
Primeros 64 bytes del archivo:
06 7C 44 C9 76 71 C8 D0 9A 7D B8 62 40 34 77 0A 10 00 01 01 20 40 20 20 ...

Cabecera "SQLite format 3" en texto plano: NO (cifrada)
Lectura sin clave: RECHAZADA (file is not a database)
Lectura con clave correcta: OK -> PACIENTE_CONFIDENCIAL_12345
```

El archivo de demo **no se limpia**: queda disponible para inspección con
editor hexadecimal o el CLI `sqlite3` (que fallará al abrirlo sin clave).

## 7. Limitaciones (honestidad criptográfica)

| Límite | Consecuencia |
| --- | --- |
| La clave está en secure storage, no en hardware sellado | Con dispositivo rooteado/emulador y sesión desbloqueada, la clave es extraíble. El secure storage es la barrera, no la encriptación. |
| En memoria el dato está en claro | Mientras la app corre, las páginas están descifradas en RAM. Protege el reposo, no el uso. |
| No reemplaza la autorización | Un vacunador legítimo ve lo que le corresponde; el cifrado no discrimina entre usuarios del mismo dispositivo. |
| La seguridad de los tokens sigue en otro mecanismo | Los JWT/refresh viven en secure storage por ADR-005; nunca en SQLite. |
| La base sin cifrar vieja es irrecuperable con clave | Migración = recrear (§5). No hay conversión in-place implementada (`PRAGMA rekey` no se usa). |

## 8. Referencias de implementación

| Pieza | Ubicación |
| --- | --- |
| Compilación con sqlite3mc | `apps/mobile/pubspec.yaml:24-30` |
| Apertura con `PRAGMA key` | `apps/mobile/lib/core/storage/app_database.dart:314-327` |
| Generación/persistencia de clave | `apps/mobile/lib/core/storage/app_database.dart:329-342` |
| Guarda de regresión (4 tests) | `apps/mobile/test/core/storage/database_encryption_test.dart` |
| Demo visual | `apps/mobile/test/core/storage/database_encryption_demo_test.dart` |
| Script de demo | `scripts/demo-cifrado.ps1` |
| Paquete de cifrado | [SQLite3MultipleCiphers](https://github.com/utelle/SQLite3MultipleCiphers) (flavor `sqlite3mc` de `package:sqlite3`) |
