# Estado actual del frontend Flutter

> Documento descriptivo del estado actual de `apps/mobile`. No introduce
> decisiones nuevas: registra cómo está organizado y construido el cliente
> Flutter hoy. Complementa a `architecture.md` y a los ADR (001–007).

---

## 1. Resumen

El cliente es una aplicación **Flutter** con:

- **Clean Architecture ligera + organización feature-first**: cada feature se
  divide en `domain/`, `data/` y `presentation/`.
- **Sin gestor de estado externo**: se usa `ChangeNotifier` +
  `AnimatedBuilder`. No hay Provider, Riverpod, BLoC ni GetX.
- **Sin librería de inyección de dependencias**: todo el grafo se construye a
  mano en `main.dart` (composition root).
- **Offline-first de autorización**: la ventana offline regula *qué* se puede
  escribir sin conexión, mientras los tokens y el perfil se guardan/localizan
  de forma segura.

Plan de la app: autenticación con Supabase + backend Spring, consulta y
registro de pacientes/atenciones, catálogos de vacunas y administración.

---

## 2. Estructura de carpetas

```text
apps/mobile/lib/
├── main.dart                     # composition root: crea e inyecta todo
├── app/
│   ├── app.dart                  # MaterialApp + AuthController + ruteo por sesión
│   ├── config/app_config.dart    # --dart-define (Supabase, API_BASE_URL)
│   └── theme/app_theme.dart      # tema visual
├── core/                         # infraestructura transversal
│   ├── auth/                     # sesión, política y autorización offline
│   ├── network/                  # ApiClient, ApiException, NetworkInfo, MeResponse
│   ├── storage/                  # AppDatabase (drift cifrado)
│   ├── presentation/             # AsyncController (base de los controladores)
│   └── utils/                    # normalizadores de documento/campos, uuid
└── features/<feature>/
    ├── domain/                   # entities + repositories (interfaz) + use_cases
    ├── data/                     # *RepositoryImpl (implementa la interfaz)
    └── presentation/             # *Controller (ChangeNotifier) + pages/
```

Dependencias externas relevantes (`pubspec.yaml`):

| Paquete | Uso |
|---|---|
| `supabase_flutter` | Autenticación (Supabase Auth) |
| `http` | Cliente HTTP hacia la API Spring |
| `flutter_secure_storage` | Tokens y clave de la base local |
| `drift` + `drift_flutter` | Caché local tipada sobre SQLite |
| `connectivity_plus` | Conectividad real del dispositivo |
| `sqlite3` (hook `source: sqlite3mc`) | Cifrado real de la base local (ADR-003) |

---

## 3. La regla de dependencias

Es el equivalente Flutter del `Controller → Service → Repository` del backend
(ADR-006), pero **con inversión de dependencia real**: la interfaz vive en
`domain/`.

```text
presentation  ──▶ domain  ◀── data
 (Page/Controller)   (entities,        (RepositoryImpl:
                      repositories,      ApiClient + AppDatabase)
                      use_cases)
```

- `domain/` no importa `data/` ni `presentation/`. Ej.: `PatientsRepository`
  (`features/patients/domain/repositories/patients_repository.dart`) es una
  interfaz abstracta.
- `data/` implementa la interfaz y traduce JSON ↔ entidad. Ej.:
  `PatientsRepositoryImpl` (`features/patients/data/patients_repository_impl.dart`).
- `presentation/` llama a **casos de uso**, nunca a `ApiClient` directamente.

---

## 4. Composition root (`main.dart`)

No hay contenedor de DI. `main.dart` (`apps/mobile/lib/main.dart:39-133`)
inicializa Supabase, abre la base cifrada y construye el grafo completo:

```dart
final secureStorage = const FlutterSecureStorage();
final apiClient     = ApiClient(baseUrl: AppConfig.apiBaseUrl);
final sessionManager = SessionManager(secureStorage);
final networkInfo   = ConnectivityNetworkInfo();
final appDatabase   = await AppDatabase.open(secureStorage);   // drift cifrado
final localSessionStore = LocalSessionStore(appDatabase);
final authRepository = SupabaseAuthRepository(
  apiClient, sessionManager, localSessionStore, networkInfo,
);

final patientsRepository   = PatientsRepositoryImpl(apiClient);
final attentionsRepository = AttentionsRepositoryImpl(apiClient);
final attentionController  = AttentionController(
  sessionManager: sessionManager,
  searchPatient: SearchPatient(patientsRepository),
  createAttention: CreateAttention(attentionsRepository),
  ...
);
runApp(TuVacunaApp(... controllers ...));
```

