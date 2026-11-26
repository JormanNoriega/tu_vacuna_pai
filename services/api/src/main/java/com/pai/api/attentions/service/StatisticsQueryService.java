package com.pai.api.attentions.service;

import com.pai.api.attentions.entity.AppliedDoseEntity;
import com.pai.api.attentions.entity.AttentionEntity;
import com.pai.api.attentions.repository.AppliedDoseRepository;
import com.pai.api.attentions.repository.AttentionRepository;
import com.pai.api.attentions.state.CancelledState;
import com.pai.api.identity.entity.UserEntity;
import com.pai.api.identity.repository.UserRepository;
import com.pai.api.reports.dto.StatisticsDashboardResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.DataStatusResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.KpisResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.PeriodResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.TimePointResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.VaccinatorProductivityResponse;
import com.pai.api.reports.dto.StatisticsDashboardResponse.VaccineDistributionResponse;
import com.pai.api.reports.service.StatisticsQuery;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.temporal.IsoFields;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class StatisticsQueryService implements StatisticsQuery {

  private final AttentionRepository attentions;
  private final AppliedDoseRepository doses;
  private final UserRepository users;

  public StatisticsQueryService(
      AttentionRepository attentions,
      AppliedDoseRepository doses,
      UserRepository users) {
    this.attentions = attentions;
    this.doses = doses;
    this.users = users;
  }

  @Override
  @Transactional(readOnly = true)
  public StatisticsDashboardResponse dashboard(
      UUID institutionId,
      Instant from,
      Instant to,
      String granularity) {

    String normalizedGranularity = normalizeGranularity(granularity);
    List<AttentionEntity> attentionRows = attentions
        .findByInstitutionIdAndAttentionDateBetweenOrderByAttentionDateAsc(institutionId, from, to)
        .stream()
        .filter(attention -> !(attention.getStatus() instanceof CancelledState))
        .toList();

    Set<UUID> attentionIds = attentionRows.stream().map(AttentionEntity::getId).collect(java.util.stream.Collectors.toSet());
    List<AppliedDoseEntity> activeDoses = attentionIds.isEmpty()
        ? List.of()
        : doses.findByAttentionIdInOrderByCreatedAtAsc(attentionIds).stream()
            .filter(dose -> dose.getStatus() == AppliedDoseEntity.Status.REGISTERED)
            .filter(dose -> !dose.getApplicationDate().isBefore(from) && dose.getApplicationDate().isBefore(to))
            .toList();

    Map<UUID, AttentionEntity> attentionById = new HashMap<>();
    for (AttentionEntity attention : attentionRows) {
      attentionById.put(attention.getId(), attention);
    }

    Set<UUID> patientIds = new HashSet<>();
    Set<UUID> vaccinatorIds = new HashSet<>();
    Map<String, Long> dosesBySeriesBucket = new LinkedHashMap<>();
    Map<String, Set<UUID>> patientsBySeriesBucket = new LinkedHashMap<>();

    Map<String, VaccineAccumulator> dosesByVaccine = new LinkedHashMap<>();
    Map<UUID, VaccinatorAccumulator> dosesByVaccinator = new LinkedHashMap<>();

    for (AppliedDoseEntity dose : activeDoses) {
      AttentionEntity attention = attentionById.get(dose.getAttentionId());
      if (attention == null) continue;

      patientIds.add(attention.getPatientId());
      vaccinatorIds.add(attention.getProfessionalId());

      String bucket = timeBucket(dose.getApplicationDate(), normalizedGranularity);
      dosesBySeriesBucket.merge(bucket, 1L, Long::sum);
      patientsBySeriesBucket.computeIfAbsent(bucket, key -> new HashSet<>()).add(attention.getPatientId());

      String vaccineName = dose.getVaccineNameSnapshot();
      String vaccineCode = dose.getVaccineCodeSnapshot();
      dosesByVaccine.computeIfAbsent(vaccineCode, key -> new VaccineAccumulator(vaccineName, vaccineCode))
          .doses++;

      dosesByVaccinator.computeIfAbsent(
          attention.getProfessionalId(),
          key -> new VaccinatorAccumulator(attention.getProfessionalId()))
          .add(attention.getPatientId());
    }

    List<TimePointResponse> doseSeries = new ArrayList<>();
    Set<String> allBuckets = new HashSet<>(dosesBySeriesBucket.keySet());
    allBuckets.addAll(patientsBySeriesBucket.keySet());
    List<String> orderedBuckets = allBuckets.stream().sorted().toList();
    for (String bucket : orderedBuckets) {
      doseSeries.add(new TimePointResponse(
          bucket,
          bucketStart(bucket, normalizedGranularity),
          dosesBySeriesBucket.getOrDefault(bucket, 0L),
          (long) patientsBySeriesBucket.getOrDefault(bucket, Set.of()).size()));
    }

    long totalDoses = activeDoses.size();
    long uniquePatients = patientIds.size();
    long activeVaccinators = vaccinatorIds.size();

    List<VaccineDistributionResponse> vaccineDistribution = dosesByVaccine.values().stream()
        .sorted((left, right) -> Long.compare(right.doses, left.doses))
        .map(vaccine -> new VaccineDistributionResponse(
            vaccine.name,
            vaccine.code,
            vaccine.doses,
            totalDoses == 0 ? 0.0 : (vaccine.doses * 100.0 / totalDoses)))
        .toList();

    List<UserEntity> vaccinatorUsers = vaccinatorIds.isEmpty()
        ? List.of()
        : users.findByInstitutionIdAndIdIn(institutionId, vaccinatorIds);
    Map<UUID, String> namesById = new HashMap<>();
    for (UserEntity user : vaccinatorUsers) {
      namesById.put(user.getId(), user.getFullName());
    }

    List<VaccinatorProductivityResponse> vaccinatorProductivity = dosesByVaccinator.values().stream()
        .sorted((left, right) -> Long.compare(right.doses, left.doses))
        .map(accumulator -> new VaccinatorProductivityResponse(
            accumulator.vaccinatorId.toString(),
            namesById.getOrDefault(accumulator.vaccinatorId, "Vacunador"),
            accumulator.doses,
            (long) accumulator.patientIds.size()))
        .toList();

    return new StatisticsDashboardResponse(
        new PeriodResponse(from, to, normalizedGranularity),
        new KpisResponse(
            totalDoses,
            uniquePatients,
            activeVaccinators,
            uniquePatients == 0 ? 0 : totalDoses / uniquePatients),
        doseSeries,
        vaccineDistribution,
        vaccinatorProductivity,
        new DataStatusResponse(Instant.now(), "server"));
  }

  private String normalizeGranularity(String granularity) {
    if (granularity == null) return "day";
    return switch (granularity.toLowerCase()) {
      case "week", "month" -> granularity.toLowerCase();
      default -> "day";
    };
  }

  private String timeBucket(Instant instant, String granularity) {
    var date = instant.atZone(ZoneOffset.UTC);
    return switch (granularity) {
      case "week" -> date.toLocalDate()
          .with(java.time.temporal.TemporalAdjusters.previousOrSame(java.time.DayOfWeek.MONDAY))
          .toString();
      case "month" -> date.toLocalDate().withDayOfMonth(1).toString();
      default -> date.toLocalDate().toString();
    };
  }

  private Instant bucketStart(String bucket, String granularity) {
    var date = java.time.LocalDate.parse(bucket);
    return date.atStartOfDay().toInstant(java.time.ZoneOffset.UTC);
  }

  private static class VaccineAccumulator {
    private final String name;
    private final String code;
    private long doses;

    private VaccineAccumulator(String name, String code) {
      this.name = name;
      this.code = code;
    }
  }

  private static class VaccinatorAccumulator {
    private final UUID vaccinatorId;
    private final Set<UUID> patientIds = new HashSet<>();
    private long doses;

    private VaccinatorAccumulator(UUID vaccinatorId) {
      this.vaccinatorId = vaccinatorId;
    }

    private void add(UUID patientId) {
      doses++;
      patientIds.add(patientId);
    }
  }
}
