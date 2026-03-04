"""
Build Registry — Self-Healing CI/CD Pipeline
============================================
Tracks deployment health and identifies rollback-safe builds.

Thresholds:
  - Soak time:   10+ minutes
  - Requests:    10,000+ requests
  - Error rate:  < 0.01%
"""

import psycopg2
from psycopg2.extras import RealDictCursor
from contextlib import contextmanager
import os
from dotenv import load_dotenv

load_dotenv()

DEFAULT_THRESHOLDS = {
    "soak_minutes":    5,
    "min_requests":    100,
    "max_error_rate":  0.001
}

SCHEMA = """
CREATE TABLE IF NOT EXISTS build_registry (
    id           SERIAL PRIMARY KEY,
    service      VARCHAR(255)    NOT NULL,
    image        VARCHAR(255)    NOT NULL,
    running_time INTEGER         NOT NULL,   -- minutes
    requests     INTEGER         NOT NULL,
    error_rate   DECIMAL(10, 6)  NOT NULL,
    is_safe      BOOLEAN         NOT NULL DEFAULT FALSE,
    created_at   TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_service_safe 
    ON build_registry (service, is_safe, created_at DESC);
"""

def get_connection(config: dict = None):
    """
    Creates a PostgreSQL connection.
    Pass a config dict to override defaults (great for per-environment configs).
    """
    cfg = config or {
        "host":     os.getenv("DB_HOST","localhost"),
        "port":     int(os.getenv("DB_PORT","5432")),
        "database": os.getenv("DB_NAME","pipeline_db"),
        "user":     os.getenv("DB_USER","postgres"),
        "password": os.getenv("DB_PASSWORD","secret"),
    }
    return psycopg2.connect(**cfg)


@contextmanager
def db_cursor(config: dict = None):
    """
    Context manager that handles connection + commit + cleanup automatically.
    Usage:
        with db_cursor() as cur:
            cur.execute(...)
    """
    conn = get_connection(config)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            yield cur
        conn.commit()
    except Exception as e:
        conn.rollback()
        raise e
    finally:
        conn.close()


def initialize_db(config: dict = None):
    """Creates the build_registry table if it doesn't exist."""
    with db_cursor(config) as cur:
        cur.execute(SCHEMA)
    print("Build registry initialized")


def calculate_is_safe(
    running_time: int,
    requests: int,
    error_rate: float,
    thresholds: dict = None
) -> bool:
    """
    Determines if a build is rollback-safe based on your three signals:
      1. Soak time   — ran long enough
      2. Traffic     — served enough real requests  
      3. Error rate  — stayed healthy under that traffic

    You designed this logic yourself! (Decision 1)
    """
    t = thresholds or DEFAULT_THRESHOLDS

    soak_ok   = running_time >= t["soak_minutes"]
    traffic_ok = requests   >= t["min_requests"]
    errors_ok  = error_rate <  t["max_error_rate"]

    return soak_ok and traffic_ok and errors_ok


def record_deployment(
    service:      str,
    image:        str,
    running_time: int,
    requests:     int,
    error_rate:   float,
    thresholds:   dict = None,
    config:       dict = None
) -> dict:
    """
    Records a deployment in the registry.
    Automatically calculates is_safe based on the three golden signals.

    Returns the saved record.
    """
    is_safe = calculate_is_safe(running_time, requests, error_rate, thresholds)

    with db_cursor(config) as cur:
        cur.execute("""
            INSERT INTO build_registry 
                (service, image, running_time, requests, error_rate, is_safe)
            VALUES 
                (%(service)s, %(image)s, %(running_time)s, 
                 %(requests)s, %(error_rate)s, %(is_safe)s)
            RETURNING *
        """, {
            "service":      service,
            "image":        image,
            "running_time": running_time,
            "requests":     requests,
            "error_rate":   error_rate,
            "is_safe":      is_safe,
        })
        record = dict(cur.fetchone())

    status = "SAFE" if is_safe else "NOT YET SAFE"
    print(f"{status} | {service} | {image} | "
          f"{running_time}min | {requests:,} reqs | {error_rate:.4%} err")

    return record


def get_last_safe_build(service: str, exclude_image : str = None, config: dict = None) -> dict | None:
    """
    Returns the most recent rollback-safe build for a given service.
    This is called by the Rollback Engine during an incident.

    Query logic (you designed this):
      - WHERE is_safe = TRUE AND service = ?
      - ORDER BY created_at DESC   ← most recent first
      - LIMIT 1                    ← we only need one
    """
    with db_cursor(config) as cur:
        cur.execute("""
            SELECT * FROM build_registry
            WHERE  service = %(service)s
              AND  is_safe  = TRUE
              AND  image   != %(exclude_image)s
            ORDER BY created_at DESC
            LIMIT 1
        """, {"service": service, "exclude_image": exclude_image or ""})

        row = cur.fetchone()
        return dict(row) if row else None


def get_deployment_history(service: str, limit: int = 10, config: dict = None) -> list:
    """
    Returns the last N deployments for a service (safe or not).
    Useful for debugging and the Telegram alert payload.
    """
    with db_cursor(config) as cur:
        cur.execute("""
            SELECT * FROM build_registry
            WHERE  service = %(service)s
            ORDER BY created_at DESC
            LIMIT  %(limit)s
        """, {"service": service, "limit": limit})

        return [dict(row) for row in cur.fetchall()]


def update_build_metrics(
    service:      str,
    image:        str,
    running_time: int,
    requests:     int,
    error_rate:   float,
    thresholds:   dict = None,
    config:       dict = None
) -> dict | None:
    """
    Updates metrics for a running deployment.
    Called periodically by the Health Watchdog as the build accumulates soak time.
    Once thresholds are crossed, is_safe flips to TRUE automatically.
    """
    is_safe = calculate_is_safe(running_time, requests, error_rate, thresholds)

    with db_cursor(config) as cur:
        cur.execute("""
            UPDATE build_registry
            SET running_time = GREATEST(running_time, %(running_time)s),
                requests     = GREATEST(requests, %(requests)s),
                error_rate   = %(error_rate)s,
                is_safe      = CASE 
                    WHEN is_safe = TRUE THEN TRUE  
                    ELSE %(is_safe)s 
                END
            WHERE  service = %(service)s
            AND  image   = %(image)s
            RETURNING *
        """, {
            "running_time": running_time,
            "requests":     requests,
            "error_rate":   error_rate,
            "is_safe":      is_safe,
            "service":      service,
            "image":        image,
        })
        row = cur.fetchone()
        return dict(row) if row else None