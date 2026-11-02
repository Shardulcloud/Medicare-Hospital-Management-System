import os
import socket
import threading
import webbrowser
from datetime import date, datetime
from flask import Flask, jsonify, render_template, request, session, redirect, url_for
import oracledb
from config import SECRET_KEY, APP_HOST, APP_PORT, DB_USER, DB_DSN
import db

app = Flask(__name__)
app.secret_key = SECRET_KEY

MODULES = [
    ("dashboard", "Dashboard"), ("patients", "Patients"), ("doctors", "Doctors"),
    ("appointments", "Appointments"), ("admissions", "Admissions & Beds"),
    ("pharmacy", "Pharmacy"), ("laboratory", "Laboratory"),
    ("billing", "Billing"), ("reports", "Reports"), ("about", "PL/SQL Map")
]

def db_error_message(exc):
    raw = str(exc)
    if "ORA-01017" in raw:
        return "Oracle login rejected. Check DB_USER and DB_PASSWORD in config.py."
    if "ORA-12541" in raw:
        return "Oracle listener is not responding. Start the Oracle listener/service."
    if "ORA-12514" in raw:
        return "Oracle does not know this service. Check DB_DSN (default localhost:1521/XEPDB1)."
    if "DPY-6005" in raw or "DPY-4001" in raw:
        return "Could not connect to Oracle. Check listener, service name, username/password, and Oracle service."
    return "Oracle database is unavailable. Check that Oracle is running and config.py has the correct connection details."

def logged_in():
    return bool(session.get("user"))

@app.context_processor
def inject_globals():
    return {"current_user": session.get("user"), "current_role": session.get("role", "DEMO"), "modules": MODULES}

@app.route("/")
def index():
    # College demo mode: open the dashboard directly without a login screen.
    # This is intended for a local student project, not a public production deployment.
    if not logged_in():
        session.update(user="Demo Admin", role="ADMIN")
    return render_template("index.html")

@app.route("/login", methods=["POST"])
def login():
    username = request.form.get("username", "").strip()
    password = request.form.get("password", "")
    # The demo login is local-only so the UI can be explored before Oracle is configured.
    # Once the Oracle security package exists, authentication is delegated to it.
    try:
        with db.connection() as conn:
            cur = conn.cursor()
            try:
                out = cur.var(oracledb.NUMBER)
                role = cur.var(str, size=30)
                cur.callproc("SECURITY_PKG.LOGIN_USER", [username, password, out, role])
                conn.commit()
                if out.getvalue() == 1:
                    session.update(user=username, role=role.getvalue() or "RECEPTIONIST")
                    return redirect(url_for("index"))
                return render_template("login.html", db_message="Login failed. Check credentials or account lock status."), 401
            finally:
                cur.close()
    except Exception as exc:
        print("Oracle connection/login issue:", db_error_message(exc))
        return render_template("login.html", db_message=db_error_message(exc)), 503

@app.route("/logout")
def logout():
    session.clear()
    return redirect(url_for("index"))

def api_guard():
    if not logged_in():
        return jsonify(success=False, data=None, message="Please sign in again."), 401
    return None

@app.route("/api/health")
def health():
    try:
        db.fetch_one("SELECT 1 AS ok FROM dual")
        return jsonify(success=True, data={"oracle": "connected"}, message="Oracle connection is healthy.")
    except Exception as exc:
        return jsonify(success=False, data=None, message=db_error_message(exc)), 503

@app.route("/api/dashboard")
def dashboard_data():
    guard = api_guard()
    if guard:
        return guard
    try:
        # Views are installed by the SQL scripts. A fallback keeps the dashboard useful
        # in partially installed student environments.
        data = {
            "patients": db.fetch_one("SELECT COUNT(*) AS n FROM patient")["n"],
            "doctors": db.fetch_one("SELECT COUNT(*) AS n FROM doctor WHERE active_flag='Y'")["n"],
            "appointments": db.fetch_one("SELECT COUNT(*) AS n FROM appointment WHERE TRUNC(appointment_date)=TRUNC(SYSDATE)")["n"],
            "admitted": db.fetch_one("SELECT COUNT(*) AS n FROM admission WHERE discharge_date IS NULL")["n"],
            "free_beds": db.fetch_one("SELECT COUNT(*) AS n FROM bed WHERE status='FREE'")["n"],
            "outstanding": db.fetch_one("SELECT NVL(SUM(total_amount-paid_amount),0) AS n FROM bill WHERE status <> 'PAID'")["n"],
        }
        recent = db.fetch_all("SELECT patient_code, full_name, phone FROM patient WHERE ROWNUM <= 6 ORDER BY patient_id DESC")
        return jsonify(success=True, data={"stats": data, "recent_patients": recent}, message="Dashboard loaded.")
    except Exception as exc:
        return jsonify(success=False, data=None, message=db_error_message(exc)), 503

