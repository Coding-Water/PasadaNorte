-- ============================================================================
-- PASADANORTE: PILLAR 2 — ANTI-GPS SPOOFING & MOCK LOCATION SENTINEL
-- Laoag City Paratransit Dispatch & Municipal Regulation Ecosystem
-- Standards: ISO/IEC 25010:2023 Security & Integrity • Laoag City Ord. 2023-005
-- ============================================================================

-- 1. Extend driver_telemetry table with hardware mock detection flag
ALTER TABLE public.driver_telemetry 
ADD COLUMN IF NOT EXISTS is_mocked BOOLEAN NOT NULL DEFAULT FALSE;

-- 2. Create index on is_mocked for high-performance dispatch filtering
CREATE INDEX IF NOT EXISTS idx_driver_telemetry_is_mocked 
ON public.driver_telemetry (is_mocked);

-- 3. Filtered View: Valid Driver Telemetry (excludes spoofed or mock GPS streams)
-- Passenger clients and public map displays query this view to prevent displaying spoofed positions.
CREATE OR REPLACE VIEW public.valid_driver_telemetry AS
SELECT 
    ride_id,
    latitude,
    longitude,
    heading,
    stage,
    updated_at
FROM public.driver_telemetry
WHERE is_mocked = FALSE;

-- Grant read access on valid_driver_telemetry to authenticated and anon users
GRANT SELECT ON public.valid_driver_telemetry TO anon, authenticated;

-- 4. Automated Audit Trigger: Log Mock GPS Spoofing Attempts into Regulatory Audit Trail
CREATE OR REPLACE FUNCTION public.log_mock_gps_tamper_attempt()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_mocked = TRUE AND (OLD.is_mocked IS NULL OR OLD.is_mocked = FALSE) THEN
        INSERT INTO public.minc_trip_audit_logs (
            trip_id,
            actor,
            action,
            discrepancy_amount,
            status,
            logged_at
        ) VALUES (
            NEW.ride_id,
            'DRIVER_LOCATION_SENTINEL',
            'GPS_SPOOFING_ATTEMPT_DETECTED: Hardware isMocked=true flag detected during active telemetry broadcast (City Ord. 2023-005). Digital Pila queue advancement blocked.',
            0.00,
            'FLAGGED_SPOOF',
            timezone('utc'::text, now())
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS trg_driver_telemetry_mock_audit ON public.driver_telemetry;
CREATE TRIGGER trg_driver_telemetry_mock_audit
AFTER INSERT OR UPDATE OF is_mocked ON public.driver_telemetry
FOR EACH ROW
WHEN (NEW.is_mocked = TRUE)
EXECUTE FUNCTION public.log_mock_gps_tamper_attempt();

COMMENT ON COLUMN public.driver_telemetry.is_mocked IS 
'Hardware sensor flag indicating coordinates originated from Android Mock Location Provider or iOS simulated location.';
