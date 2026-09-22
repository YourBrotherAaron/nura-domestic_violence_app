-- ============================================================================
-- Nura / EviSafe — database schema
-- ============================================================================
-- This file runs automatically the FIRST time the Postgres container starts
-- (it is mounted into /docker-entrypoint-initdb.d/). It creates every table the
-- backend needs and seeds the evidence types.
--
-- Source: reconstructed from the original team's hand-off DDL, adjusted so the
-- column types match the backend's SQLAlchemy models exactly (a few types in the
-- hand-off drifted from the code). The database/user themselves are created by
-- the container via POSTGRES_DB / POSTGRES_USER, so this file only defines tables.
-- ============================================================================

-- Users -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS app_user (
    user_id        SERIAL PRIMARY KEY,
    first_name     VARCHAR(255) NOT NULL,
    last_name      VARCHAR(255) NOT NULL,
    email          VARCHAR(255) UNIQUE NOT NULL,
    password_hash  VARCHAR(255) NOT NULL,
    phone_number   VARCHAR(50),
    created_at     DATE DEFAULT CURRENT_DATE,
    account_status BOOLEAN DEFAULT TRUE
);

-- Cases (one per user — the app enforces this, mirrored here) -----------------
CREATE TABLE IF NOT EXISTS cases (
    case_id       SERIAL PRIMARY KEY,
    user_id       INTEGER UNIQUE REFERENCES app_user(user_id),
    case_title    VARCHAR(255) NOT NULL,
    description   TEXT,
    creation_date DATE DEFAULT CURRENT_DATE,
    status        VARCHAR(50)
);

-- Incidents -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident (
    incident_id   SERIAL PRIMARY KEY,
    case_id       INTEGER NOT NULL REFERENCES cases(case_id),
    incident_date DATE,
    incident_time TIME,
    location      VARCHAR(255),
    incident_type VARCHAR(50),
    description   TEXT,
    creation_date DATE DEFAULT CURRENT_DATE
);

-- Evidence types --------------------------------------------------------------
CREATE TABLE IF NOT EXISTS evidencetype (
    evidence_type_id SERIAL PRIMARY KEY,
    type_name        VARCHAR(255) NOT NULL,
    description      VARCHAR(255)
);

-- Evidence --------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS evidence (
    evidence_id               SERIAL PRIMARY KEY,
    incident_id               INTEGER NOT NULL REFERENCES incident(incident_id),
    user_id                   INTEGER NOT NULL REFERENCES app_user(user_id),
    evidence_type_id          INTEGER NOT NULL REFERENCES evidencetype(evidence_type_id),
    file_name                 VARCHAR(255) NOT NULL,
    evidence_location         VARCHAR(255),
    evidence_imei             VARCHAR(50),
    evidence_device           VARCHAR(100),
    evidence_activation       VARCHAR(50),
    file_path                 VARCHAR(500) NOT NULL,
    file_hash                 VARCHAR(500) NOT NULL,
    created_at                TIMESTAMP DEFAULT NOW(),
    description               TEXT,
    -- Trusted RFC 3161 timestamp fields
    timestamp_token           TEXT,
    timestamp_authority       VARCHAR(500),
    timestamp_status          VARCHAR(50),
    timestamp_hash_algorithm  VARCHAR(50),
    timestamp_message_imprint VARCHAR(128),
    timestamp_nonce           VARCHAR(64),
    timestamp_time            VARCHAR(50)
);

-- Encryption records ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS encryption (
    crypto_id         SERIAL PRIMARY KEY,
    evidence_id       INTEGER NOT NULL REFERENCES evidence(evidence_id),
    aes_key_reference VARCHAR(500) NOT NULL,
    iv_nonce          VARCHAR(255) NOT NULL,
    hmac_hash         VARCHAR(500) NOT NULL,
    hmac_verified_at  TIMESTAMP,
    integrity_status  VARCHAR(50),
    downloaded_at     TIMESTAMP,
    description       TEXT
);

-- Audit log -------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS auditlog (
    audit_log_id     SERIAL PRIMARY KEY,
    user_id          INTEGER NOT NULL REFERENCES app_user(user_id),
    case_id          INTEGER REFERENCES cases(case_id),
    incident_id      INTEGER REFERENCES incident(incident_id),
    evidence_id      INTEGER REFERENCES evidence(evidence_id),
    export_id        INTEGER,
    action_type      VARCHAR(100) NOT NULL,
    entity_type      VARCHAR(100) NOT NULL,
    entity_id        INTEGER,
    action_timestamp TIMESTAMP DEFAULT NOW(),
    old_value        VARCHAR,
    new_value        VARCHAR
);

-- Export packages (present in the schema; not yet used by the backend) --------
CREATE TABLE IF NOT EXISTS export_package (
    export_id        SERIAL PRIMARY KEY,
    case_id          INTEGER REFERENCES cases(case_id),
    user_id          INTEGER REFERENCES app_user(user_id),
    created_by       VARCHAR,
    created_at       TIMESTAMP DEFAULT NOW(),
    export_format    VARCHAR,
    destination_type VARCHAR,
    note             VARCHAR
);

-- Integrity check log (written by the integrity checker) ----------------------
CREATE TABLE IF NOT EXISTS integrity_check_log (
    id            SERIAL PRIMARY KEY,
    evidence_id   INTEGER NOT NULL,
    result        VARCHAR(20) NOT NULL,
    stored_hash   TEXT,
    computed_hash TEXT,
    message       TEXT,
    checked_at    TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed evidence types ---------------------------------------------------------
INSERT INTO evidencetype (type_name, description)
SELECT * FROM (VALUES
    ('photo',        'Photo evidence'),
    ('video',        'Video evidence'),
    ('audio',        'Audio recording'),
    ('document',     'Document or file'),
    ('written_note', 'Written note entered by user')
) AS seed(type_name, description)
WHERE NOT EXISTS (SELECT 1 FROM evidencetype);
