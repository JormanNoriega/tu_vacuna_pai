package com.pai.api.inventory.service;

import com.pai.api.identity.service.DataScope;
import com.pai.api.shared.security.PermissionGuard;
import java.time.Instant;
import java.util.List;
import java.util.Objects;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Isolation;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.server.ResponseStatusException;

/**
 * Evidencia explícita, no saldo ni autorización sanitaria. Todas las escrituras
 * serializan por entrega, igual que recepción y novedades. Los conteos son
 * instantáneas acumuladas, nunca movimientos ni consumos inferidos.
 */
@Service
public class CustodyWorkflowService {
  private final JdbcTemplate db;
  private final PermissionGuard guard;
  private final DataScope scope;
  private final boolean enabled;

  public CustodyWorkflowService(JdbcTemplate db, PermissionGuard guard, DataScope scope,
      @Value("${app.inventory.custody-workflow-enabled:false}") boolean enabled) {
    this.db = db; this.guard = guard; this.scope = scope; this.enabled = enabled;
  }

  public record Count(UUID id, int closedVials, int openVials, int exhaustedVials,
      int discardedVials, int discardedDoses, String note, UUID recordedBy, Instant recordedAt) {}
  public record ClinicalDose(UUID id, Instant applicationDate, String status, String attentionStatus,
      boolean linked) {}
  public record Decision(UUID id, String kind, String note, UUID recordedBy, Instant recordedAt) {}
  public record Review(UUID id, UUID countId, String basis, String note, UUID recordedBy, Instant recordedAt) {}
  public record Workflow(UUID assignmentId, boolean recordingEnabled, int receivedVials,
      long declaredEventVials, long pendingReturnVials, long registeredLinkedDoses, long cancelledLinkedDoses,
      List<Count> counts, List<ClinicalDose> clinicalDoses, Decision finalization,
      Review review, String basis, Long unaccountedVials, String custodyState,
      String transferStatus, int dispatchedVials, int resolvedVials) {}
  private record Assignment(UUID lot, UUID custodian, int sent, int received, int resolved,
      String status, UUID vaccine, String lotNumber) {}

  private UUID authorize(UUID actor, UUID institution, boolean mine, boolean write) {
    return scope.resolveInstitutionId(guard.require(actor, mine ? "ATTENTION_CREATE"
        : write ? "INVENTORY_WRITE" : "INVENTORY_READ"), Objects.requireNonNull(institution));
  }

  private Assignment assignment(UUID institution, UUID id, UUID actor, boolean mine, boolean lock) {
    if (lock) {
      // Bloquear solo la entrega: no invertir el orden lote/entrega usado por despachos.
      db.queryForList("SELECT id FROM app.inventory_assignments WHERE institution_id=? AND id=?"
          + (mine ? " AND vaccinator_id=?" : "") + " FOR UPDATE",
          mine ? new Object[]{institution,id,actor} : new Object[]{institution,id});
    }
    var rows = db.query("SELECT a.lot_id,a.vaccinator_id,a.vial_count,a.received_vials,"
        + "a.resolved_vials,a.status,l.vaccine_id,l.lot_number FROM app.inventory_assignments a "
        + "JOIN app.inventory_lots l ON l.institution_id=a.institution_id AND l.id=a.lot_id "
        + "WHERE a.institution_id=? AND a.id=?" + (mine ? " AND a.vaccinator_id=?" : "")
        ,
        (rs, n) -> new Assignment(rs.getObject(1, UUID.class), rs.getObject(2, UUID.class),
            rs.getInt(3), rs.getInt(4), rs.getInt(5), rs.getString(6),
            rs.getObject(7, UUID.class), rs.getString(8)),
        mine ? new Object[]{institution, id, actor} : new Object[]{institution, id});
    if (rows.isEmpty()) throw new IllegalArgumentException("Entrega no encontrada en tu ámbito.");
    return rows.getFirst();
  }

  private void requireEnabled() {
    if (!enabled) throw new ResponseStatusException(HttpStatus.SERVICE_UNAVAILABLE,
        "El registro de custodia requiere aplicar V39 y habilitar APP_INVENTORY_CUSTODY_WORKFLOW_ENABLED.");
  }

