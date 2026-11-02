CREATE OR REPLACE PACKAGE audit_pkg AS
  PROCEDURE log_event(p_table VARCHAR2, p_action VARCHAR2, p_key VARCHAR2, p_details VARCHAR2);
END audit_pkg;
/
CREATE OR REPLACE PACKAGE security_pkg AS
  PROCEDURE login_user(p_username VARCHAR2, p_password VARCHAR2, p_ok OUT NUMBER, p_role OUT VARCHAR2);
  PROCEDURE change_password(p_username VARCHAR2, p_old_password VARCHAR2, p_new_password VARCHAR2);
  PROCEDURE unlock_user(p_username VARCHAR2);
END security_pkg;
/
CREATE OR REPLACE PACKAGE patient_pkg AS
  PROCEDURE register_patient(p_name VARCHAR2, p_phone VARCHAR2, p_dob DATE, p_gender VARCHAR2,
    p_blood_group VARCHAR2, p_allergies VARCHAR2, p_emergency_contact VARCHAR2);
  PROCEDURE deactivate_patient(p_patient_id NUMBER);
  FUNCTION patient_count RETURN NUMBER;
  PROCEDURE search_patients(p_term VARCHAR2, p_rows OUT SYS_REFCURSOR);
END patient_pkg;
/
CREATE OR REPLACE PACKAGE doctor_pkg AS
  PROCEDURE add_doctor(p_department_id NUMBER, p_name VARCHAR2, p_specialization VARCHAR2,
    p_qualification VARCHAR2, p_fee NUMBER);
  PROCEDURE deactivate_doctor(p_doctor_id NUMBER);
  PROCEDURE list_doctors(p_rows OUT SYS_REFCURSOR);
END doctor_pkg;
/
CREATE OR REPLACE PACKAGE appt_pkg AS
  PROCEDURE book_appointment(p_patient_id NUMBER, p_doctor_id NUMBER, p_date_text VARCHAR2, p_reason VARCHAR2);
  PROCEDURE cancel_appointment(p_appointment_id NUMBER);
  PROCEDURE mark_no_shows;
  PROCEDURE list_today(p_rows OUT SYS_REFCURSOR);
END appt_pkg;
/
CREATE OR REPLACE PACKAGE admission_pkg AS
  PROCEDURE admit_patient(p_patient_id NUMBER, p_bed_id NUMBER);
  PROCEDURE discharge_patient(p_admission_id NUMBER);
END admission_pkg;
/
CREATE OR REPLACE PACKAGE pharmacy_pkg AS
  PROCEDURE add_stock(p_medicine_id NUMBER, p_quantity NUMBER);
  PROCEDURE dispense(p_medicine_id NUMBER, p_quantity NUMBER);
  PROCEDURE low_stock_report(p_rows OUT SYS_REFCURSOR);
END pharmacy_pkg;
/
CREATE OR REPLACE PACKAGE lab_pkg AS
  PROCEDURE order_test(p_patient_id NUMBER, p_test_name VARCHAR2, p_price NUMBER);
  PROCEDURE enter_result(p_order_id NUMBER, p_result VARCHAR2, p_abnormal CHAR);
  PROCEDURE pending_report(p_rows OUT SYS_REFCURSOR);
END lab_pkg;
/
CREATE OR REPLACE PACKAGE billing_pkg AS
  PROCEDURE create_bill(p_patient_id NUMBER, p_subtotal NUMBER, p_bill_id OUT NUMBER);
  PROCEDURE record_payment(p_bill_id NUMBER, p_amount NUMBER, p_method VARCHAR2);
  FUNCTION calculate_total(p_subtotal NUMBER, p_discount NUMBER, p_tax_rate NUMBER) RETURN NUMBER;
END billing_pkg;
/
CREATE OR REPLACE PACKAGE report_pkg AS
  PROCEDURE low_stock_report(p_rows OUT SYS_REFCURSOR);
  PROCEDURE daily_revenue(p_rows OUT SYS_REFCURSOR);
  FUNCTION admitted_count RETURN NUMBER;
END report_pkg;
/
CREATE OR REPLACE PACKAGE demo_pkg AS
  TYPE number_list IS TABLE OF NUMBER;
  TYPE name_map IS TABLE OF VARCHAR2(100) INDEX BY PLS_INTEGER;
  PROCEDURE show_collection_demo;
END demo_pkg;
/
