# MediCare Hospital Management System

## Run on Windows
1. Open this extracted folder in File Explorer.
2. Click the address bar, type `cmd`, and press Enter.
3. Run `python -m pip install -r requirements.txt` once.
4. Run `python app.py`. The browser opens automatically.

Oracle must be running. `config.py` defaults to HOSPITAL / anpm2005 and localhost:1521/XEPDB1. The app does not install, drop, or reset database objects on startup. SQL setup scripts are kept in `sql/`. Do not run `sql/09_drop_all.sql` unless you deliberately want to remove the project schema objects.

If the dashboard opens but data cannot load, open `http://127.0.0.1:5000/api/health` and inspect the message in the browser.
