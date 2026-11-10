-- ============================================================================
-- PASADANORTE: PILLAR 1 — DATABASE & SUPABASE ROW LEVEL SECURITY (RLS) HARDENING
-- Laoag City Paratransit Dispatch & Municipal Regulation Ecosystem
-- Target PostgreSQL Engine: Supabase Cloud (PostGIS Enabled)
-- Standards: ISO/IEC 25010:2023 Security & Integrity • Laoag City Ord. 2023-005
-- ============================================================================

-- Enable PostGIS extension if not already enabled
CREATE EXTENSION IF NOT EXISTS postgis;

-- ----------------------------------------------------------------------------
-- 1. BASE SCHEMA DEFINITIONS & TABLE STRUCTURES
-- ----------------------------------------------------------------------------

-- Table 1: Laoag City Official Fare Matrix (City Ordinance No. 2023-005)
CREATE TABLE IF NOT EXISTS public.fare_guide_table (
    id BIGSERIAL PRIMARY KEY,
    ordinance_label TEXT NOT NULL DEFAULT 'City Ordinance No. 2023-005',
    regular_first_km_fare NUMERIC(6, 2) NOT NULL DEFAULT 20.00,
    discounted_first_km_fare NUMERIC(6, 2) NOT NULL DEFAULT 16.00,
    succeeding_km_rate NUMERIC(6, 2) NOT NULL DEFAULT 5.00,
    base_distance_km NUMERIC(4, 2) NOT NULL DEFAULT 1.00,
    statutory_discount_share_rate NUMERIC(3, 2) NOT NULL DEFAULT 0.20,
    effective_date TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now()),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS ordinance_label TEXT DEFAULT 'City Ordinance No. 2023-005';
ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS regular_first_km_fare NUMERIC(6, 2) DEFAULT 20.00;
ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS discounted_first_km_fare NUMERIC(6, 2) DEFAULT 16.00;
ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS succeeding_km_rate NUMERIC(6, 2) DEFAULT 5.00;
ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS base_distance_km NUMERIC(4, 2) DEFAULT 1.00;
ALTER TABLE public.fare_guide_table ADD COLUMN IF NOT EXISTS statutory_discount_share_rate NUMERIC(3, 2) DEFAULT 0.20;

-- Table 2: Emergency SOS Distress Beacons & Live Incidents
CREATE TABLE IF NOT EXISTS public.emergency_sos_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_name TEXT NOT NULL,
    body_number TEXT DEFAULT '#042',
    plate_number TEXT DEFAULT '7489-IN',
    toda TEXT DEFAULT 'Laoag Central Terminal TODA',
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    location_name TEXT DEFAULT 'Laoag City Route',
    alert_reason TEXT NOT NULL DEFAULT 'DRIVER_TRIGGERED_EMERGENCY_SOS',
    status TEXT NOT NULL DEFAULT 'ACTIVE_DISPATCHED',
    contact TEXT DEFAULT '+63 917 554 9012',
    dispatched_pnp BOOLEAN DEFAULT FALSE,
    pnp_dispatch_time TIMESTAMPTZ,
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS driver_name TEXT;
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS body_number TEXT DEFAULT '#042';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS plate_number TEXT DEFAULT '7489-IN';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS toda TEXT DEFAULT 'Laoag Central Terminal TODA';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS location_name TEXT DEFAULT 'Laoag City Route';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS alert_reason TEXT DEFAULT 'DRIVER_TRIGGERED_EMERGENCY_SOS';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS status TEXT DEFAULT 'ACTIVE_DISPATCHED';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS contact TEXT DEFAULT '+63 917 554 9012';
ALTER TABLE public.emergency_sos_alerts ADD COLUMN IF NOT EXISTS dispatched_pnp BOOLEAN DEFAULT FALSE;

