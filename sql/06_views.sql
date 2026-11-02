CREATE OR REPLACE VIEW v_patient_summary AS
SELECT p.patient_id,p.patient_code,p.full_name,p.phone,p.blood_group,p.active_flag,
       (SELECT COUNT(*) FROM appointment a WHERE a.patient_id=p.patient_id) appointment_count,
       (SELECT NVL(SUM(b.total_amount-b.paid_amount),0) FROM bill b WHERE b.patient_id=p.patient_id) outstanding_balance
FROM patient p;
CREATE OR REPLACE VIEW v_doctor_department AS
SELECT d.doctor_id,d.full_name,d.specialization,d.consultation_fee,dep.department_name,d.active_flag
FROM doctor d LEFT JOIN department dep ON dep.department_id=d.department_id;
CREATE OR REPLACE VIEW v_free_beds AS SELECT b.bed_id,b.bed_code,w.ward_name,w.daily_charge FROM bed b JOIN ward w ON w.ward_id=b.ward_id WHERE b.status='FREE';
