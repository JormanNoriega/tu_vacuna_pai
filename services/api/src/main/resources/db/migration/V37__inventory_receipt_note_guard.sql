-- Guarda incorporada despues de aplicar V33; no se reescribe la migracion ya aplicada.
ALTER TABLE app.inventory_receipts ADD CONSTRAINT ck_receipt_difference_note
  CHECK (length(difference_note) <= 1000);