-- Table 3: TODA Terminal Geofences & PostGIS Calibration
CREATE TABLE IF NOT EXISTS public.toda_terminals (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    toda_code TEXT NOT NULL,
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    center_point GEOGRAPHY(POINT, 4326),
    radius_meters NUMERIC(5, 2) NOT NULL DEFAULT 25.00,
    dwell_time_seconds INT NOT NULL DEFAULT 30,
    speed_limit_kmh NUMERIC(4, 1) NOT NULL DEFAULT 5.0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Backward-compatibility: Ensure all columns exist on pre-existing toda_terminals
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS latitude DOUBLE PRECISION;
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS longitude DOUBLE PRECISION;
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS center_point GEOGRAPHY(POINT, 4326);
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS radius_meters NUMERIC(5, 2) DEFAULT 25.00;
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS dwell_time_seconds INT DEFAULT 30;
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS speed_limit_kmh NUMERIC(4, 1) DEFAULT 5.0;
ALTER TABLE public.toda_terminals ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT timezone('utc'::text, now());

-- Allow center_point to be nullable if previously defined as NOT NULL
DO $$
BEGIN
    ALTER TABLE public.toda_terminals ALTER COLUMN center_point DROP NOT NULL;
EXCEPTION
    WHEN OTHERS THEN NULL;
END $$;

-- If existing rows have center_point, populate latitude and longitude
UPDATE public.toda_terminals
SET latitude = ST_Y(center_point::geometry),
    longitude = ST_X(center_point::geometry)
WHERE latitude IS NULL AND center_point IS NOT NULL;

-- Table 4: Driver Completed Trips & Fare Settlement Records
CREATE TABLE IF NOT EXISTS public.driver_completed_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_name TEXT NOT NULL,
    passenger_name TEXT NOT NULL,
    pickup_point TEXT,
    destination TEXT NOT NULL,
    distance_km NUMERIC(5, 2) NOT NULL,
    fare NUMERIC(7, 2) NOT NULL,
    is_cash BOOLEAN NOT NULL DEFAULT TRUE,
    payment_method TEXT NOT NULL DEFAULT 'CASH',
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 4B: Completed Trips (Analytics & Commuter Receipts)
CREATE TABLE IF NOT EXISTS public.completed_trips (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    driver_name TEXT NOT NULL,
    fare_amount NUMERIC(7, 2) NOT NULL,
    distance_km NUMERIC(5, 2) NOT NULL,
    passenger_name TEXT NOT NULL,
    payment_method TEXT NOT NULL DEFAULT 'CASH',
    dropoff_location TEXT NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 4C: Live Driver Telemetry (PostGIS GPS Stream)
CREATE TABLE IF NOT EXISTS public.driver_telemetry (
    ride_id TEXT PRIMARY KEY,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    heading DOUBLE PRECISION DEFAULT 0.0,
    stage TEXT NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 5: User Identity & 1:1 Face Verification Biometrics (ISO/IEC 19795-1)
CREATE TABLE IF NOT EXISTS public.users (
    id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    phone_number TEXT NOT NULL UNIQUE,
    role TEXT NOT NULL DEFAULT 'rider',
    id_type TEXT DEFAULT 'Government ID',
    verification_status TEXT NOT NULL DEFAULT 'pending',
    ai_similarity_percent NUMERIC(5, 2) DEFAULT 80.00,
    verification_latency_ms INT DEFAULT 1400,
    admin_review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- Table 6: MINC Regulatory Audit Logs (Legally Tamper-Proof Trail)
CREATE TABLE IF NOT EXISTS public.minc_trip_audit_logs (
    id BIGSERIAL PRIMARY KEY,
    trip_id TEXT,
    actor TEXT NOT NULL,
    action TEXT NOT NULL,
    discrepancy_amount NUMERIC(6, 2) DEFAULT 0.00,
    status TEXT NOT NULL DEFAULT 'LOGGED',
    timestamp TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

-- ----------------------------------------------------------------------------
-- 2. HELPER FUNCTIONS FOR ROLE-BASED ACCESS CONTROL (RBAC)
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.is_minc_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        (auth.jwt() ->> 'role') = 'minc_admin' OR
        (auth.jwt() -> 'user_metadata' ->> 'role') = 'minc_admin' OR
        (auth.jwt() -> 'app_metadata' ->> 'role') = 'minc_admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.is_driver()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN (
        auth.role() = 'authenticated' AND (
            (auth.jwt() ->> 'role') = 'driver' OR
            (auth.jwt() -> 'user_metadata' ->> 'role') = 'driver'
        )
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ----------------------------------------------------------------------------
-- 3. ENABLE ROW LEVEL SECURITY (RLS) ACROSS ALL TABLES
-- ----------------------------------------------------------------------------

ALTER TABLE public.fare_guide_table ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.emergency_sos_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.toda_terminals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_completed_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.completed_trips ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.driver_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.minc_trip_audit_logs ENABLE ROW LEVEL SECURITY;

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY (RLS) POLICIES
-- ----------------------------------------------------------------------------

-- A. Policies for `fare_guide_table`
DROP POLICY IF EXISTS "Allow public read access to active fare matrix" ON public.fare_guide_table;
CREATE POLICY "Allow public read access to active fare matrix"
ON public.fare_guide_table FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Restrict fare updates to MINC Administrators" ON public.fare_guide_table;
CREATE POLICY "Restrict fare updates to MINC Administrators"
ON public.fare_guide_table FOR ALL
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

-- B. Policies for `emergency_sos_alerts`
DROP POLICY IF EXISTS "Allow emergency beacon broadcast" ON public.emergency_sos_alerts;
CREATE POLICY "Allow emergency beacon broadcast"
ON public.emergency_sos_alerts FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow reading emergency distress beacons" ON public.emergency_sos_alerts;
CREATE POLICY "Allow reading emergency distress beacons"
ON public.emergency_sos_alerts FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Only MINC Admin can resolve SOS beacons" ON public.emergency_sos_alerts;
CREATE POLICY "Only MINC Admin can resolve SOS beacons"
ON public.emergency_sos_alerts FOR UPDATE
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

DROP POLICY IF EXISTS "Forbid deletion of emergency SOS beacons" ON public.emergency_sos_alerts;
CREATE POLICY "Forbid deletion of emergency SOS beacons"
ON public.emergency_sos_alerts FOR DELETE
USING (false);

-- C. Policies for `toda_terminals`
DROP POLICY IF EXISTS "Allow public read access to TODA terminals" ON public.toda_terminals;
CREATE POLICY "Allow public read access to TODA terminals"
ON public.toda_terminals FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Only MINC Admin can configure TODA terminals" ON public.toda_terminals;
CREATE POLICY "Only MINC Admin can configure TODA terminals"
ON public.toda_terminals FOR ALL
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

-- D. Policies for trips & telemetry
DROP POLICY IF EXISTS "Allow inserting completed trips" ON public.driver_completed_trips;
CREATE POLICY "Allow inserting completed trips"
ON public.driver_completed_trips FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow reading completed trip history" ON public.driver_completed_trips;
CREATE POLICY "Allow reading completed trip history"
ON public.driver_completed_trips FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow inserting into completed_trips" ON public.completed_trips;
CREATE POLICY "Allow inserting into completed_trips"
ON public.completed_trips FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow reading completed_trips" ON public.completed_trips;
CREATE POLICY "Allow reading completed_trips"
ON public.completed_trips FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow driver telemetry stream" ON public.driver_telemetry;
CREATE POLICY "Allow driver telemetry stream"
ON public.driver_telemetry FOR ALL
USING (true)
WITH CHECK (true);

-- E. Policies for `users`
DROP POLICY IF EXISTS "Allow users and admins to view profiles" ON public.users;
CREATE POLICY "Allow users and admins to view profiles"
ON public.users FOR SELECT
USING (true);

DROP POLICY IF EXISTS "Allow user onboarding registration" ON public.users;
CREATE POLICY "Allow user onboarding registration"
ON public.users FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Only MINC Admin can update verification status" ON public.users;
CREATE POLICY "Only MINC Admin can update verification status"
ON public.users FOR UPDATE
USING (public.is_minc_admin() OR auth.role() = 'service_role')
WITH CHECK (public.is_minc_admin() OR auth.role() = 'service_role');

-- F. Policies for `minc_trip_audit_logs`
DROP POLICY IF EXISTS "Allow inserting audit logs" ON public.minc_trip_audit_logs;
CREATE POLICY "Allow inserting audit logs"
ON public.minc_trip_audit_logs FOR INSERT
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow reading audit logs" ON public.minc_trip_audit_logs;
CREATE POLICY "Allow reading audit logs"
ON public.minc_trip_audit_logs FOR SELECT
USING (true);

-- ----------------------------------------------------------------------------
-- 5. LEGAL TAMPER-PROOF IMMUTABILITY TRIGGER
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.prevent_audit_tampering()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'CRITICAL SECURITY VIOLATION: Records in minc_trip_audit_logs are legally immutable. UPDATE or DELETE operations are prohibited under City Ordinance No. 2023-005.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_immutable_audit_logs ON public.minc_trip_audit_logs;
CREATE TRIGGER trg_immutable_audit_logs
BEFORE UPDATE OR DELETE ON public.minc_trip_audit_logs
FOR EACH ROW
EXECUTE FUNCTION public.prevent_audit_tampering();

-- ----------------------------------------------------------------------------
-- 6. SEED ESSENTIAL INITIAL VALUES (FARES & TODA TERMINALS)
-- ----------------------------------------------------------------------------

INSERT INTO public.fare_guide_table (
    id, ordinance_label, regular_first_km_fare, discounted_first_km_fare, succeeding_km_rate, base_distance_km, statutory_discount_share_rate
) VALUES (
    1, 'City Ordinance No. 2023-005', 20.00, 16.00, 5.00, 1.00, 0.20
) ON CONFLICT (id) DO UPDATE SET
    regular_first_km_fare = EXCLUDED.regular_first_km_fare,
    discounted_first_km_fare = EXCLUDED.discounted_first_km_fare,
    succeeding_km_rate = EXCLUDED.succeeding_km_rate,
    updated_at = timezone('utc'::text, now());

-- Seed initial Laoag TODA Terminals (populating both center_point and latitude/longitude)
INSERT INTO public.toda_terminals (id, name, toda_code, latitude, longitude, center_point, radius_meters, dwell_time_seconds, speed_limit_kmh)
VALUES
    ('term_01', 'Laoag Central Terminal & Public Market TODA', 'CENTRAL-TODA', 18.1972, 120.5925, ST_SetSRID(ST_MakePoint(120.5925, 18.1972), 4326)::geography, 25.0, 30, 5.0),
    ('term_02', 'INCAT School Gate TODA Pila', 'INCAT-TODA', 18.1990, 120.5980, ST_SetSRID(ST_MakePoint(120.5980, 18.1990), 4326)::geography, 15.0, 25, 5.0),
    ('term_03', 'MMSU Laoag Campus TODA', 'MMSU-TODA', 18.1925, 120.5960, ST_SetSRID(ST_MakePoint(120.5960, 18.1925), 4326)::geography, 25.0, 30, 5.0),
    ('term_04', 'Laoag Plaza & Heritage Center TODA', 'PLAZA-TODA', 18.1965, 120.5930, ST_SetSRID(ST_MakePoint(120.5930, 18.1965), 4326)::geography, 15.0, 30, 5.0),
    ('term_05', 'Laoag City General Hospital Pila', 'HOSPITAL-TODA', 18.2045, 120.5910, ST_SetSRID(ST_MakePoint(120.5910, 18.2045), 4326)::geography, 20.0, 20, 5.0)
ON CONFLICT (id) DO UPDATE SET
    latitude = EXCLUDED.latitude,
    longitude = EXCLUDED.longitude,
    center_point = EXCLUDED.center_point,
    radius_meters = EXCLUDED.radius_meters;
