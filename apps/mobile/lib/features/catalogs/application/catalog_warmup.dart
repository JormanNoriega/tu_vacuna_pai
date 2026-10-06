import '../../../core/auth/session_manager.dart';
import '../domain/repositories/catalog_repository.dart';

/// Precarga los catalogos que el flujo offline necesita (geografico, de
/// referencia, aseguradoras y catalogo efectivo) cuando la sesion esta en
/// linea, para que queden disponibles sin red.
///
/// Es best-effort: cada precarga es independiente y un fallo no bloquea; se
/// reintenta en el proximo arranque con conectividad.
class CatalogWarmup {
  const CatalogWarmup({required this.sessionManager, required this.repository});

  final SessionManager sessionManager;
  final CatalogRepository repository;

  Future<void> run() async {
    final token = (await sessionManager.loadSession())?.accessToken;
    if (token == null) return;
    await _ignore(() => repository.listReferenceCatalogs(token));
    await _ignore(() => repository.listInsurers(token));
    await _ignore(() => repository.listCountries(token));
    await _ignore(() => repository.listFullGeo(token));
    await _ignore(() => repository.listEffectiveCatalog(token));
  }

  Future<void> _ignore(Future<Object?> Function() action) async {
    try {
      await action();
    } catch (_) {
      // Precarga best-effort: se reintenta en el proximo arranque online.
    }
  }
}