`TuVacunaApp` (`app/app.dart`) monta `MaterialApp`, crea el `AuthController` y
decide la pantalla raíz: splash mientras restaura la sesión, `LoginPage` si no
hay usuario y `DashboardPage` si lo hay. Los controladores bajan por
constructor.

---

## 5. Flujo de una operación

```text
Page (AnimatedBuilder escuchando al Controller)
   │  usuario pulsa un botón
   ▼
Controller (extiende AsyncController = ChangeNotifier)
   │  execute((token) => useCase(token, offline: ...))
   ▼
UseCase (domain)  →  aplica OfflinePolicy (permiso + ventana offline)
   ▼
Repository (interfaz en domain)
   ▼
RepositoryImpl (data)  →  ApiClient (HTTP) o AppDatabase (drift/SQLite)
```

Ejemplo: `AttentionController` (`features/attentions/presentation/attention_controller.dart`)
→ `RegisterDose` (`features/attentions/domain/use_cases/attentions_use_cases.dart:36`)
→ `OfflinePolicy.ensureWritable(...)` → `AttentionsRepository.registerDose` →
`ApiClient.registerDose`.

Las páginas se suscriben con `AnimatedBuilder(listenable: controller, ...)`.
Todos los controladores excepto `AuthController` heredan de `AsyncController`.

---

## 6. Core transversal

| Componente | Rol |
|---|---|
| `ApiClient` (`core/network/api_client.dart`) | Único cliente HTTP. Añade `Bearer` + header `Idempotency-Key`, aplica timeout y traduce errores a `ApiException`. Tipado como `Map<String, dynamic>`. |
| `AsyncController` (`core/presentation/async_controller.dart`) | Base de los controladores: obtiene el token, marca `isLoading`, traduce errores (`mapApiError`/`mapOfflineError`) y notifica. |
| `SessionManager` (`core/auth/session_manager.dart`) | Persiste tokens en `flutter_secure_storage` (nunca en SQLite). |
| `AppDatabase` (`core/storage/app_database.dart`) | Caché local con **drift**, cifrada con `PRAGMA key` (sqlite3mc). La clave se genera una vez y vive en almacenamiento seguro. `schemaVersion = 4` con migraciones incrementales. |
| `OfflinePolicy` (`core/auth/offline_policy.dart`) | Enum `OperationPermission`: cada operación declara `requiredPermission` y `offlineAuthorized`. `ensureWritable` valida según el `SessionStatus`. Excepciones: `OfflineLockedException`, `OfflineOperationNotAuthorizedException`, `OfflinePermissionDeniedException`. |
| `OfflineAccess` (`core/auth/offline_access.dart`) | Instantánea (`status` + `permissions`) que la UI resuelve y propaga hasta el caso de uso. |
| `OfflineAuthorizationService` | Decide si la sesión local entra (autorizado) o queda bloqueada: `now - lastOnlineValidation <= offlineWindowHours`. |
| `NetworkInfo` (`core/network/network_info.dart`) | Conectividad real del dispositivo (para distinguir `noNetwork` de `backendUnavailable`). |
| `core/utils/` | Normalización de documentos/campos (`document_normalizer`, `field_input`) y `uuid` para `operationId`. |

---

## 7. Autenticación y offline-first

`SupabaseAuthRepository` (`features/auth/data/supabase_auth_repository.dart`)
combina tres fuentes:

1. **Supabase Auth** (`signInWithPassword`) → tokens.
2. **`GET /api/v1/me`** en el backend Spring → perfil autorizado (roles,
   permisos, institución y `offlineWindowHours`).
3. Persistencia: tokens en almacenamiento seguro y perfil en drift
   (`LocalSessionStore`).

La restauración de sesión (`restoreSession`) devuelve un `SessionRestoreResult`
(`features/auth/domain/entities/session_restore_result.dart`) con uno de cuatro
estados (`SessionStatus`):

| Estado | Significado |
|---|---|
| `signedIn` | Sesión validada online. |
| `offlineAuthorized` | Sesión local dentro de la ventana offline. |
| `offlineLocked` | Ventana vencida: solo lectura local. |
| `signedOut` | Sin sesión restaurable (muestra login). |

Regla de roles: los administradores (`ADMIN_INSTITUTION`, `SUPER_ADMIN`) son
**online-first**; si no hay red o el backend no responde, la sesión se bloquea
y se vuelve al login con aviso (`SessionRestoreResult.adminBlocked`). El
personal clínico entra en modo offline mientras la ventana esté vigente.

Importante: **hoy el offline es de autorización, no de datos**. Todas las
`OperationPermission` actuales tienen `offlineAuthorized: false`, por lo que
toda escritura exige conexión. No existe todavía un `SyncEngine`/outbox que
encolaría operaciones para sincronizar; las escrituras clínicas son
*online-first* (se confirman con la respuesta del servidor).

