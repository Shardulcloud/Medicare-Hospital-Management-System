CREATE OR REPLACE TRIGGER trg_patient_audit
AFTER INSERT OR UPDATE OR DELETE ON patient
FOR EACH ROW
BEGIN
  IF INSERTING THEN audit_pkg.log_event('PATIENT','INSERT',:NEW.patient_code,:NEW.full_name);
  ELSIF UPDATING THEN audit_pkg.log_event('PATIENT','UPDATE',:NEW.patient_code,'Patient details updated');
  ELSIF DELETING THEN audit_pkg.log_event('PATIENT','DELETE',:OLD.patient_code,:OLD.full_name);
  END IF;
END;
/
CREATE OR REPLACE TRIGGER trg_bed_status
AFTER INSERT OR UPDATE OF status ON admission
FOR EACH ROW
BEGIN
  IF :NEW.status='ADMITTED' THEN UPDATE bed SET status='OCCUPIED' WHERE bed_id=:NEW.bed_id;
  ELSIF :NEW.status='DISCHARGED' THEN UPDATE bed SET status='FREE' WHERE bed_id=:NEW.bed_id;
  END IF;
END;
/
CREATE OR REPLACE TRIGGER trg_bill_number
BEFORE INSERT ON bill
FOR EACH ROW
BEGIN
  IF :NEW.bill_number IS NULL THEN :NEW.bill_number:='B-'||TO_CHAR(SYSDATE,'YYYY')||'-'||bill_number_seq.NEXTVAL; END IF;
END;
/
CREATE OR REPLACE TRIGGER trg_medicine_audit
AFTER UPDATE OF stock_qty ON medicine
FOR EACH ROW
BEGIN
  IF :NEW.stock_qty <> :OLD.stock_qty THEN
    audit_pkg.log_event('MEDICINE','UPDATE',TO_CHAR(:NEW.medicine_id),'Stock changed from '||:OLD.stock_qty||' to '||:NEW.stock_qty);
  END IF;
END;
/