  private static String note(String value) {
    if (value == null || value.isBlank() || value.trim().length() > 1000)
      throw new IllegalArgumentException("Describe la evidencia (hasta 1000 caracteres).");
    return value.trim();
  }

  private List<Count> counts(UUID institution, UUID id) {
    return db.query("SELECT * FROM app.inventory_custody_counts WHERE institution_id=? "
        + "AND assignment_id=? ORDER BY sequence DESC",
        (rs,n) -> new Count(rs.getObject("id",UUID.class),rs.getInt("closed_vials"),rs.getInt("open_vials"),
            rs.getInt("exhausted_vials"),rs.getInt("discarded_vials"),rs.getInt("discarded_doses"),
            rs.getString("note"),rs.getObject("recorded_by",UUID.class),rs.getTimestamp("recorded_at").toInstant()),
        institution,id);
  }

  private List<ClinicalDose> clinical(UUID institution, Assignment a, UUID id, boolean linkedOnly) {
    // Un número de lote compatible propone candidatos; no atribuye consumo.
    return db.query("SELECT d.id,d.application_date,d.status,t.status AS attention_status,"
        + "x.id AS link_id FROM app.applied_doses d "
        + "JOIN app.attentions t ON t.id=d.attention_id "
        + "LEFT JOIN app.inventory_clinical_links x ON x.dose_id=d.id "
        + "WHERE t.institution_id=? AND t.professional_id=? "
        + (linkedOnly ? "AND x.institution_id=? AND x.assignment_id=? "
            : "AND d.vaccine_id=? AND lower(trim(d.lot_number))=lower(trim(?)) "
              + "AND (x.id IS NULL OR (x.institution_id=? AND x.assignment_id=?)) ")
        + "ORDER BY d.application_date DESC,d.id",
        (rs,n) -> new ClinicalDose(rs.getObject(1,UUID.class),rs.getTimestamp(2).toInstant(),
            rs.getString(3),rs.getString(4),rs.getObject(5)!=null),
        linkedOnly ? new Object[]{institution,a.custodian(),institution,id}
            : new Object[]{institution,a.custodian(),a.vaccine(),a.lotNumber(),institution,id});
  }

  @Transactional(readOnly = true, isolation = Isolation.REPEATABLE_READ)
  public Workflow read(UUID actor, UUID institution, UUID id, boolean mine) {
    UUID inst = authorize(actor,institution,mine,false);
    Assignment a = assignment(inst,id,actor,mine,false);
    if (!enabled) return new Workflow(id,false,a.received(),0,0,0,0,List.of(),List.of(),
        null,null,"",null,"NOT_ENABLED",a.status(),a.sent(),a.resolved());
    // Lectura clínica requiere también el permiso clínico, aun sin datos de paciente.
    var profile = guard.require(actor, mine ? "ATTENTION_CREATE" : "INVENTORY_READ");
    boolean clinicalRead = mine || profile.getPermissions().contains("ATTENTION_READ");
    return snapshot(inst,id,a,clinicalRead);
  }

