DECLARE
  v_salt VARCHAR2(32);
BEGIN
  INSERT INTO department(department_name,description) VALUES('General Medicine','Primary care and general consultation');
  INSERT INTO department(department_name,description) VALUES('Cardiology','Heart and cardiovascular care');
  INSERT INTO department(department_name,description) VALUES('Orthopaedics','Bone and joint care');
  INSERT INTO department(department_name,description) VALUES('Paediatrics','Child health services');
  INSERT INTO department(department_name,description) VALUES('Dermatology','Skin and hair care');
  INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    SELECT department_id,'Dr. Asha Mehta','General Physician','MBBS, MD',500 FROM department WHERE department_name='General Medicine';
  INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    SELECT department_id,'Dr. Karan Singh','Cardiologist','MBBS, DM',900 FROM department WHERE department_name='Cardiology';
  INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    SELECT department_id,'Dr. Neha Kapoor','Orthopaedic Surgeon','MBBS, MS',750 FROM department WHERE department_name='Orthopaedics';
  INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    SELECT department_id,'Dr. Rohan Bedi','Paediatrician','MBBS, MD',600 FROM department WHERE department_name='Paediatrics';
  INSERT INTO doctor(department_id,full_name,specialization,qualification,consultation_fee)
    SELECT department_id,'Dr. Simran Gill','Dermatologist','MBBS, MD',650 FROM department WHERE department_name='Dermatology';
  INSERT INTO patient(patient_code,full_name,phone,dob,gender,blood_group,allergies)
    VALUES('P-'||TO_CHAR(SYSDATE,'YYYY')||'-1001','Aarav Sharma','9876543210',ADD_MONTHS(TRUNC(SYSDATE),-360),'Male','B+','None known');
  INSERT INTO patient(patient_code,full_name,phone,dob,gender,blood_group,allergies)
    VALUES('P-'||TO_CHAR(SYSDATE,'YYYY')||'-1002','Meera Kaur','9876543211',ADD_MONTHS(TRUNC(SYSDATE),-780),'Female','O+','Penicillin');
  INSERT INTO patient(patient_code,full_name,phone,dob,gender,blood_group,allergies)
    VALUES('P-'||TO_CHAR(SYSDATE,'YYYY')||'-1003','Kabir Verma','9876543212',ADD_MONTHS(TRUNC(SYSDATE),-240),'Male','A+','None known');
  INSERT INTO patient(patient_code,full_name,phone,dob,gender,blood_group,allergies)
    VALUES('P-'||TO_CHAR(SYSDATE,'YYYY')||'-1004','Isha Malhotra','9876543213',ADD_MONTHS(TRUNC(SYSDATE),-540),'Female','AB+','Dust');
  INSERT INTO ward(ward_name,daily_charge) VALUES('General Ward',1200);
  INSERT INTO ward(ward_name,daily_charge) VALUES('ICU',5000);
  INSERT INTO ward(ward_name,daily_charge) VALUES('Private Room',3000);
  FOR i IN 1..8 LOOP
    INSERT INTO bed(ward_id,bed_code,status)
    SELECT ward_id,'GW-'||LPAD(i,2,'0'),CASE WHEN i<=2 THEN 'OCCUPIED' ELSE 'FREE' END
    FROM ward WHERE ward_name='General Ward';
  END LOOP;
  FOR i IN 1..6 LOOP INSERT INTO bed(ward_id,bed_code,status) SELECT ward_id,'ICU-'||LPAD(i,2,'0'),'FREE' FROM ward WHERE ward_name='ICU'; END LOOP;
  FOR i IN 1..6 LOOP INSERT INTO bed(ward_id,bed_code,status) SELECT ward_id,'PR-'||LPAD(i,2,'0'),'FREE' FROM ward WHERE ward_name='Private Room'; END LOOP;
  INSERT INTO admission(patient_id,bed_id,admit_date,status)
    SELECT p.patient_id,b.bed_id,SYSDATE-2,'ADMITTED' FROM patient p CROSS JOIN bed b
    WHERE p.full_name='Aarav Sharma' AND b.bed_code='GW-01';
  INSERT INTO admission(patient_id,bed_id,admit_date,status)
    SELECT p.patient_id,b.bed_id,SYSDATE-1,'ADMITTED' FROM patient p CROSS JOIN bed b
    WHERE p.full_name='Meera Kaur' AND b.bed_code='GW-02';
  INSERT INTO medicine(medicine_name,category,unit_price,stock_qty,reorder_level,expiry_date) VALUES('Paracetamol 500mg','Analgesic',2.5,180,25,ADD_MONTHS(SYSDATE,18));
  INSERT INTO medicine(medicine_name,category,unit_price,stock_qty,reorder_level,expiry_date) VALUES('Amoxicillin 250mg','Antibiotic',6,8,20,ADD_MONTHS(SYSDATE,12));
  INSERT INTO medicine(medicine_name,category,unit_price,stock_qty,reorder_level,expiry_date) VALUES('Cetirizine 10mg','Antihistamine',3,90,15,ADD_MONTHS(SYSDATE,8));
  INSERT INTO medicine(medicine_name,category,unit_price,stock_qty,reorder_level,expiry_date) VALUES('ORS Sachet','Rehydration',18,5,12,ADD_MONTHS(SYSDATE,2));
  INSERT INTO medicine(medicine_name,category,unit_price,stock_qty,reorder_level,expiry_date) VALUES('Expired Demo Medicine','Demo',10,4,10,TRUNC(SYSDATE)-2);
  INSERT INTO lab_order(patient_id,test_name,order_date,status,result_value,normal_range,abnormal_flag,price)
    SELECT patient_id,'Complete Blood Count',SYSDATE-1,'RESULT_READY','Normal','See reference range','N',350 FROM patient WHERE full_name='Aarav Sharma';
  INSERT INTO lab_order(patient_id,test_name,price) SELECT patient_id,'Blood Glucose',250 FROM patient WHERE full_name='Meera Kaur';
  INSERT INTO bill(bill_number,patient_id,subtotal,discount_amount,tax_amount,total_amount,paid_amount,status)
    SELECT 'B-'||TO_CHAR(SYSDATE,'YYYY')||'-SAMPLE1',patient_id,1000,0,50,1050,500,'PARTIAL' FROM patient WHERE full_name='Aarav Sharma';
  INSERT INTO payment(bill_id,amount,payment_method,reference_note)
    SELECT bill_id,500,'UPI','Sample part payment' FROM bill WHERE bill_number='B-'||TO_CHAR(SYSDATE,'YYYY')||'-SAMPLE1';
  INSERT INTO appointment(patient_id,doctor_id,appointment_date,reason,status)
    SELECT p.patient_id,d.doctor_id,CAST(TRUNC(SYSDATE)+1+10/24 AS TIMESTAMP),'General check-up','BOOKED'
    FROM patient p CROSS JOIN doctor d WHERE p.full_name='Kabir Verma' AND d.full_name='Dr. Asha Mehta';
  INSERT INTO appointment(patient_id,doctor_id,appointment_date,reason,status)
    SELECT p.patient_id,d.doctor_id,CAST(TRUNC(SYSDATE)+2+11/24 AS TIMESTAMP),'Follow-up','BOOKED'
    FROM patient p CROSS JOIN doctor d WHERE p.full_name='Isha Malhotra' AND d.full_name='Dr. Karan Singh';
  v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
  INSERT INTO app_user(username,password_hash,password_salt,role_name)
    VALUES('admin',LOWER(RAWTOHEX(STANDARD_HASH('admin123'||v_salt,'SHA256'))),v_salt,'ADMIN');
  v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
  INSERT INTO app_user(username,password_hash,password_salt,role_name)
    VALUES('doctor',LOWER(RAWTOHEX(STANDARD_HASH('doctor123'||v_salt,'SHA256'))),v_salt,'DOCTOR');
  v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
  INSERT INTO app_user(username,password_hash,password_salt,role_name)
    VALUES('reception',LOWER(RAWTOHEX(STANDARD_HASH('reception123'||v_salt,'SHA256'))),v_salt,'RECEPTIONIST');
  v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
  INSERT INTO app_user(username,password_hash,password_salt,role_name)
    VALUES('pharmacy',LOWER(RAWTOHEX(STANDARD_HASH('pharmacy123'||v_salt,'SHA256'))),v_salt,'PHARMACIST');
  v_salt:=LOWER(RAWTOHEX(SYS_GUID()));
  INSERT INTO app_user(username,password_hash,password_salt,role_name)
    VALUES('labtech',LOWER(RAWTOHEX(STANDARD_HASH('labtech123'||v_salt,'SHA256'))),v_salt,'LAB_TECH');
END;
/
COMMIT;
