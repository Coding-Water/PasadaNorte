-- PasadaNorte PostgreSQL + PostGIS Schema (Aligned with Revised Case Study)
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Core Account Records (Separated from Biometric Templates per RA 10173 Data Minimization)
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    full_name VARCHAR(100) NOT NULL,
    role VARCHAR(20) NOT NULL CHECK (role IN ('rider', 'driver', 'toda_admin', 'minc_admin')),
    id_type VARCHAR(60) NOT NULL,
    informed_consent_signed BOOLEAN NOT NULL DEFAULT FALSE,
    informed_consent_timestamp TIMESTAMP WITH TIME ZONE,
    ai_similarity_percent NUMERIC(5, 2),
    verification_latency_ms INT,
    verification_status VARCHAR(30) DEFAULT 'pending'
        CHECK (verification_status IN ('pending', 'approved', 'rejected', 're_upload_requested')),
    verification_images_deleted BOOLEAN DEFAULT FALSE,
    admin_review_note TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 2. Encrypted Face Templates Vault (Stored Separately from Account Records with Access Logging)
CREATE TABLE encrypted_face_templates (
    template_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_ref_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    encrypted_embedding_cipher BYTEA NOT NULL, -- AES-256-GCM encrypted at rest
    encryption_key_id VARCHAR(64) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE TABLE biometric_access_logs (
    log_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_user_id UUID REFERENCES users(id),
    target_user_id UUID REFERENCES users(id),
    action_type VARCHAR(50) NOT NULL, -- e.g. '1_TO_1_MATCH', 'ADMIN_MANUAL_REVIEW', 'PURGE_RAW_IMAGES'
    logged_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 3. TODA Terminals & Admin-Configurable Geofences ("Digital Pila" - Objective 4)
CREATE TABLE toda_terminals (
    id VARCHAR(30) PRIMARY KEY,
    name VARCHAR(120) NOT NULL,
    toda_code VARCHAR(30) UNIQUE NOT NULL,
    center_point GEOGRAPHY(POINT, 4326) NOT NULL,
    radius_meters NUMERIC(5, 2) NOT NULL DEFAULT 15.0, -- Initial 10m to 25m range
    join_speed_limit_kmh NUMERIC(4, 2) NOT NULL DEFAULT 5.0,
    min_stop_dwell_seconds INT NOT NULL DEFAULT 30,
    departure_speed_kmh NUMERIC(4, 2) NOT NULL DEFAULT 10.0,
    auto_pass_timeout_seconds INT NOT NULL DEFAULT 15
);

-- 4. Editable Approved Fare Table (Objective 1 & 5b - PNA 2026a & LTFRB MC 2025-10)
CREATE TABLE fare_guide_table (
    id SERIAL PRIMARY KEY,
    ordinance_label VARCHAR(150) DEFAULT 'Laoag City Approved Fare Guide (2026)',
    regular_first_km_fare NUMERIC(6, 2) NOT NULL DEFAULT 20.00,
    discounted_first_km_fare NUMERIC(6, 2) NOT NULL DEFAULT 15.00,
    succeeding_km_rate NUMERIC(6, 2) NOT NULL DEFAULT 2.00,
    base_distance_km NUMERIC(4, 2) NOT NULL DEFAULT 1.00,
    statutory_discount_share_rate NUMERIC(4, 2) NOT NULL DEFAULT 0.20,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Hourly Zone Trip Counts for Demand Forecasting (Objective 3: 10 Zones x 56 Days x 12 Hours = 6,720 Records)
CREATE TABLE zone_hourly_demand (
    record_id SERIAL PRIMARY KEY,
    zone_code VARCHAR(10) NOT NULL,
    zone_name VARCHAR(120) NOT NULL,
    zone_centroid GEOGRAPHY(POINT, 4326) NOT NULL,
    observation_date DATE NOT NULL,
    hour_of_day INT NOT NULL CHECK (hour_of_day BETWEEN 0 AND 23),
    is_weekday BOOLEAN NOT NULL DEFAULT TRUE,
    actual_trip_count INT NOT NULL DEFAULT 0,
    predicted_trip_count INT,
    seasonal_baseline_count INT,
    k_anonymity_displayed BOOLEAN GENERATED ALWAYS AS (COALESCE(predicted_trip_count, actual_trip_count) >= 5) STORED
);
