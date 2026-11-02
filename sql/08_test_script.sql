SET SERVEROUTPUT ON;
BEGIN
  DBMS_OUTPUT.PUT_LINE('MediCare HMS test script');
  DBMS_OUTPUT.PUT_LINE('Active patients: '||patient_pkg.patient_count);
  DBMS_OUTPUT.PUT_LINE('Admitted patients: '||report_pkg.admitted_count);
  DBMS_OUTPUT.PUT_LINE('Subtotal 1000, discount 100, tax 5% => '||billing_pkg.calculate_total(1000,100,5));
  demo_pkg.show_collection_demo;
  DBMS_OUTPUT.PUT_LINE('Low-stock report cursor can be opened using REPORT_PKG.LOW_STOCK_REPORT.');
END;
/