@app.route("/api/<module>")
def list_module(module):
    guard = api_guard()
    if guard:
        return guard
    queries = {
        "patients": "SELECT patient_id AS id, patient_code AS code, full_name AS name, phone, blood_group, active_flag AS status FROM patient ORDER BY patient_id DESC",
        "doctors": "SELECT d.doctor_id AS id, d.full_name AS name, d.specialization, d.consultation_fee AS fee, d.active_flag AS status, dep.department_name AS department FROM doctor d LEFT JOIN department dep ON dep.department_id=d.department_id ORDER BY d.doctor_id",
        "appointments": "SELECT a.appointment_id AS id, p.full_name AS patient, d.full_name AS doctor, a.appointment_date, a.status FROM appointment a JOIN patient p ON p.patient_id=a.patient_id JOIN doctor d ON d.doctor_id=a.doctor_id ORDER BY a.appointment_date DESC",
        "admissions": "SELECT a.admission_id AS id, p.full_name AS patient, b.bed_code, w.ward_name, a.admit_date, a.discharge_date FROM admission a JOIN patient p ON p.patient_id=a.patient_id JOIN bed b ON b.bed_id=a.bed_id JOIN ward w ON w.ward_id=b.ward_id ORDER BY a.admit_date DESC",
        "pharmacy": "SELECT medicine_id AS id, medicine_name AS name, category, unit_price AS price, stock_qty AS stock, reorder_level, expiry_date FROM medicine ORDER BY medicine_name",
        "laboratory": "SELECT lab_order_id AS id, patient_id, test_name, order_date, status, result_value, abnormal_flag FROM lab_order ORDER BY lab_order_id DESC",
        "billing": "SELECT bill_id AS id, bill_number, patient_id, bill_date, total_amount, paid_amount, status FROM bill ORDER BY bill_id DESC",
    }
    if module not in queries:
        return jsonify(success=False, data=None, message="Unknown module."), 404
    try:
        rows = db.fetch_all(queries[module])
        return jsonify(success=True, data=rows, message=f"{module.title()} loaded.")
    except Exception as exc:
        return jsonify(success=False, data=None, message=db_error_message(exc)), 503

@app.route("/api/patients", methods=["POST"])
def create_patient():
    guard = api_guard()
    if guard:
        return guard
    payload = request.get_json(silent=True) or {}
    try:
        with db.connection() as conn:
            cur = conn.cursor()
            try:
                dob_value = datetime.strptime(payload["dob"], "%Y-%m-%d") if payload.get("dob") else None
                cur.callproc("PATIENT_PKG.REGISTER_PATIENT", [
                    payload.get("full_name", ""), payload.get("phone", ""),
                    dob_value, payload.get("gender", "Other"),
                    payload.get("blood_group") or None, payload.get("allergies") or None,
                    payload.get("emergency_contact") or None
                ])
                conn.commit()
            finally:
                cur.close()
        return jsonify(success=True, data=None, message="Patient registered successfully."), 201
    except Exception as exc:
        msg = str(exc)
        if "ORA-20" in msg:
            msg = msg.split("ORA-06512")[0].replace("ORA-20001:", "").strip()
        return jsonify(success=False, data=None, message=msg or db_error_message(exc)), 400

@app.route("/api/appointments", methods=["POST"])
def create_appointment():
    guard = api_guard()
    if guard:
        return guard
    payload = request.get_json(silent=True) or {}
    try:
        with db.connection() as conn:
            cur = conn.cursor()
            try:
                cur.callproc("APPT_PKG.BOOK_APPOINTMENT", [
                    int(payload["patient_id"]), int(payload["doctor_id"]),
                    payload["appointment_date"], payload.get("reason", "Consultation")
                ])
                conn.commit()
            finally:
                cur.close()
        return jsonify(success=True, data=None, message="Appointment booked."), 201
    except Exception as exc:
        return jsonify(success=False, data=None, message=str(exc).split("ORA-06512")[0]), 400

@app.route("/api/reports")
def reports():
    guard = api_guard()
    if guard:
        return guard
    try:
        data = {
            "daily_revenue": db.fetch_all("SELECT TRUNC(payment_date) AS day, SUM(amount) AS revenue FROM payment WHERE payment_date >= TRUNC(SYSDATE)-6 GROUP BY TRUNC(payment_date) ORDER BY day"),
            "low_stock": db.fetch_all("SELECT medicine_name, stock_qty, reorder_level FROM medicine WHERE stock_qty <= reorder_level ORDER BY stock_qty"),
        }
        return jsonify(success=True, data=data, message="Reports loaded.")
    except Exception as exc:
        return jsonify(success=False, data=None, message=db_error_message(exc)), 503

if __name__ == "__main__":
    # Start the interface directly. Database setup is intentionally not run automatically:
    # launching the app must never drop/recreate the user's existing schema.
    # Select a free port in 5000-5010, then open browser once.
    chosen_port = APP_PORT
    for candidate in range(APP_PORT, APP_PORT + 11):
        with socket.socket() as sock:
            try:
                sock.bind((APP_HOST, candidate))
                chosen_port = candidate
                break
            except OSError:
                continue
    url = f"http://localhost:{chosen_port}"
    print("\nMediCare Hospital Management System")
    print(f"Opening {url} in your default browser...")
    print("If Oracle is not configured yet, read README.md and run the SQL setup as SYSTEM.")
    threading.Timer(1.5, lambda: webbrowser.open(url)).start()
    app.run(host=APP_HOST, port=chosen_port, debug=False, use_reloader=False)
