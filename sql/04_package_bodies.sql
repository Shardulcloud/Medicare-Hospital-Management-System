CREATE OR REPLACE PACKAGE BODY audit_pkg AS
  PROCEDURE log_event(p_table VARCHAR2, p_action VARCHAR2, p_key VARCHAR2, p_details VARCHAR2) IS
    PRAGMA AUTONOMOUS_TRANSACTION;
  BEGIN
    INSERT INTO audit_log(db_user, app_user, table_name, action_name, record_key, details)
    VALUES (SYS_CONTEXT('USERENV','SESSION_USER'), SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER'),
            SUBSTR(p_table,1,50), SUBSTR(p_action,1,10), SUBSTR(p_key,1,100), SUBSTR(p_details,1,1000));
    COMMIT;
  EXCEPTION WHEN OTHERS THEN ROLLBACK;
  END log_event;
END audit_pkg;
/
CREATE OR REPLACE PACKAGE BODY security_pkg AS
  PROCEDURE login_user(p_username VARCHAR2, p_password VARCHAR2, p_ok OUT NUMBER, p_role OUT VARCHAR2) IS
    v_hash VARCHAR2(64); v_salt VARCHAR2(32); v_fail NUMBER; v_locked CHAR(1);
  BEGIN
    p_ok := 0; p_role := NULL;
    SELECT password_hash, password_salt, failed_attempts, locked_flag, role_name
      INTO v_hash, v_salt, v_fail, v_locked, p_role
      FROM app_user WHERE username=LOWER(p_username) AND active_flag='Y' FOR UPDATE;
    IF v_locked='Y' THEN p_ok:=0; RETURN; END IF;
    IF v_hash=LOWER(RAWTOHEX(STANDARD_HASH(p_password||v_salt,'SHA256'))) THEN
      UPDATE app_user SET failed_attempts=0 WHERE username=LOWER(p_username);
      p_ok:=1;
    ELSE
      v_fail:=v_fail+1;
      UPDATE app_user SET failed_attempts=v_fail, locked_flag=CASE WHEN v_fail>=5 THEN 'Y' ELSE 'N' END
       WHERE username=LOWER(p_username);
      p_role:=NULL;
    END IF;
  EXCEPTION WHEN NO_DATA_FOUND THEN p_ok:=0; p_role:=NULL;
  END login_user;
  PROCEDURE change_password(p_username VARCHAR2, p_old_password VARCHAR2, p_new_password VARCHAR2) IS
    v_hash VARCHAR2(64); v_salt VARCHAR2(32);
  BEGIN
    SELECT password_hash,password_salt INTO v_hash,v_salt FROM app_user WHERE username=LOWER(p_username) FOR UPDATE;
    IF v_hash <> LOWER(RAWTOHEX(STANDARD_HASH(p_old_password||v_salt,'SHA256'))) THEN
      RAISE_APPLICATION_ERROR(-20001,'Current password is incorrect.');
    END IF;
    IF LENGTH(p_new_password)<8 THEN RAISE_APPLICATION_ERROR(-20002,'New password must contain at least 8 characters.'); END IF;
    v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
    UPDATE app_user SET password_salt=v_salt,password_hash=LOWER(RAWTOHEX(STANDARD_HASH(p_new_password||v_salt,'SHA256'))),failed_attempts=0,locked_flag='N'
      WHERE username=LOWER(p_username);
  END change_password;
  PROCEDURE unlock_user(p_username VARCHAR2) IS
  BEGIN UPDATE app_user SET failed_attempts=0,locked_flag='N' WHERE username=LOWER(p_username);
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20003,'User not found.'); END IF;
  END unlock_user;