  private Workflow snapshot(UUID inst, UUID id, Assignment a, boolean clinicalRead) {
    var cs = counts(inst,id);
    var doses = clinical(inst,a,id,true);
    long registered = doses.stream().filter(d -> d.status().equals("REGISTERED")
        && !d.attentionStatus().equals("CANCELLED")).count();
    long cancelled = doses.size()-registered;
    var events = db.queryForMap("SELECT COALESCE(SUM(vial_count),0) AS total,"
        + "COALESCE(SUM(CASE WHEN status='RETURN_PENDING' THEN vial_count ELSE 0 END),0) AS pending,"
        + "COUNT(*) AS n FROM app.inventory_custody_events WHERE institution_id=? AND assignment_id=?",inst,id);
    long declared = ((Number)events.get("total")).longValue();
    long pending = ((Number)events.get("pending")).longValue();
    String basis = a.received()+":"+a.resolved()+":"+a.status()+":"+declared+":"+pending+":"
        +events.get("n")+":"+registered+":"+cancelled+":"+(cs.isEmpty()?"none":cs.getFirst().id());
    var finals = db.query("SELECT * FROM app.inventory_transfer_finalizations WHERE institution_id=? AND assignment_id=?",
        (rs,n) -> new Decision(rs.getObject("id",UUID.class),rs.getString("kind"),rs.getString("note"),
            rs.getObject("recorded_by",UUID.class),rs.getTimestamp("recorded_at").toInstant()),inst,id);
    var reviews = db.query("SELECT * FROM app.inventory_custody_reviews WHERE institution_id=? AND assignment_id=? "
        + "ORDER BY sequence DESC",
        (rs,n) -> new Review(rs.getObject("id",UUID.class),rs.getObject("count_id",UUID.class),rs.getString("basis"),
            rs.getString("note"),rs.getObject("recorded_by",UUID.class),rs.getTimestamp("recorded_at").toInstant()),inst,id);
    Long unaccounted = null;
    String state = "COUNT_REQUIRED";
    Review review = reviews.isEmpty()?null:reviews.getFirst();
    if (!cs.isEmpty()) {
      Count c = cs.getFirst();
      unaccounted = (long)a.received()-declared-c.closedVials()-c.openVials()-c.exhaustedVials()-c.discardedVials();
      state = unaccounted!=0 || cancelled>0 ? "REQUIRES_REVIEW"
          : review==null || !review.basis().equals(basis) ? "REVIEW_REQUIRED"
          : c.closedVials()>0 || c.openVials()>0 || pending>0 ? "REVIEWED_CUSTODY_CONTINUES" : "REVIEWED";
    }
    return new Workflow(id,true,a.received(),declared,pending,registered,cancelled,cs,
        clinicalRead?clinical(inst,a,id,false):List.of(),finals.isEmpty()?null:finals.getFirst(),
        review,basis,unaccounted,state,a.status(),a.sent(),a.resolved());
  }

  @Transactional
  public UUID recordCount(UUID actor, UUID institution, UUID assignmentId, Count request) {
    UUID inst = authorize(actor,institution,true,true);
    requireEnabled();
    Assignment a = assignment(inst,assignmentId,actor,true,true);
    if (a.received()<=0) throw new IllegalArgumentException("Primero confirma una recepción positiva.");
    String detail = note(request.note());
    Objects.requireNonNull(request.id());
    if (request.closedVials()<0 || request.openVials()<0 || request.exhaustedVials()<0
        || request.discardedVials()<0 || request.discardedDoses()<0)
      throw new IllegalArgumentException("Las cantidades no pueden ser negativas.");
    var prior = counts(inst,assignmentId).stream().filter(c->c.id().equals(request.id())).findFirst();
    if (prior.isPresent()) {
      Count p=prior.get();
      if (p.closedVials()!=request.closedVials() || p.openVials()!=request.openVials()
          || p.exhaustedVials()!=request.exhaustedVials() || p.discardedVials()!=request.discardedVials()
          || p.discardedDoses()!=request.discardedDoses() || !p.note().equals(detail) || !p.recordedBy().equals(actor))
        throw new IllegalArgumentException("Identificador de conteo usado con otros datos.");
      return request.id();
    }
    // Se conserva también un conteo discrepante: no ajustar ni declarar pérdida.
    db.update("INSERT INTO app.inventory_custody_counts (id,institution_id,lot_id,assignment_id,"
        + "closed_vials,open_vials,exhausted_vials,discarded_vials,discarded_doses,note,recorded_by) "
        + "VALUES (?,?,?,?,?,?,?,?,?,?,?)",request.id(),inst,a.lot(),assignmentId,request.closedVials(),
        request.openVials(),request.exhaustedVials(),request.discardedVials(),request.discardedDoses(),detail,actor);
    return request.id();
  }