---

## 8. Features

| Feature | `domain/` | `data/` | `presentation/` |
|---|---|---|---|
| **auth** | `AuthUser`, `SessionRestoreResult`, `AuthException`, `AuthRepository`, `SignIn`/`SignOut`/`RestoreSession` | `SupabaseAuthRepository`, `InMemoryAuthRepository`, `LocalSessionStore` | `AuthController` + `login_page` |
| **patients** | `Patient`, `NewPatientInput`, `PatientProfile`, `PatientsRepository`, `CreatePatient`/`SearchPatient`/perfil | `PatientsRepositoryImpl` (solo HTTP, sin caché) | `PatientDetailController` + wizard/detail |
| **attentions** | `Attention`/`AppliedDose`, `AttentionsRepository`, `CreateAttention`/`RegisterDose`/`CompleteAttention`/`CancelAttention`/`CancelDose`/`ListPatientAttentions` | `AttentionsRepositoryImpl` (solo HTTP) | `AttentionController`, `HistoryController` + páginas |
| **catalogs** | entidades de catálogo efectivo/geografía/opciones, `CatalogRepository`, casos de uso | `CatalogRepositoryImpl` (**HTTP + caché drift**) | `CatalogController` + páginas |
| **admin** | `Institution`, `InstitutionAdmin`, `CloneCatalogResult`, `AdminRepository`, casos de uso | `AdminRepositoryImpl` | `AdminController` + páginas |
| **users** | `Vaccinator`, `UsersRepository`, casos de uso | `UsersRepositoryImpl` (**HTTP + caché drift**) | `UsersController` + páginas |
| **dashboard** | — | — | `dashboard_page` (hub de navegación) |

---

## 9. Pruebas

Pruebas existentes en `apps/mobile/test/`:

- **Controladores**: `auth_controller_test`, `users_controller_test`,
  `attention_controller_test`, `admin_controller_test`,
  `patient_detail_controller_test`.
- **Core**: `async_controller_test`, `api_client_test`,
  `offline_policy_test`, `offline_authorization_service_test`,
  `database_encryption_test`.
- **Repositorios/entidades**: `patients_repository_test`,
  `supabase_auth_repository_test`, `local_session_store_test`,
  `catalog_entities_test`.
- **Widgets/utilidades**: `patient_wizard_page_test`, normalizadores de
  documento/campos.

Los repositorios se sustituyen por fakes (`fake_auth_repository`,
`fake_users_repository`, `fake_admin_repository`), lo que confirma que la
inversión de dependencia funciona.

---

## 10. Estado actual: implementado vs. pendiente

**Implementado**

- Autenticación con Supabase + revalidación de perfil contra la API Spring.
- Restauración de sesión online/offline con ventana autorizada y bloqueo por
  rol.
- Persistencia segura de tokens y base local cifrada.
- CRUD de pacientes, atenciones (crear/registrar/cancelar dosis, completar,
  cancelar) y su historial.
- Catálogos globales e institucionales con caché local.
- Administración de instituciones y usuarios (vacunadores, admins).
- Política offline centralizada en `core/auth`.

**Pendiente / no implementado**

- Sincronización offline real de datos (outbox + `SyncEngine`): no hay
  encolado ni reintento de escrituras clínicas.
- Caché local de pacientes y atenciones (hoy son 100% online).
- `offlineAuthorized: true` para cualquier operación: ninguna escritura se
  autoriza sin conexión todavía.

---

## 11. Deudas técnicas observadas

1. **`ApiClient` monolítico**: concentra todos los endpoints (~40 métodos) y
   todos los features dependen de él, rompiendo la modularidad por feature.
2. **Offline parcial**: solo `catalogs`, `users` y `admin` cachean en drift;
   `patients`/`attentions` no, y no existe sincronización.
3. **Inconsistencia estructural**: hay casos de uso en
   `features/*/application/use_cases/` (`admin`, `users`) mezclados con
   `features/*/domain/use_cases/`. Conviene unificar en `domain/use_cases`.
4. **DI manual que crecerá**: `main.dart` acumula el grafo completo; con más
   features conviene agrupar por módulos de composición.
5. **Páginas grandes**: p. ej. `patient_detail_page.dart` (~600 líneas);
   conviene extraer widgets.
6. **Mapeo JSON manual** en entidades y repositorios (sin `json_serializable`/
   `freezed`), con riesgo de desalinearse de los DTO del backend.
7. **Sin capa común de mapeo de errores**: cada controlador sobrescribe
   `mapApiError`/`mapOfflineError` (duplicación parcial).