END security_pkg;
/
CREATE OR REPLACE PACKAGE BODY patient_pkg AS
  PROCEDURE register_patient(p_name VARCHAR2, p_phone VARCHAR2, p_dob DATE, p_gender VARCHAR2,
    p_blood_group VARCHAR2, p_allergies VARCHAR2, p_emergency_contact VARCHAR2) IS
    v_code VARCHAR2(20);
  BEGIN
    IF TRIM(p_name) IS NULL THEN RAISE_APPLICATION_ERROR(-20010,'Patient name is required.'); END IF;
    IF NOT REGEXP_LIKE(p_phone,'^[0-9]{10}$') THEN RAISE_APPLICATION_ERROR(-20011,'Phone must contain exactly 10 digits.'); END IF;
    IF p_dob IS NOT NULL AND p_dob>TRUNC(SYSDATE) THEN RAISE_APPLICATION_ERROR(-20012,'Date of birth cannot be in the future.'); END IF;
    v_code:='P-'||TO_CHAR(SYSDATE,'YYYY')||'-'||LPAD(patient_code_seq.NEXTVAL,4,'0');
    INSERT INTO patient(patient_code,full_name,phone,dob,gender,blood_group,allergies,emergency_contact)
    VALUES(v_code,TRIM(p_name),p_phone,p_dob,NVL(p_gender,'Other'),p_blood_group,p_allergies,p_emergency_contact);
    audit_pkg.log_event('PATIENT','INSERT',v_code,'Patient registered');
  END register_patient;
  PROCEDURE deactivate_patient(p_patient_id NUMBER) IS
  BEGIN UPDATE patient SET active_flag='N' WHERE patient_id=p_patient_id;
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20013,'Patient not found.'); END IF;
  END deactivate_patient;
  FUNCTION patient_count RETURN NUMBER IS v_count NUMBER;
  BEGIN SELECT COUNT(*) INTO v_count FROM patient WHERE active_flag='Y'; RETURN v_count; END;
  PROCEDURE search_patients(p_term VARCHAR2,p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT patient_id,patient_code,full_name,phone,blood_group,active_flag
    FROM patient WHERE UPPER(full_name) LIKE '%'||UPPER(p_term)||'%' OR phone LIKE '%'||p_term||'%' OR patient_code LIKE '%'||p_term||'%'
    ORDER BY full_name; END;
END patient_pkg;
/
CREATE OR REPLACE PACKAGE BODY doctor_pkg AS
  PROCEDURE add_doctor(p_department_id NUMBER,p_name VARCHAR2,p_specialization VARCHAR2,p_qualification VARCHAR2,p_fee NUMBER) IS
  BEGIN
    INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    VALUES(p_department_id,p_name,p_specialization,p_qualification,p_fee);
  END;
  PROCEDURE deactivate_doctor(p_doctor_id NUMBER) IS
  BEGIN UPDATE doctor SET active_flag='N' WHERE doctor_id=p_doctor_id;
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20020,'Doctor not found.'); END IF;
  END;
  PROCEDURE list_doctors(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT d.doctor_id,d.full_name,d.specialization,d.consultation_fee,dep.department_name
    FROM doctor d LEFT JOIN department dep ON dep.department_id=d.department_id WHERE d.active_flag='Y' ORDER BY d.full_name; END;
END doctor_pkg;
/
CREATE OR REPLACE PACKAGE BODY appt_pkg AS
  PROCEDURE book_appointment(p_patient_id NUMBER,p_doctor_id NUMBER,p_date_text VARCHAR2,p_reason VARCHAR2) IS
    v_date TIMESTAMP; v_count NUMBER; v_patient CHAR(1); v_doctor CHAR(1);
  BEGIN
    v_date:=TO_TIMESTAMP(p_date_text,'YYYY-MM-DD"T"HH24:MI');
    IF v_date<SYSTIMESTAMP THEN RAISE_APPLICATION_ERROR(-20030,'Appointment cannot be in the past.'); END IF;
    SELECT active_flag INTO v_patient FROM patient WHERE patient_id=p_patient_id;
    SELECT active_flag INTO v_doctor FROM doctor WHERE doctor_id=p_doctor_id;
    IF v_patient<>'Y' OR v_doctor<>'Y' THEN RAISE_APPLICATION_ERROR(-20031,'Patient and doctor must be active.'); END IF;
    SELECT COUNT(*) INTO v_count FROM appointment WHERE doctor_id=p_doctor_id AND appointment_date=v_date AND status IN ('BOOKED','CHECKED_IN');
    IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20032,'Doctor already has an appointment at this time.'); END IF;
    SELECT COUNT(*) INTO v_count FROM appointment WHERE patient_id=p_patient_id AND appointment_date=v_date AND status IN ('BOOKED','CHECKED_IN');
    IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20033,'Patient already has an appointment at this time.'); END IF;
    INSERT INTO appointment(patient_id,doctor_id,appointment_date,reason) VALUES(p_patient_id,p_doctor_id,v_date,p_reason);
  EXCEPTION WHEN VALUE_ERROR THEN RAISE_APPLICATION_ERROR(-20034,'Use date/time format YYYY-MM-DDTHH:MM.');
  END book_appointment;
  PROCEDURE cancel_appointment(p_appointment_id NUMBER) IS
  BEGIN UPDATE appointment SET status='CANCELLED' WHERE appointment_id=p_appointment_id AND status='BOOKED';
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20035,'Only booked appointments can be cancelled.'); END IF;
  END;
  PROCEDURE mark_no_shows IS
  BEGIN UPDATE appointment SET status='NO_SHOW' WHERE status='BOOKED' AND appointment_date<SYSTIMESTAMP; END;
  PROCEDURE list_today(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT a.appointment_id,p.full_name patient,d.full_name doctor,a.appointment_date,a.status
    FROM appointment a JOIN patient p ON p.patient_id=a.patient_id JOIN doctor d ON d.doctor_id=a.doctor_id
    WHERE TRUNC(CAST(a.appointment_date AS DATE))=TRUNC(SYSDATE) ORDER BY a.appointment_date; END;
END appt_pkg;
/
CREATE OR REPLACE PACKAGE BODY admission_pkg AS
  PROCEDURE admit_patient(p_patient_id NUMBER,p_bed_id NUMBER) IS v_status VARCHAR2(15); v_count NUMBER;
  BEGIN
    SELECT status INTO v_status FROM bed WHERE bed_id=p_bed_id FOR UPDATE;
    IF v_status<>'FREE' THEN RAISE_APPLICATION_ERROR(-20040,'Selected bed is not free.'); END IF;
    SELECT COUNT(*) INTO v_count FROM admission WHERE patient_id=p_patient_id AND status='ADMITTED';
    IF v_count>0 THEN RAISE_APPLICATION_ERROR(-20041,'Patient is already admitted.'); END IF;
    INSERT INTO admission(patient_id,bed_id) VALUES(p_patient_id,p_bed_id);
    UPDATE bed SET status='OCCUPIED' WHERE bed_id=p_bed_id;
  END;
  PROCEDURE discharge_patient(p_admission_id NUMBER) IS v_bed NUMBER;
  BEGIN
    SELECT bed_id INTO v_bed FROM admission WHERE admission_id=p_admission_id AND status='ADMITTED' FOR UPDATE;
    UPDATE admission SET discharge_date=SYSDATE,status='DISCHARGED' WHERE admission_id=p_admission_id;
    UPDATE bed SET status='FREE' WHERE bed_id=v_bed;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20042,'Active admission not found.');
  END;