  @Transactional
  public UUID linkDose(UUID actor, UUID institution, UUID assignmentId, UUID operationId,
      UUID doseId, String evidence, boolean mine) {
    UUID inst=authorize(actor,institution,mine,true);
    if (!mine) guard.require(actor,"ATTENTION_READ");
    requireEnabled();
    Assignment a=assignment(inst,assignmentId,actor,mine,true);
    String detail=note(evidence);
    Objects.requireNonNull(operationId); Objects.requireNonNull(doseId);
    // Bloquea la dosis para serializar atribuciones entre entregas diferentes.
    var ds=db.query("SELECT d.vaccine_id,d.lot_number,d.status,t.status AS attention_status,"
        + "t.professional_id FROM app.applied_doses d JOIN app.attentions t ON t.id=d.attention_id "
        + "WHERE d.id=? AND t.institution_id=? FOR UPDATE",
        (rs,n)->new Object[]{rs.getObject(1,UUID.class),rs.getString(2),rs.getString(3),
            rs.getString(4),rs.getObject(5,UUID.class)},doseId,inst);
    if (ds.isEmpty()) throw new IllegalArgumentException("Aplicación no encontrada en la institución.");
    var previous=db.queryForList("SELECT * FROM app.inventory_clinical_links WHERE dose_id=?",doseId);
    if (!previous.isEmpty()) {
      var p=previous.getFirst();
      if (!operationId.equals(p.get("id")) || !assignmentId.equals(p.get("assignment_id"))
          || !inst.equals(p.get("institution_id")) || !actor.equals(p.get("recorded_by")) || !detail.equals(p.get("note")))
        throw new IllegalArgumentException("La aplicación ya tiene otro vínculo.");
      return operationId;
    }
    Object[] d=ds.getFirst();
    if (a.received()<=0 || !a.vaccine().equals(d[0]) || d[1]==null
        || !a.lotNumber().trim().equalsIgnoreCase(d[1].toString().trim()) || !a.custodian().equals(d[4])
        || !"REGISTERED".equals(d[2]) || "CANCELLED".equals(d[3]))
      throw new IllegalArgumentException("Verifica vacuna, lote, vacunador y vigencia de la aplicación.");
    db.update("INSERT INTO app.inventory_clinical_links "
        + "(id,institution_id,lot_id,assignment_id,dose_id,note,recorded_by) VALUES (?,?,?,?,?,?,?)",
        operationId,inst,a.lot(),assignmentId,doseId,detail,actor);
    return operationId;
  }

  @Transactional
  public UUID finalizeTransfer(UUID actor, UUID institution, UUID id, UUID operationId, String evidence) {
    UUID inst=authorize(actor,institution,false,true); requireEnabled();
    Assignment a=assignment(inst,id,actor,false,true);
    return finalizeLocked(actor,inst,id,a,operationId,"ADMIN_REVIEW",note(evidence),false);
  }

  /** Solo el orquestador de recepción, en la misma transacción. No endpoint automático público. */
  @Transactional
  public void afterReceipt(UUID actor, UUID institution, UUID id) {
    if (!enabled) return;
    UUID inst=authorize(actor,institution,true,true);
    Assignment a=assignment(inst,id,actor,true,true);
    if (a.status().equals("RECEIVED") && a.received()==a.sent() && a.resolved()==0) {
      Long clean=db.queryForObject("SELECT COUNT(*) FROM app.inventory_receipts "
          + "WHERE institution_id=? AND assignment_id=? AND vials=? AND length(trim(difference_note))=0",
          Long.class,inst,id,a.sent());
      Long all=db.queryForObject("SELECT COUNT(*) FROM app.inventory_receipts WHERE institution_id=? AND assignment_id=?",
          Long.class,inst,id);
      Long events=db.queryForObject("SELECT COUNT(*) FROM app.inventory_custody_events WHERE institution_id=? AND assignment_id=?",
          Long.class,inst,id);
      if (clean!=null && clean==1 && all!=null && all==1 && events!=null && events==0)
        finalizeLocked(actor,inst,id,a,id,"AUTOMATIC","Recepción completa sin diferencias.",true);
    }
  }

