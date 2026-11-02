import os

# Defaults match the HOSPITAL schema you created for this project.
# To use the alternative HMS account, set HMS_DB_USER=HMS and HMS_DB_PASSWORD=hms123.
DB_USER = os.getenv("HMS_DB_USER", "HOSPITAL")
DB_PASSWORD = os.getenv("HMS_DB_PASSWORD", "anpm2005")
DB_DSN = os.getenv("HMS_DB_DSN", "localhost:1521/XEPDB1")
SECRET_KEY = os.getenv("HMS_SECRET_KEY", "change-this-for-real-deployment")
APP_HOST = os.getenv("HMS_HOST", "127.0.0.1")
APP_PORT = int(os.getenv("HMS_PORT", "5000"))