END admission_pkg;
/
CREATE OR REPLACE PACKAGE BODY pharmacy_pkg AS
  PROCEDURE add_stock(p_medicine_id NUMBER,p_quantity NUMBER) IS
  BEGIN IF p_quantity<=0 THEN RAISE_APPLICATION_ERROR(-20050,'Quantity must be positive.'); END IF;
    UPDATE medicine SET stock_qty=stock_qty+p_quantity WHERE medicine_id=p_medicine_id;
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20051,'Medicine not found.'); END IF;
  END;
  PROCEDURE dispense(p_medicine_id NUMBER,p_quantity NUMBER) IS v_stock NUMBER; v_expiry DATE;
  BEGIN
    SELECT stock_qty,expiry_date INTO v_stock,v_expiry FROM medicine WHERE medicine_id=p_medicine_id FOR UPDATE;
    IF v_expiry IS NOT NULL AND v_expiry<TRUNC(SYSDATE) THEN RAISE_APPLICATION_ERROR(-20052,'Expired medicine cannot be dispensed.'); END IF;
    IF p_quantity<=0 OR v_stock<p_quantity THEN RAISE_APPLICATION_ERROR(-20053,'Quantity is invalid or stock is insufficient.'); END IF;
    UPDATE medicine SET stock_qty=stock_qty-p_quantity WHERE medicine_id=p_medicine_id;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20054,'Medicine not found.');
  END;
  PROCEDURE low_stock_report(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT medicine_id,medicine_name,stock_qty,reorder_level FROM medicine WHERE stock_qty<=reorder_level ORDER BY stock_qty; END;
END pharmacy_pkg;
/
CREATE OR REPLACE PACKAGE BODY lab_pkg AS
  PROCEDURE order_test(p_patient_id NUMBER,p_test_name VARCHAR2,p_price NUMBER) IS
  BEGIN INSERT INTO lab_order(patient_id,test_name,price) VALUES(p_patient_id,p_test_name,p_price); END;
  PROCEDURE enter_result(p_order_id NUMBER,p_result VARCHAR2,p_abnormal CHAR) IS
  BEGIN UPDATE lab_order SET result_value=p_result,abnormal_flag=CASE WHEN p_abnormal='Y' THEN 'Y' ELSE 'N' END,status='RESULT_READY'
    WHERE lab_order_id=p_order_id;
    IF SQL%ROWCOUNT=0 THEN RAISE_APPLICATION_ERROR(-20060,'Lab order not found.'); END IF;
  END;
  PROCEDURE pending_report(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT lab_order_id,patient_id,test_name,order_date,status FROM lab_order WHERE status<>'RESULT_READY' ORDER BY order_date; END;
END lab_pkg;
/
CREATE OR REPLACE PACKAGE BODY billing_pkg AS
  FUNCTION calculate_total(p_subtotal NUMBER,p_discount NUMBER,p_tax_rate NUMBER) RETURN NUMBER IS
  BEGIN RETURN ROUND((p_subtotal-NVL(p_discount,0))*(1+NVL(p_tax_rate,0)/100),2); END;
  PROCEDURE create_bill(p_patient_id NUMBER,p_subtotal NUMBER,p_bill_id OUT NUMBER) IS
    v_age NUMBER; v_discount NUMBER:=0; v_tax NUMBER; v_total NUMBER;
  BEGIN
    SELECT FLOOR(MONTHS_BETWEEN(SYSDATE,dob)/12) INTO v_age FROM patient WHERE patient_id=p_patient_id;
    IF v_age>60 THEN v_discount:=ROUND(p_subtotal*0.10,2); END IF;
    v_tax:=ROUND((p_subtotal-v_discount)*0.05,2);
    INSERT INTO bill(bill_number,patient_id,subtotal,discount_amount,tax_amount,total_amount)
    VALUES('B-'||TO_CHAR(SYSDATE,'YYYY')||'-'||bill_number_seq.NEXTVAL,p_patient_id,p_subtotal,v_discount,v_tax,p_subtotal-v_discount+v_tax)
    RETURNING bill_id INTO p_bill_id;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20070,'Patient not found.');
  END;
  PROCEDURE record_payment(p_bill_id NUMBER,p_amount NUMBER,p_method VARCHAR2) IS v_total NUMBER; v_paid NUMBER;
  BEGIN
    SELECT total_amount,paid_amount INTO v_total,v_paid FROM bill WHERE bill_id=p_bill_id FOR UPDATE;
    IF p_amount<=0 OR v_paid+p_amount>v_total THEN RAISE_APPLICATION_ERROR(-20071,'Payment amount is invalid or exceeds balance.'); END IF;
    INSERT INTO payment(bill_id,amount,payment_method) VALUES(p_bill_id,p_amount,p_method);
    UPDATE bill SET paid_amount=paid_amount+p_amount,
      status=CASE WHEN paid_amount+p_amount>=total_amount THEN 'PAID' WHEN paid_amount+p_amount>0 THEN 'PARTIAL' ELSE 'UNPAID' END
      WHERE bill_id=p_bill_id;
  EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20072,'Bill not found.');
  END;
