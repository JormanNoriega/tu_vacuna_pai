package com.pai.api.geography;

import com.github.benmanes.caffeine.cache.Caffeine;
import java.time.Duration;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.cache.CacheManager;
import org.springframework.cache.annotation.EnableCaching;
import org.springframework.cache.caffeine.CaffeineCacheManager;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@EnableCaching
@ConditionalOnProperty(name = "app.geography.enabled", havingValue = "true")
class GeographyConfiguration {
  @Bean
  CacheManager geographyCacheManager(
      @Value("${app.geography.cache-ttl:30m}") Duration ttl,
      @Value("${app.geography.cache-maximum-size:500}") long maximumSize) {
    CaffeineCacheManager manager = new CaffeineCacheManager("geographyAttentions");
    manager.setCaffeine(Caffeine.newBuilder().expireAfterWrite(ttl).maximumSize(maximumSize));
    return manager;
  }
}