  private UUID finalizeLocked(UUID actor, UUID inst, UUID id, Assignment a, UUID operationId,
      String kind, String evidence, boolean automatic) {
    Objects.requireNonNull(operationId);
    var prior=db.queryForList("SELECT * FROM app.inventory_transfer_finalizations WHERE institution_id=? AND assignment_id=?",inst,id);
    if (!prior.isEmpty()) {
      var p=prior.getFirst();
      if (automatic) return (UUID)p.get("id");
      if (!operationId.equals(p.get("id")) || !actor.equals(p.get("recorded_by"))
          || !kind.equals(p.get("kind")) || !evidence.equals(p.get("note")))
        throw new IllegalArgumentException("La transferencia ya fue finalizada. Actualiza el seguimiento.");
      return operationId;
    }
    if ((long)a.received()+a.resolved()!=a.sent()
        || (!a.status().equals("RECEIVED") && !a.status().equals("CLOSED_WITH_DIFFERENCE")))
      throw new IllegalArgumentException("Resuelve la diferencia de traslado antes de finalizar.");
    var receipt=db.queryForMap("SELECT COUNT(*) AS n,COALESCE(SUM(vials),0) AS total FROM app.inventory_receipts "
        + "WHERE institution_id=? AND assignment_id=?",inst,id);
    if (((Number)receipt.get("n")).longValue()>0 && ((Number)receipt.get("total")).longValue()!=a.received())
      throw new IllegalArgumentException("La evidencia de recepción no coincide.");
    Long invalid=db.queryForObject("SELECT COUNT(*) FROM app.inventory_receipts WHERE institution_id=? "
        + "AND assignment_id=? AND (lot_id<>? OR received_by<>? OR vials<0)",Long.class,inst,id,a.lot(),a.custodian());
    Long resolved=db.queryForObject("SELECT COALESCE(SUM(vial_count),0) FROM app.inventory_difference_resolutions "
        + "WHERE institution_id=? AND assignment_id=?",Long.class,inst,id);
    if (invalid==null || invalid!=0 || resolved==null || resolved!=a.resolved())
      throw new IllegalArgumentException("La evidencia de traslado requiere revisión.");
    db.update("INSERT INTO app.inventory_transfer_finalizations "
        + "(id,institution_id,lot_id,assignment_id,kind,recorded_by,note) VALUES (?,?,?,?,?,?,?)",
        operationId,inst,a.lot(),id,kind,actor,evidence);
    return operationId;
  }

  @Transactional
  public UUID review(UUID actor, UUID institution, UUID id, UUID operationId, UUID countId,
      String expectedBasis, String evidence) {
    UUID inst=authorize(actor,institution,false,true); requireEnabled();
    Assignment a=assignment(inst,id,actor,false,true);
    String detail=note(evidence);
    var prior=db.queryForList("SELECT * FROM app.inventory_custody_reviews WHERE institution_id=? AND id=?",inst,operationId);
    if (!prior.isEmpty()) {
      var p=prior.getFirst();
      if (!id.equals(p.get("assignment_id")) || !countId.equals(p.get("count_id"))
          || !expectedBasis.equals(p.get("basis")) || !actor.equals(p.get("recorded_by")) || !detail.equals(p.get("note")))
        throw new IllegalArgumentException("Identificador de revisión usado con otros datos.");
      return operationId;
    }
    Workflow w=snapshot(inst,id,a,false);
    if (w.counts().isEmpty() || !w.counts().getFirst().id().equals(countId) || !w.basis().equals(expectedBasis))
      throw new IllegalArgumentException("La evidencia cambió. Actualiza antes de revisar.");
    if (w.unaccountedVials()!=0 || w.cancelledLinkedDoses()>0)
      throw new IllegalArgumentException("Hay diferencias o aplicaciones anuladas pendientes. No se puede aceptar la conciliación.");
    if (w.finalization()==null)
      throw new IllegalArgumentException("Finaliza primero la transferencia; la custodia continuará por separado.");
    db.update("INSERT INTO app.inventory_custody_reviews "
        + "(id,institution_id,assignment_id,count_id,basis,note,recorded_by) VALUES (?,?,?,?,?,?,?)",
        operationId,inst,id,countId,expectedBasis,detail,actor);
    return operationId;
  }
}
