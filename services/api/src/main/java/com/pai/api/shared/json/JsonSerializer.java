package com.pai.api.shared.json;

import java.io.InputStream;
import org.springframework.stereotype.Component;
import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;

/**
 * Serializacion JSON unica de la aplicacion. Envuelve el {@link ObjectMapper}
 * configurado por Spring para que ningun servicio instancie el suyo (DIP) y para
 * centralizar el manejo de fallos (DRY).
 *
 * <p>{@link #write(Object)} propaga el fallo; {@link #writeOrEmpty(Object)}
 * expone la politica de "no romper la operacion de negocio por un fallo de
 * serializacion" que aplican auditores y registros de idempotencia.
 */
@Component
public class JsonSerializer {

  private final ObjectMapper mapper;

  public JsonSerializer(ObjectMapper mapper) {
    this.mapper = mapper;
  }

  /** Serializa a JSON; lanza {@link IllegalStateException} si el valor no es serializable. */
  public String write(Object value) {
    try {
      return mapper.writeValueAsString(value);
    } catch (Exception ex) {
      throw new IllegalStateException("No se pudo serializar el valor a JSON.", ex);
    }
  }

  /**
   * Serializa a JSON; devuelve {@code "{}"} si el valor es nulo o no serializable.
   * Pensado para payloads de trazabilidad, donde un fallo no debe abortar la
   * operacion de negocio.
   */
  public String writeOrEmpty(Object value) {
    if (value == null) {
      return "{}";
    }
    try {
      return mapper.writeValueAsString(value);
    } catch (Exception ex) {
      return "{}";
    }
  }

  /** Deserializa {@code json} a {@code type}; lanza {@link IllegalStateException} si no puede. */
  public <T> T read(String json, Class<T> type) {
    try {
      return mapper.readValue(json, type);
    } catch (Exception ex) {
      throw new IllegalStateException("No se pudo reconstruir el JSON.", ex);
    }
  }

  /**
   * Convierte un valor (mapa, DTO) al tipo destino. Lanza
   * {@link IllegalArgumentException} si el valor no es convertible, para que el
   * llamador lo trate como payload invalido.
   */
  public <T> T convert(Object value, Class<T> type) {
    try {
      return mapper.convertValue(value, type);
    } catch (Exception ex) {
      throw new IllegalArgumentException("Payload invalido.", ex);
    }
  }

  /**
   * Lee un arbol JSON desde un stream (recursos de seed y catalogos
   * versionados). Lanza {@link IllegalStateException} si no puede parsear.
   */
  public JsonNode readTree(InputStream input) {
    try {
      return mapper.readTree(input);
    } catch (Exception ex) {
      throw new IllegalStateException("No se pudo leer el JSON.", ex);
    }
  }
}
