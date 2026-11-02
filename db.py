import oracledb
from config import DB_USER, DB_PASSWORD, DB_DSN

_pool = None

def get_pool():
    global _pool
    if _pool is None:
        _pool = oracledb.create_pool(
            user=DB_USER, password=DB_PASSWORD, dsn=DB_DSN,
            min=1, max=4, increment=1, timeout=30
        )
    return _pool

def connection():
    return get_pool().acquire()

def callproc(name, params=None):
    with connection() as conn:
        cur = conn.cursor()
        try:
            cur.callproc(name, params or [])
            conn.commit()
            return True
        finally:
            cur.close()

def callfunc(name, return_type, params=None):
    with connection() as conn:
        cur = conn.cursor()
        try:
            result = cur.callfunc(name, return_type, params or [])
            conn.commit()
            return result
        finally:
            cur.close()

def fetch_all(sql, params=None):
    # Only fixed, developer-authored SELECT statements are passed here.
    with connection() as conn:
        cur = conn.cursor()
        try:
            cur.execute(sql, params or {})
            cols = [d[0].lower() for d in cur.description] if cur.description else []
            return [dict(zip(cols, row)) for row in cur.fetchall()]
        finally:
            cur.close()

def fetch_one(sql, params=None):
    rows = fetch_all(sql, params)
    return rows[0] if rows else None
