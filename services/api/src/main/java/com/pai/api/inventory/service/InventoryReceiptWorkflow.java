package com.pai.api.inventory.service;

import java.util.UUID;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** La recepción y su finalización administrativa automática se confirman juntas. */
@Service
public class InventoryReceiptWorkflow {
  private final InventoryService inventory;
  private final CustodyWorkflowService custody;

  public InventoryReceiptWorkflow(InventoryService inventory, CustodyWorkflowService custody) {
    this.inventory=inventory; this.custody=custody;
  }

  @Transactional
  public InventoryService.ReceiptResult receive(UUID actor, UUID institution, UUID assignment,
      UUID operation, int vials, String note) {
    var result=inventory.receivePartial(actor,institution,assignment,operation,vials,note);
    custody.afterReceipt(actor,institution,assignment);
    return result;
  }
}
