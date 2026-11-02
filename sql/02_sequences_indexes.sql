CREATE SEQUENCE patient_code_seq START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE bill_number_seq START WITH 1001 INCREMENT BY 1 NOCACHE;
CREATE INDEX ix_patient_name ON patient(UPPER(full_name));
CREATE INDEX ix_patient_phone ON patient(phone);
CREATE INDEX ix_appt_doctor_date ON appointment(doctor_id, appointment_date);
CREATE INDEX ix_appt_patient_date ON appointment(patient_id, appointment_date);
CREATE INDEX ix_bill_patient_date ON bill(patient_id, bill_date);
CREATE INDEX ix_medicine_expiry ON medicine(expiry_date);