END billing_pkg;
/
CREATE OR REPLACE PACKAGE BODY report_pkg AS
  PROCEDURE low_stock_report(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT medicine_name,stock_qty,reorder_level FROM medicine WHERE stock_qty<=reorder_level ORDER BY stock_qty; END;
  PROCEDURE daily_revenue(p_rows OUT SYS_REFCURSOR) IS
  BEGIN OPEN p_rows FOR SELECT TRUNC(payment_date) day,SUM(amount) revenue FROM payment
    WHERE payment_date>=TRUNC(SYSDATE)-6 GROUP BY TRUNC(payment_date) ORDER BY day; END;
  FUNCTION admitted_count RETURN NUMBER IS v_count NUMBER;
  BEGIN SELECT COUNT(*) INTO v_count FROM admission WHERE status='ADMITTED'; RETURN v_count; END;
END report_pkg;
/
CREATE OR REPLACE PACKAGE BODY demo_pkg AS
  PROCEDURE show_collection_demo IS
    TYPE fee_record IS RECORD (doctor_name VARCHAR2(100), fee NUMBER);
    TYPE fee_table IS TABLE OF fee_record;
    v_fees fee_table;
    v_names name_map;
    CURSOR c_doctors IS SELECT full_name,consultation_fee FROM doctor ORDER BY doctor_id;
    v_row c_doctors%ROWTYPE;
    v_count NUMBER:=0;
  BEGIN
    OPEN c_doctors;
    LOOP
      FETCH c_doctors INTO v_row;
      EXIT WHEN c_doctors%NOTFOUND;
      v_count:=v_count+1;
      v_names(v_count):=v_row.full_name;
      DBMS_OUTPUT.PUT_LINE(v_row.full_name||' fee='||v_row.consultation_fee);
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Rows fetched: '||c_doctors%ROWCOUNT);
    IF c_doctors%ISOPEN THEN CLOSE c_doctors; END IF;
    SELECT full_name,consultation_fee BULK COLLECT INTO v_fees FROM doctor;
    FOR i IN 1..v_fees.COUNT LOOP
      CONTINUE WHEN v_fees(i).fee<0;
      EXIT WHEN i>100;
    END LOOP;
  END show_collection_demo;
END demo_pkg;
/
