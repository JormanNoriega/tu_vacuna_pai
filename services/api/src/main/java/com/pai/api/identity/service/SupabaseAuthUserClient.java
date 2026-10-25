package com.pai.api.identity.service;

/**
 * Clase legada de cliente HTTP directo.
 *
 * @deprecated Refactorizado formalmente bajo el patron estructural Adapter en
 *             favor de {@link SupabaseAuthAdapter} (Adapter) y
 *             {@link SupabaseAuthRestClient} (Adaptee).
 */
@Deprecated(forRemoval = true)
public class SupabaseAuthUserClient extends SupabaseAuthAdapter {

  public SupabaseAuthUserClient(SupabaseAuthRestClient restClient) {
    super(restClient);
  }
}
