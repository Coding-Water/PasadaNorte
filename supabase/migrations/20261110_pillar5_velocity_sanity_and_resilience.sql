-- ============================================================================
-- PASADANORTE: PILLAR 5 — BACKEND RESILIENCE & VELOCITY SANITY SENTINEL
-- Laoag City Paratransit Dispatch & Municipal Regulation Ecosystem
-- Standards: ISO/IEC 25010:2023 Reliability & Fault Tolerance • Laoag City Ord. 2023-005
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. EXTEND TELEMETRY SCHEMA WITH VELOCITY ANOMALY COLUMNS
-- ----------------------------------------------------------------------------

ALTER TABLE public.driver_telemetry 
ADD COLUMN IF NOT EXISTS velocity_kmh DOUBLE PRECISION DEFAULT 0.0;

ALTER TABLE public.driver_telemetry 
ADD COLUMN IF NOT EXISTS velocity_anomalous BOOLEAN DEFAULT FALSE;

-- Index for instant filtering of clean coordinates
CREATE INDEX IF NOT EXISTS idx_driver_telemetry_anomalous 
ON public.driver_telemetry (velocity_anomalous);

-- ----------------------------------------------------------------------------
-- 2. POSTGRESQL VELOCITY SANITY TRIGGER (Teleportation Glitch Detection)
-- Calculates true physical speed between pings using PostGIS ST_Distance
-- ----------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.calculate_telemetry_velocity()
RETURNS TRIGGER AS $$
DECLARE
    delta_seconds DOUBLE PRECISION;
    distance_meters DOUBLE PRECISION;
    speed_kmh DOUBLE PRECISION := 0.0;
    max_physical_speed_kmh CONSTANT DOUBLE PRECISION := 80.0;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        delta_seconds := EXTRACT(EPOCH FROM (NEW.updated_at - OLD.updated_at));

        -- Only compute if at least 0.5s has elapsed between pings
        IF delta_seconds >= 0.5 THEN
            distance_meters := ST_Distance(
                ST_SetSRID(ST_MakePoint(NEW.longitude, NEW.latitude), 4326)::geography,
                ST_SetSRID(ST_MakePoint(OLD.longitude, OLD.latitude), 4326)::geography
            );

            speed_kmh := (distance_meters / delta_seconds) * 3.6;
            NEW.velocity_kmh := ROUND(speed_kmh::numeric, 2);

            -- Flag teleportation jump (> 80 km/h is physically impossible for a tricycle)
            IF speed_kmh > max_physical_speed_kmh THEN
                NEW.velocity_anomalous := TRUE;

                INSERT INTO public.minc_trip_audit_logs (
                    trip_id,
                    actor,
                    action,
                    discrepancy_amount,
                    status,
                    logged_at
                ) VALUES (
                    NEW.ride_id,
                    'VELOCITY_SANITY_SENTINEL',
                    CONCAT('TELEPORTATION_ANOMALY: Speed calculated at ', ROUND(speed_kmh::numeric, 1), ' km/h between pings. Point suppressed from live passenger maps.'),
                    0.00,
                    'GLITCH_SUPPRESSED',
                    timezone('utc'::text, now())
                );
            ELSE
                NEW.velocity_anomalous := FALSE;
            END IF;
        ELSE
            -- Retain previous speed for micro-interval updates
            NEW.velocity_kmh := OLD.velocity_kmh;
            NEW.velocity_anomalous := OLD.velocity_anomalous;
        END IF;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_driver_telemetry_velocity ON public.driver_telemetry;
CREATE TRIGGER trg_driver_telemetry_velocity
BEFORE UPDATE ON public.driver_telemetry
FOR EACH ROW
EXECUTE FUNCTION public.calculate_telemetry_velocity();

-- ----------------------------------------------------------------------------
-- 3. UPDATED SECURE VIEW: valid_driver_telemetry
-- Excludes both Mock GPS pings and Velocity Anomalies (> 80 km/h)
-- ----------------------------------------------------------------------------

-- Drop view first to allow column reordering without triggering ERROR 42P16
DROP VIEW IF EXISTS public.valid_driver_telemetry CASCADE;

CREATE VIEW public.valid_driver_telemetry AS
SELECT 
    ride_id,
    latitude,
    longitude,
    heading,
    stage,
    velocity_kmh,
    updated_at
FROM public.driver_telemetry
WHERE is_mocked = FALSE 
  AND velocity_anomalous = FALSE;

GRANT SELECT ON public.valid_driver_telemetry TO anon, authenticated;

COMMENT ON VIEW public.valid_driver_telemetry IS 
'Clean live driver telemetry view filtering out both mock GPS coordinates and physical velocity spikes (> 80 km/h).';
