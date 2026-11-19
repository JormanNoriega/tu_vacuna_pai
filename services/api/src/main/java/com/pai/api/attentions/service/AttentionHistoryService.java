package com.pai.api.attentions.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.identity.service.AuthorizedUser;
import com.pai.api.identity.service.DataScope;
import com.pai.api.identity.service.IdentityPermissions;
import com.pai.api.identity.service.RoleCodes;
import com.pai.api.reports.domain.PatientIdentity;
import com.pai.api.reports.service.PatientIdentityQuery;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import java.util.stream.Collectors;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Slice;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

@Service
public class AttentionHistoryService {
  private static final int PAGE_SIZE = 20;
  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;
  private final UserRepository users;
  private final PatientIdentityQuery patients;
  private final DataScope scope;

  public AttentionHistoryService(AttentionRepository attentions, AppliedDoseRepository doses,
      UserRepository users, PatientIdentityQuery patients, DataScope scope) {
    this.attentions = attentions;
    this.doses = doses;
    this.users = users;
    this.patients = patients;
    this.scope = scope;
  }

  public record Dose(String vaccine, String label, String lot, String status) {}
  public record Item(UUID id, UUID patientId, String patientName, String document,
      String professionalName, Instant date, String status, Long consecutive,
      String observations, List<Dose> doses) {}
  public record HistoryPage(List<Item> items, boolean hasNext) {}

  @Transactional(readOnly = true)
  public HistoryPage history(AuthorizedUser actor, Instant from, Instant to, int page) {
    if (from == null || to == null || !from.isBefore(to)
        || Duration.between(from, to).compareTo(Duration.ofDays(367)) > 0
        || page < 0 || page > 10000) {
      throw new ResponseStatusException(HttpStatus.BAD_REQUEST, "Rango o pagina invalida.");
    }
    UUID institutionId = scope.institutionOf(actor);
    boolean admin = actor.hasPermission(IdentityPermissions.USER_MANAGE)
        || (actor.getRoles() != null && actor.getRoles().contains(RoleCodes.ADMIN_INSTITUTION));
    Slice<AttentionEntity> result = admin
        ? attentions.historyPage(institutionId, from, to, PageRequest.of(page, PAGE_SIZE))
        : attentions.personalHistoryPage(
            institutionId, actor.getId(), from, to, PageRequest.of(page, PAGE_SIZE));
    if (result.isEmpty()) return new HistoryPage(List.of(), false);

    var patientIds = result.stream().map(AttentionEntity::getPatientId).collect(Collectors.toSet());
    var professionalIds = result.stream().map(AttentionEntity::getProfessionalId).collect(Collectors.toSet());
    var attentionIds = result.stream().map(AttentionEntity::getId).collect(Collectors.toSet());
    Map<UUID, PatientIdentity> patientMap = patients.byIds(patientIds).stream()
        .collect(Collectors.toMap(PatientIdentity::id, p -> p));
    Map<UUID, String> names = users.findByInstitutionIdAndIdIn(institutionId, professionalIds).stream()
        .collect(Collectors.toMap(UserEntity::getId, UserEntity::getFullName));
    Map<UUID, List<AppliedDoseEntity>> doseMap = doses.findByAttentionIdInOrderByCreatedAtAsc(attentionIds)
        .stream().collect(Collectors.groupingBy(AppliedDoseEntity::getAttentionId));
    List<Item> items = result.stream().map(a -> {
      PatientIdentity p = patientMap.get(a.getPatientId());
      String name = p == null ? "Paciente no disponible" :
          (p.firstName() + " " + p.lastName()).trim();
      String document = p == null ? "" : p.documentType() + " " + p.documentNumber();
      List<Dose> itemDoses = doseMap.getOrDefault(a.getId(), List.of()).stream()
          .map(d -> new Dose(d.getVaccineNameSnapshot(), d.getDoseLabelSnapshot(),
              d.getLotNumber(), d.getStatus().name())).toList();
      return new Item(a.getId(), a.getPatientId(), name, document,
          names.getOrDefault(a.getProfessionalId(), "Profesional no disponible"),
          a.getAttentionDate(), a.getStatus().code(), a.getConsecutive(),
          a.getObservations(), itemDoses);
    }).toList();
    return new HistoryPage(items, result.hasNext());
  }
}
